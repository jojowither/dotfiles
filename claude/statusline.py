#!/usr/bin/env python3
"""Claude Code status line.

1. 在 Claude Code 底部顯示：模型 · context % · 5h % · 本週 %
2. 把官方的 rate_limits（和 /usage 同一份資料）存到
   ~/.cache/claude-usage/rate_limits.json，給 Herdr 的 claude-usage 面板讀。

rate_limits 只有 Pro / Max 訂閱才有，而且要在 session 第一次回應之後才出現。
"""
import json
import os
import sys
import tempfile
import time

CACHE = os.path.expanduser("~/.cache/claude-usage/rate_limits.json")


def save(rate_limits):
    os.makedirs(os.path.dirname(CACHE), exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(CACHE))
    with os.fdopen(fd, "w") as f:
        json.dump({"updated_at": int(time.time()), "rate_limits": rate_limits}, f)
    os.replace(tmp, CACHE)  # 原子替換，面板不會讀到寫一半的檔案


def main():
    try:
        data = json.load(sys.stdin)
    except ValueError:
        data = {}

    rl = data.get("rate_limits") or {}
    if rl.get("five_hour") or rl.get("seven_day"):
        try:
            save(rl)
        except OSError:
            pass

    parts = [(data.get("model") or {}).get("display_name") or "Claude"]
    ctx = (data.get("context_window") or {}).get("used_percentage")
    if ctx is not None:
        parts.append("ctx %d%%" % round(ctx))
    for key, label in (("five_hour", "5h"), ("seven_day", "週")):
        pct = (rl.get(key) or {}).get("used_percentage")
        if pct is not None:
            parts.append("%s %d%%" % (label, round(pct)))
    print(" · ".join(parts))


if __name__ == "__main__":
    main()
