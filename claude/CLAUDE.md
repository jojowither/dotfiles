# 全域習慣（所有專案共用）

## 回答
- 用繁體中文回答；程式碼、指令、檔名維持原文。

## mattpocock-skills：主動提醒手動 skill
裝了 `mattpocock-skills` plugin。其中標成手動的 skill 不會自動觸發，我也還不熟，
所以遇到下面的情況，請在回覆最後用一行建議對應指令（只建議，不要自己跑），
同一個 session 同一個建議只提一次：

| 情況 | 建議 |
|---|---|
| 要做新功能、改設計、需求還模糊，準備開始寫程式之前 | `/grill-with-docs`（非程式的計畫用 `/grill-me`） |
| 討論完了，要整理成規格或拆成工作 | `/to-spec`、`/to-tickets` |
| 工作量大到一個 session 做不完 | `/wayfinder` |
| 已經有 spec 或 tickets，要開始實作 | `/implement` |
| 想整理架構、程式碼越來越亂 | `/improve-codebase-architecture` |
| 這個 repo 第一次用這些 skill（還沒有它的設定） | `/setup-matt-pocock-skills` |
| session 很長、要換新 session 接手 | `/handoff` |
| 一段工作做完，想回顧 | `/retro` |
| 不確定該用哪個 | `/ask-matt` |

自動觸發的（`tdd`、`diagnosing-bugs`、`code-review`、`pr` 等）照常使用，不用另外提醒。
