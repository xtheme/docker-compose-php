# Copilot Instructions — Docker-Compose 開發環境

## P1. 專案定位

本專案為本地開發用 Docker 容器編排環境，支援多版本 PHP、MySQL、Redis，主要服務 Laravel 與 Hyperf。

## P2. 語言與回應原則

- 所有回應與說明使用**繁體中文**。

1. 優先給可執行指令，避免只做概念解釋。
2. 優先使用既有別名（如 `tinker`、`mysql80`、`cdfront`）。
3. 回覆步驟固定為：進容器 → 切目錄 → 執行 → 驗證。
4. 容器間連線必用服務名稱（如 `mysql8`、`redis`），不用 `localhost`。
5. 不輸出敏感資訊；機密統一放 `.env`。

## P3. 文件路由（章節錨點）

當使用者提問時，依問題類型導流至對應文件：

| 問題類型 | 主要文件 | 說明 |
|---|---|---|
| 常用指令、容器操作 | [QUICK_REFERENCE.md](skills/QUICK_REFERENCE.md#q1-服務與容器) | 高頻命令速查 |
| MySQL 連線、備份、SQL Mode | [MYSQL_USAGE.md](skills/MYSQL_USAGE.md#m1-連線方式) | MySQL 深度手冊 |
| Laravel Tinker 操作與除錯 | [LARAVEL_TINKER.md](skills/LARAVEL_TINKER.md#t1-啟動流程) | Tinker 實作指南 |
| AI 觸發詞、診斷流程、回應模板 | [AI_SKILLS.md](skills/AI_SKILLS.md#a1-問題分類路由) | AI 專用規範 |
| 專案全貌與結構 | [CLAUDE.md](../CLAUDE.md) | 全域說明 |

## P4. 編輯與維護規則

1. 若內容屬於技能文檔，優先更新 `skills/` 下對應主責文件。
2. 避免同一知識在多文件重複貼完整內容，改用連結導流。
3. 每次修改後更新文件尾端 `最後更新`。
4. 不將憑證、密碼、token 放入範例；改以環境變數表示。

## P5. 回應輸出格式

1. 一句診斷結果。
2. 可直接複製的步驟指令。
3. 驗證指令。
4. 對應文件連結（必要時）。

## P6. 更新記錄

- **2026-03-25**：
  - 精簡本文件為 AI 政策與文件路由。
  - 將操作細節維護責任集中到 `skills/`。
- **2026-03-23**：
  - 修復 PHP-FPM8 監聽地址（`127.0.0.1` → `0.0.0.0`）。
  - 新增 MySQL 別名（`mysql57`、`mysql80`）。
  - 補齊 MySQL / Tinker 文件。

---

**最後更新**：2026-03-25


