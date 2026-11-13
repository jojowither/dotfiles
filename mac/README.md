這個資料夾放 GUI app 的設定，用 `./bootstrap.sh --backup` 從目前這台電腦匯出：

- `karabiner/`      ← ~/.config/karabiner/
- `linearmouse.json` ← ~/.config/linearmouse/linearmouse.json

換電腦時 bootstrap 會把它們「複製」回去（不是 symlink，因為這些 app 會自己覆寫設定檔）。
