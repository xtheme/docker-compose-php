# AI 助手技能知識庫

本目錄提供 Docker-Compose 開發環境的技能文件，重點是**分工清楚、避免重複**。

## R1. 文件責任地圖

| 文件 | 用途 | 主要讀者 | 不包含 |
|---|---|---|---|
| [QUICK_REFERENCE.md](QUICK_REFERENCE.md#q1-服務與容器) | 指令速查 | 開發者 / AI | 原理解析 |
| [MYSQL_USAGE.md](MYSQL_USAGE.md#m1-連線方式) | MySQL 深度操作 | 開發者 / AI | Tinker 教學 |
| [LARAVEL_TINKER.md](LARAVEL_TINKER.md#t1-啟動流程) | Tinker 實作指南 | 開發者 / AI | 備份還原詳解 |
| [AI_SKILLS.md](AI_SKILLS.md#a1-問題分類路由) | AI 診斷與模板 | AI 助手 | 一般使用者教學 |
| [../../CLAUDE.md](../../CLAUDE.md) | 專案全域文件 | 開發者 / AI | 問題分流模板 |

## R2. 快速導流

- 常用命令與容器操作：[QUICK_REFERENCE.md](QUICK_REFERENCE.md#q1-服務與容器)
- MySQL 連線、SQL Mode、備份還原：[MYSQL_USAGE.md](MYSQL_USAGE.md#m1-連線方式)
- Laravel Tinker 操作與除錯：[LARAVEL_TINKER.md](LARAVEL_TINKER.md#t1-啟動流程)
- AI 問題分類與回覆模板：[AI_SKILLS.md](AI_SKILLS.md#a1-問題分類路由)

## R3. 交叉引用規則

1. 指令速查只在 `QUICK_REFERENCE.md` 完整維護。
2. MySQL 深度內容只在 `MYSQL_USAGE.md` 完整維護。
3. Tinker 深度內容只在 `LARAVEL_TINKER.md` 完整維護。
4. `AI_SKILLS.md` 只放路由、模板、檢查清單，不重貼長篇教學。
5. 跨檔引用使用相對路徑，優先連到明確章節錨點。

## R4. 新增/調整流程

1. 先定義文件責任（要解什麼問題、不解什麼問題）。
2. 檢查現有文件是否已有同主題內容。
3. 新增或調整文件後，更新 `copilot-instructions.md` 路由表。
4. 補上必要交叉連結與末尾更新日期。

---

*最後更新：2026-03-25*


