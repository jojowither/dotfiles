#!/usr/bin/env python3
"""Claude Code status line.

1. 在 Claude Code 底部顯示：模型 · context % · 5h % · week %
2. 存資料給 Herdr（~/.cache/claude-usage/）：
   - rate_limits.json  官方用量（和 /usage 同一份），給狀態列
   - history.json      最近幾小時的用量取樣，給狀態列算用完時間的預估
   - agents/<id>.json  每個 agent 的模型、context %、改動行數；
                       <id> 是 Herdr 終端機位址（$HC_TERMINAL_ID，例如 t13），
                       和 Herdr agents() 的 address 對得上

rate_limits 只有 Pro / Max 訂閱才有，而且要在 session 第一次回應之後才出現。
"""
import json
import os
import re
import sys
import tempfile
import time

DIR = os.path.expanduser("~/.cache/claude-usage")
HISTORY_KEEP_SEC = 6 * 3600
HISTORY_MIN_GAP_SEC = 60


def write_json(path, obj):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path))
    with os.fdopen(fd, "w") as f:
        json.dump(obj, f)
    os.replace(tmp, path)  # 原子替換，讀的一方不會讀到寫一半的檔案


def read_json(path, default):
    try:
        with open(path) as f:
            return json.load(f)
    except (OSError, ValueError):
        return default


def save_usage(rl, now):
    write_json(os.path.join(DIR, "rate_limits.json"), {"updated_at": now, "rate_limits": rl})

    # 取樣：[時間, 5h %, 5h 重置時間, week %, week 重置時間]
    five, week = rl.get("five_hour") or {}, rl.get("seven_day") or {}
    sample = [now, five.get("used_percentage"), five.get("resets_at"),
              week.get("used_percentage"), week.get("resets_at")]
    path = os.path.join(DIR, "history.json")
    hist = [s for s in read_json(path, []) if now - s[0] <= HISTORY_KEEP_SEC]
    if hist and now - hist[-1][0] < HISTORY_MIN_GAP_SEC:
        hist[-1] = sample
    else:
        hist.append(sample)
    write_json(path, hist)


def save_agent(data, now):
    tid = os.environ.get("HC_TERMINAL_ID", "")
    if not re.fullmatch(r"[A-Za-z0-9_-]+", tid):
        return  # 不是在 Herdr 終端機裡跑的
    cost = data.get("cost") or {}
    write_json(os.path.join(DIR, "agents", tid + ".json"), {
        "updated_at": now,
        "session_id": data.get("session_id"),
        "model": (data.get("model") or {}).get("display_name"),
        "context_pct": (data.get("context_window") or {}).get("used_percentage"),
        "lines_added": cost.get("total_lines_added"),
        "lines_removed": cost.get("total_lines_removed"),
        "cwd": (data.get("workspace") or {}).get("current_dir"),
    })


def main():
    try:
        data = json.load(sys.stdin)
    except ValueError:
        data = {}
    now = int(time.time())

    rl = data.get("rate_limits") or {}
    try:
        if rl.get("five_hour") or rl.get("seven_day"):
            save_usage(rl, now)
        save_agent(data, now)
    except OSError:
        pass

    parts = [(data.get("model") or {}).get("display_name") or "Claude"]
    ctx = (data.get("context_window") or {}).get("used_percentage")
    if ctx is not None:
        parts.append("ctx %d%%" % round(ctx))
    for key, label in (("five_hour", "5h"), ("seven_day", "week")):
        pct = (rl.get(key) or {}).get("used_percentage")
        if pct is not None:
            parts.append("%s %d%%" % (label, round(pct)))
    print(" · ".join(parts))


if __name__ == "__main__":
    main()
