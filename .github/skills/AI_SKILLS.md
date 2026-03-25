# AI 助手技能指南

> 用途：提供 AI 助手的診斷路由、回應結構與引用規則
>
> 適用對象：AI 助手
>
> 不包含內容：給一般使用者的完整教學
>
> 延伸閱讀：
> - [QUICK_REFERENCE.md](QUICK_REFERENCE.md)
> - [MYSQL_USAGE.md](MYSQL_USAGE.md)
> - [LARAVEL_TINKER.md](LARAVEL_TINKER.md)
> - [../../CLAUDE.md](../../CLAUDE.md)

---

## A1. 問題分類路由

| 關鍵詞 | 問題類型 | 優先文件 |
|---|---|---|
| `502`, `bad gateway`, `upstream` | Nginx / PHP-FPM 連線 | [QUICK_REFERENCE.md](QUICK_REFERENCE.md#q6-三步排查) |
| `mysql`, `SQLSTATE`, `Access denied`, `ONLY_FULL_GROUP_BY` | MySQL 連線/配置/SQL Mode | [MYSQL_USAGE.md](MYSQL_USAGE.md#m6-故障排除) |
| `tinker`, `artisan`, `model` | Laravel Tinker 操作 | [LARAVEL_TINKER.md](LARAVEL_TINKER.md#t1-啟動流程) |
| `extra_hosts`, `nginx`, `.local` | 虛擬主機與容器網路 | [QUICK_REFERENCE.md](QUICK_REFERENCE.md#q1-服務與容器) + [../../CLAUDE.md](../../CLAUDE.md) |
| `重啟`, `logs`, `ps`, `build` | 容器維護 | [QUICK_REFERENCE.md](QUICK_REFERENCE.md#q1-服務與容器) |

---

## A2. 標準回應骨架

1. 診斷：一句話先說明最可能原因。
2. 步驟：提供可直接複製的指令，順序為進容器 → 切目錄 → 執行。
3. 驗證：給 1-2 個可快速確認結果的指令。
4. 延伸：附上對應文件連結。

---

## A3. 標準模板（文字）

### 模板 A：連線問題

- 診斷：目前看起來是 `[服務名/埠號/監聽]` 不一致導致連線失敗。
- 步驟：
  - `docker-compose ps <service>`
  - `docker-compose exec <container> ...`
  - `docker-compose restart <service>`
- 驗證：
  - `docker-compose ps <service>`
  - `docker-compose exec <container> ...`
- 延伸：導流到對應文件章節。

### 模板 B：操作教學

- 診斷：你要的是 `[目標操作]`，可直接走最短流程。
- 步驟：
  - 進容器
  - 切到目標專案目錄（優先用別名）
  - 執行目標命令
- 驗證：回傳關鍵輸出（例如 `PONG`、資料筆數、SQL Mode）。
- 延伸：附完整教學文件連結。

---

## A4. 回應檢查清單

- 使用繁體中文。
- 優先給可執行命令。
- 優先用別名：`mysql80`、`tinker`、`cdfront`。
- 容器間連線用服務名，不用 `localhost`。
- 至少包含一個驗證步驟。
- 不輸出機密，敏感值導向 `.env`。

---

## A5. 文件引用規則

1. 指令速查只引用 [QUICK_REFERENCE.md](QUICK_REFERENCE.md)。
2. MySQL 原理與備份還原只引用 [MYSQL_USAGE.md](MYSQL_USAGE.md)。
3. Tinker 實作與模型測試只引用 [LARAVEL_TINKER.md](LARAVEL_TINKER.md)。
4. 專案全域設定只引用 [../../CLAUDE.md](../../CLAUDE.md)。
5. 避免在本文件重貼長篇教學內容。

---

**版本**：2.1.0  
**最後更新**：2026-03-25  
**適用 AI**：Claude、GitHub Copilot、ChatGPT、Cursor AI 等

