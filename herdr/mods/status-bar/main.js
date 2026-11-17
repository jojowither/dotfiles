// 底部狀態列（取代 Herdr 內建的 workspace-status）：
//   左：機器 · git 分支 · agent 數量（有幾個在等你）
//   右：Claude 用量（目前 session / 本週，和 /usage 同一份官方資料）· ⌘⇧P 提示
// 另外：
//   - Dock 圖示的紅色數字 = 在等你的 agent 數（blocked）
//   - 用量超過 80% / 95% 時各跳一次通知（每個重置週期一次）
//
// 用量資料來自 claude/statusline.py 寫的 ~/.cache/claude-usage/rate_limits.json，
// 只有在任何一個 Claude Code session 有回應時才會更新。
import { View, div, svg } from "gpui-kit";
import { h_flex } from "gpui-base";
import { spaces, agents, theme, run, window, keys, readTextFile, home, setBadge, notify, checking } from "herdr";

const REFRESH_MS = 20_000;
const THRESHOLDS = [95, 80];
const WINDOWS = [
  { key: "five_hour", short: "5h", name: "目前 session" },
  { key: "seven_day", short: "週", name: "本週" },
];

const pad = (n) => String(n).padStart(2, "0");
const resetText = (sec) => {
  const d = new Date(sec * 1000);
  const sameDay = d.toDateString() === new Date().toDateString();
  const wd = ["日", "一", "二", "三", "四", "五", "六"][d.getDay()];
  return `${sameDay ? "" : `週${wd} `}${pad(d.getHours())}:${pad(d.getMinutes())}`;
};

export default class StatusBar extends View {
  init(_props, cx) {
    this.usage = null;
    this.badge = undefined;
    if (checking()) return;
    cx.timer.every(REFRESH_MS, (cx) => this.refresh(cx));
    this.refresh(cx);
  }

  refresh(cx) {
    cx.spawn(async (cx) => {
      try {
        const text = await readTextFile(`${home()}/.cache/claude-usage/rate_limits.json`);
        this.usage = text ? JSON.parse(text) : null;
      } catch (_) {
        this.usage = null;
      }
      this.alertIfHigh();
      cx.notify();
    });
  }

  // 某個區段的百分比；重置時間已過就當 0（等下一次回應再更新）
  pct(w) {
    if (!w || w.used_percentage == null) return null;
    if (w.resets_at && w.resets_at <= Date.now() / 1000) return 0;
    return Math.round(w.used_percentage);
  }

  alertIfHigh() {
    const rl = this.usage?.rate_limits ?? {};
    for (const win of WINDOWS) {
      const w = rl[win.key];
      const pct = this.pct(w);
      if (pct == null) continue;
      const level = THRESHOLDS.find((n) => pct >= n);
      if (!level) continue;
      const seenKey = `alert:${win.key}:${w.resets_at}:${level}`;
      try { if (localStorage.getItem(seenKey)) continue; localStorage.setItem(seenKey, "1"); } catch (_) {}
      notify({
        title: `Claude ${win.name}用量 ${pct}%`,
        body: `${resetText(w.resets_at)} 重置`,
        level: level >= 95 ? "error" : "warning",
        timeout: 8000,
      });
    }
  }

  updateBadge(blocked) {
    const text = blocked ? String(blocked) : null;
    if (text !== this.badge) { this.badge = text; setBadge(text); }
  }

  hint() {
    const mac = window()?.platform === "macos";
    const mod = { cmd: mac ? "⌘" : "Ctrl+", ctrl: mac ? "⌃" : "Ctrl+", shift: mac ? "⇧" : "Shift+", alt: mac ? "⌥" : "Alt+", option: mac ? "⌥" : "Alt+" };
    const b = keys().find((k) => k.section === "global" && k.action === "app.palette");
    const parts = b && b.keys.endsWith("--") ? [...b.keys.slice(0, -2).split("-"), "-"] : b?.keys.split("-");
    const key = parts && parts.map((p) => mod[p.toLowerCase()] ?? p.toUpperCase()).join("");
    return key ? `${key}  commands` : "commands";
  }

  usageItem(t, win, w) {
    const pct = this.pct(w);
    const color = pct == null ? t.dim : pct >= 90 ? t.blocked : pct >= 70 ? t.ansi3 : t.accent;
    return h_flex().gap(6).items_center()
      .child(div().text_color(t.dim).child(win.short))
      .child(div().w(36).h(4).rounded(2).bg(t.border)
        .child(div().h(4).rounded(2).bg(color).w(Math.round((36 * (pct ?? 0)) / 100))))
      .child(div().text_color(pct != null && pct >= 70 ? color : t.muted).child(pct == null ? "—" : `${pct}%`));
  }

  render() {
    const t = theme();
    const space = spaces().find((s) => s.active);
    const list = agents();
    const needs = list.filter((a) => a.status === "blocked").length;
    const working = list.filter((a) => a.status === "working").length;
    if (!checking()) this.updateBadge(needs);

    const rl = this.usage?.rate_limits;
    const label = (icon, text) => h_flex().gap(6).items_center()
      .child(svg(`mods/workspace-chrome/${icon}.svg`).size(13)).child(text);
    const sep = () => div().w(1).h(12).bg(t.border);

    return h_flex().size_full().px(14).gap(14).items_center()
      .bg(t.chrome).border_t(1).border_color(t.border).text_size(11.8).text_color(t.muted)
      .child(label(space?.machine ? "server" : "monitor", space?.machine ?? "This computer"))
      .when(Boolean(space?.branch), (el) => el.child(label("branch", space.branch)))
      .child(h_flex().gap(6).items_center()
        .child(div().size(6).rounded(3).bg(needs ? t.blocked : working ? t.working : t.dim))
        .child(`${list.length} agents`)
        .when(working > 0, (el) => el.child(div().text_color(t.working).child(`· ${working} working`)))
        .when(needs > 0, (el) => el.child(div().text_color(t.blocked).child(`· ${needs} needs you`))))
      .child(div().flex_1())
      .when(Boolean(rl), (el) => el
        .child(h_flex().id("status-usage").gap(14).items_center()
          .on_click((_e, cx) => this.refresh(cx))
          .child(div().text_color(t.dim).child("Claude"))
          .children(WINDOWS.map((win) => this.usageItem(t, win, rl[win.key]))))
        .child(sep()))
      .child(div().id("palette").text_color(t.dim).hover((s) => s.text_color(t.foreground))
        .on_click(() => run("app.palette")).child(this.hint()));
  }
}
