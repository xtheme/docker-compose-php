# Docker-Compose 環境優化 — A 階段：設定整理 / 安全性

- 日期：2026-05-25
- 範圍：僅 A 階段（低風險、不重建 image）
- 後續：B（映像檔精簡）、C（效能 / DX）為獨立階段，本 spec 不涵蓋

## 1. 目標

讓 `.env.example`、`.env`、`CLAUDE.md` 三方資訊一致；統一容器 restart 行為；移除不必要的 host 端 port 曝露；瘦化 `docker build` 的 context；私鑰掛載改為唯讀。

**不在範圍內**：

- Dockerfile 重寫、image 瘦身、PHP 擴充裁減（B 階段）
- Xdebug 模式調整、MySQL `my.cnf` 調校、healthcheck、compose profiles（C 階段）
- 多階段建置、layer 合併
- 變更服務數量或業務行為

## 2. 變更項目

### A1 — 對齊 `.env.example`

來源檔：`/Users/rb/Docker-Compose/.env.example`

| 變更 | 原值 | 新值 | 理由 |
|------|------|------|------|
| `MYSQL_PORT` | `3306` | `3305` | 對齊 CLAUDE.md「MySQL 5.7 對外埠為 3305」與實際 `.env` |
| `MYSQL8_PORT` | `3308` | `3306` | 對齊 CLAUDE.md「MySQL 8.0 為 3306」與實際 `.env` |
| `NODEJS_VERSION` | `23` | `20` | 對齊實際 `.env`，CLAUDE.md 表格也記 `16 或 23`，實際多用 LTS |
| 新增 `MYSQL8_DATABASE` | — | `database` | `.env` 已有但 example 缺；docker-compose.yml 透過 `MYSQL_DATABASE` 共用 → 詳見備註 |
| 新增 `MYSQL8_USER` | — | `user` | 同上 |
| 新增 `MYSQL8_PASSWORD` | — | `pass` | 同上 |
| 新增 `MYSQL8_ROOT_PASSWORD` | — | `pass` | 同上 |
| 移除 ClickHouse 註解 | `#CLICKHOUSE_USER=...` | (刪除) | 目前 compose 已無 ClickHouse 服務；git history 仍可查 |

**備註**：目前 `docker-compose.yml` 的 `mysql8` service 仍使用 `MYSQL_DATABASE`、`MYSQL_USER` 等共用變數。`.env.example` 補上 `MYSQL8_*` 是為了「對齊實際 `.env` 內容」，**本 spec 不修改 compose 檔讓 mysql8 改用 `MYSQL8_*` 變數**（避免影響現有資料庫初始化行為）。是否切換到獨立變數留給 C 階段或之後評估。

### A2 — 統一 restart policy

來源檔：`/Users/rb/Docker-Compose/docker-compose.yml`

| service | 原值 | 新值 |
|---------|------|------|
| `web` (line 17) | `restart: always` | `restart: unless-stopped` |
| `open-webui` (line 174) | `restart: always` | `restart: unless-stopped` |

其他服務 (`php-fpm`、`php-fpm8`、`api`、`mysql`、`mysql8`、`redis`) 維持 `unless-stopped`。

**理由**：開發機上手動 `docker stop` 後不希望 Docker daemon 自動拉起；對齊 commit `0565d46` 的方針。

### A3 — 新增 `.dockerignore`

新增檔：`/Users/rb/Docker-Compose/.dockerignore`

內容：

```
# Version control & IDE
.git/
.github/
.idea/
.claude/
.codex/

# OS noise
.DS_Store
**/.DS_Store

# Local-only
.env
Workspace/

# Service state (huge, never belongs in build context)
mysql/data/
mysql/log/
mysql8/data/
mysql8/log/
gitlab-runner/config/
rabbitmq/data/
rabbitmq/logs/

# Logs
*.log
nginx/logs/

# Docs (不參與 build)
docs/
README.md
CLAUDE.md
AGENTS.md
```

**理由**：

- 目前 `docker build` 的 context 是各服務子目錄（如 `./php-fpm`），看似不會掃到根目錄；但 Docker 仍會以根目錄為 daemon context 邊界處理 `.dockerignore`。為避免日後 build context 變更時意外送進 MySQL data，先補上。
- `mysql/data/` 與 `mysql8/data/` 在開發中可能膨脹到 GB 等級。
- `.git/`、`.idea/`、`.claude/`、`.codex/` 都不該進入 image 邊界。

### A4 — SSH 私鑰唯讀掛載

來源檔：`/Users/rb/Docker-Compose/docker-compose.yml`

| service | 原 line | 變更 |
|---------|---------|------|
| `php-fpm` | line 35 | `- ${SSH_KEY_PATH}:/root/.ssh/id_rsa` → `- ${SSH_KEY_PATH}:/root/.ssh/id_rsa:ro` |
| `php-fpm8` | line 113 | 同上 |

公鑰 (`id_rsa.pub`) 已是 `:ro`；本變更只補上私鑰。

**理由**：容器內以 root 跑，誤觸命令可能覆蓋 host 私鑰；改為唯讀掛載作為第一道防線。

### A5 — 移除 PHP-FPM 對 host 的 port 曝露

來源檔：`/Users/rb/Docker-Compose/docker-compose.yml`

| service | 變更 |
|---------|------|
| `php-fpm` | 移除 `ports:` 段 `"9000:9000"`（lines 30~31） |
| `php-fpm8` | 移除 `ports:` 段 `"9001:9000"`（lines 108~109） |

**理由**：

- Nginx 容器與 PHP-FPM 在同一個 default network，nginx 透過 `fastcgi_pass php-upstream;` / `php-upstream8;` 走 service name 解析，不需要 host 端 port。
- 移除可避免 host 端 9000 / 9001 port 衝突、減少對外曝露面。
- 不影響 Xdebug（Xdebug 是 PHP 容器**主動連回** host 9003，跟 9000 listen port 無關）。

`api` (Swoole) 的 `"9501:9501"` **不動**，因為直接從 host 打 Swoole 測試是常見做法。

## 3. 驗證計畫

實作後依序執行：

1. `git diff` 檢視變更與本 spec 一致
2. `docker compose config` — 確認 compose 檔合法、變數展開正確
3. `docker compose down && docker compose up -d web php-fpm php-fpm8 mysql mysql8 redis` — 重啟核心服務
4. 從 host 瀏覽器存取任一虛擬主機（如 `front-api.local`），確認 nginx → php-fpm 鏈路仍通
5. 在 `php-fpm8` 容器內執行 `mysql80` 別名連線 → 確認 DB 通
6. 確認 `docker inspect php-fpm | grep -A2 Mounts` 中 `id_rsa` 有 `"RW": false`
7. `cp .env.example /tmp/.env.test && docker compose --env-file /tmp/.env.test config` — 驗證 example 可獨立 render

## 4. 風險與回退

| 風險 | 機率 | 影響 | 回退 |
|------|------|------|------|
| 開發機某流程依賴 host 端 9000 / 9001 連 FPM | 低 | 該流程中斷 | git revert 該變更 commit |
| `.dockerignore` 規則誤殺需要 COPY 的檔案 | 低 | 對應 service build 失敗 | 調整規則，本 spec 不影響現有 build context |
| `restart: always` → `unless-stopped` 在 host 重開機後不會自啟 | 低 | 需手動 `docker compose up -d` | 個別服務改回 `always` |

## 5. 提交策略

拆為 2 個 commit，依「設定資料」與「行為 / 安全性」分組，便於日後 bisect 與回退：

1. `chore: 對齊 .env.example 與 CLAUDE.md / .env 三方設定`（A1）
2. `chore: 統一 restart 策略、限制私鑰權限、補 .dockerignore 並收斂 FPM 對外 port`（A2 + A3 + A4 + A5）

## 6. 後續階段（不在本 spec）

- **B 階段**：抽出 `php-fpm` / `php-fpm8` 共用 base image、合併 RUN layer、裁減未用擴充、pin 版本
- **C 階段**：Xdebug trigger 模式、MySQL buffer pool、healthcheck、compose profiles 分組
