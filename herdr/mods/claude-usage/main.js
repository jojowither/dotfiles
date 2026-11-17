// Claude 用量面板：和 Claude Code 的 /usage 同一份官方資料（目前 session、本週的百分比與重置時間）。
//
// 資料來源：claude/statusline.py（Claude Code 的 status line）每次更新時，把 rate_limits
// 存到 ~/.cache/claude-usage/rate_limits.json，這裡每 20 秒讀一次那個檔案。
// 所以數字會在「任何一個 Claude Code session 有回應」時更新；都沒在用時停在最後一次的值。
// 某個區段的重置時間過了，就當作已重置（0%），等下一次回應再更新成真實數字。
import { View, div } from "gpui-kit";
import { v_flex, h_flex } from "gpui-base";
import { readTextFile, home, theme, checking } from "herdr";

const REFRESH_MS = 20_000;
const WEEKDAYS = ["週日", "週一", "週二", "週三", "週四", "週五", "週六"];

const pad = (n) => String(n).padStart(2, "0");
const hhmm = (d) => `${pad(d.getHours())}:${pad(d.getMinutes())}`;
const resetLabel = (d) => {
  const now = new Date();
  const sameDay = d.toDateString() === now.toDateString();
  return `${sameDay ? "" : WEEKDAYS[d.getDay()] + " "}${hhmm(d)} 重置`;
};
const ago = (sec) => {
  const m = Math.floor((Date.now() / 1000 - sec) / 60);
  return m < 1 ? "剛剛" : m < 60 ? `${m} 分鐘前` : `${Math.floor(m / 60)} 小時前`;
};

export default class ClaudeUsage extends View {
  init(_props, cx) {
    this.data = null;
    this.error = null;
    this.width = 240;
    if (checking()) return;
    cx.timer.every(REFRESH_MS, (cx) => this.refresh(cx));
    this.refresh(cx);
  }

  refresh(cx) {
    cx.spawn(async (cx) => {
      try {
        const text = await readTextFile(`${home()}/.cache/claude-usage/rate_limits.json`);
        this.data = text ? JSON.parse(text) : null;
        this.error = null;
      } catch (e) {
        this.error = String(e?.message ?? e);
      }
      cx.notify();
    });
  }

  render(cx) {
    const t = theme();
    const rl = this.data?.rate_limits ?? {};
    const nowSec = Date.now() / 1000;

    const windowRow = (label, w) => {
      const expired = w && w.resets_at && w.resets_at <= nowSec;
      const pct = !w ? null : expired ? 0 : Math.round(w.used_percentage ?? 0);
      const color = pct == null ? t.dim : pct >= 90 ? t.blocked : pct >= 70 ? t.ansi3 : t.accent;
      const barW = Math.max(0, this.width - 28);
      return v_flex().gap(4)
        .child(
          h_flex().items_center().justify_between()
            .child(div().text_color(t.foreground).child(label))
            .child(div().text_color(t.muted).child(pct == null ? "—" : `${pct}% used`)))
        .child(
          div().h(4).w_full().rounded(2).bg(t.border)
            .child(div().h(4).w(Math.round((barW * (pct ?? 0)) / 100)).rounded(2).bg(color)))
        .child(
          div().text_size(11).text_color(t.dim).truncate()
            .child(!w ? "還沒有資料" : expired ? "已重置，等下一次回應更新" : resetLabel(new Date(w.resets_at * 1000))));
    };

    const header = h_flex().items_center().justify_between()
      .child(div().text_size(11).font_semibold().text_color(t.muted).child("CLAUDE 用量"))
      .child(
        div().id("claude-usage-refresh").text_size(11).text_color(t.dim)
          .hover((s) => s.text_color(t.foreground))
          .on_click((_e, cx) => this.refresh(cx))
          .child(this.data?.updated_at ? `↻ ${ago(this.data.updated_at)}` : "↻"));

    const body = v_flex().gap(10);
    if (this.error) {
      body.child(div().text_color(t.blocked).truncate().child(this.error));
    } else if (!this.data) {
      body.child(div().text_color(t.dim).child("在 Claude Code 裡送出一則訊息後就會出現"));
    } else {
      body.child(windowRow("目前 session", rl.five_hour)).child(windowRow("本週", rl.seven_day));
    }

    return v_flex().id("claude-usage-root").size_full().px(14).py(10).gap(10)
      .bg(t.chrome).border_t(1).border_color(t.border).text_size(12.5)
      .on_size_change((size, cx) => {
        if (Math.abs(size.width - this.width) > 1) { this.width = size.width; cx.notify(); }
      })
      .child(header)
      .child(body);
  }
}
