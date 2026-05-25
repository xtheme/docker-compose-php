# Docker-Compose 環境優化 — A 階段：設定整理 / 安全性

- 日期：2026-05-25
- 範圍：A 階段 + A6（PHP 容器 image 內非必要工具移除，提前自 B 階段抽出）
- 後續：B（映像檔進一步精簡 / 去重）、C（效能 / DX）為獨立階段，本 spec 不涵蓋

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
| 移除 ClickHouse 註解 | `#CLICKHOUSE_USER=...` | (刪除) | 目前 compose 已無 ClickHouse 服務；git history 仍可查 |

**關於 `MYSQL8_*` 變數**：目前 `docker-compose.yml` 的 `mysql8` service 與 `mysql` 共用 `MYSQL_DATABASE` / `MYSQL_USER` / `MYSQL_PASSWORD` / `MYSQL_ROOT_PASSWORD`。**本 spec 不在 `.env.example` 新增 `MYSQL8_*`**：若加上但 compose 未消費，會誤導開發者以為改了該值會生效，且 MySQL 初始化環境變數只在 volume 首次建立時起作用，事後發現偏差需 root 手動修正或破壞性重建 volume。是否拆成獨立 `MYSQL8_*` 變數（含 compose 變更與既有 volume 的遷移處理）留給後續階段評估。

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

### A6 — 移除 PHP 容器內非必要工具

**動機**：Oh My Zsh、Google Cloud CLI、Claude/Copilot CLI 在容器內幾乎不使用（日常開發都在 host 端進行），但每次 `docker build` 都要 clone repo、執行遠端安裝腳本、跑 `npm install -g` 與 `apt-get install google-cloud-cli`，維護成本高、build 時間長、image 體積大。

**Dockerfile 變更**（`php-fpm/Dockerfile` 與 `php-fpm8/Dockerfile` 兩者同步）：

| 區塊 | 變更 |
|------|------|
| 系統套件區塊（line 5–22） | 從 `apt-get install` 清單移除 `zsh` |
| Claude / Copilot CLI（line 90–92） | 整段 `RUN npm install -g @anthropic-ai/claude-code @github/copilot` 移除 |
| Google Cloud CLI（line 94–99） | 整段 gcloud apt repo 加入與 `apt-get install -y google-cloud-cli` 移除 |
| Oh My Zsh 與 plugin（line 104–122） | 完整移除 Oh My Zsh 安裝、3 個 plugin 的 `git clone`、`.zshrc` plugin 啟用、`chsh -s $(which zsh)` |
| aliases 寫入 `.zshrc`（line 136–139） | 移除（只保留寫入 `.bashrc` 部分） |

最終 PHP 容器內 shell 為 `bash`（`php:*-fpm` 官方 image 預設），`aliases.sh` 透過 `.bashrc` 載入。

**`docker-compose.yml` 變更**：

| service | 移除掛載 |
|---------|----------|
| `php-fpm` | `~/.claude:/root/.claude` |
| `php-fpm` | `~/.copilot:/root/.copilot` |
| `php-fpm8` | `~/.claude:/root/.claude` |
| `php-fpm8` | `~/.copilot:/root/.copilot` |
| `php-fpm8` | `~/.config/gcloud:/root/.config/gcloud` |

**文件同步變更**：

- `CLAUDE.md`「安全注意事項」段落：將「容器內的 `~/.ssh/`、`~/.gitconfig`、`~/.claude` 為 host 端掛載」改為「`~/.ssh/`、`~/.gitconfig` 為 host 端掛載」
- 若 `AGENTS.md` 有對應內容（實作時掃描確認），同步修正

**不動的部分**：

- `aliases.sh` 內容（`cdfront` 等別名仍可用）
- `default-mysql-client` 套件（容器內 `mysql57` / `mysql80` 別名需要）
- 其他開發必要套件（`git`、`composer`、`nodejs` 等）

**已知影響**：

- 容器內無法直接執行 `claude` / `copilot` / `gcloud` 指令 — 若有 host 端 script 透過 `docker compose exec` 跑這三個 CLI，需先改回 host 端執行
- 容器內 shell 不再有 zsh 補全 / 高亮 — 個人習慣調整
- 對應 commit `d84a32a`（升級 Zsh）與 `2b30853`（雙 shell）會被反向，commit message 需提及

## 3. 驗證計畫

實作後依序執行：

1. `git diff` 檢視變更與本 spec 一致
2. `docker compose config` — 確認 compose 檔合法、變數展開正確
3. `docker compose build php-fpm php-fpm8` — A6 需重建 image，確認 build 成功
4. `docker compose down && docker compose up -d web php-fpm php-fpm8 mysql mysql8 redis` — 重啟核心服務
5. 從 host 瀏覽器存取任一虛擬主機（如 `front-api.local`），確認 nginx → php-fpm 鏈路仍通
6. 在 `php-fpm8` 容器內執行 `mysql80` 別名連線 → 確認 DB 通
7. **A6 工具移除驗證（兩容器 × 全工具矩陣，每項獨立報告，避免 `&&` 鏈短路）**：

   ```bash
   for svc in php-fpm php-fpm8; do
     for bin in zsh claude copilot gcloud; do
       docker compose exec -T "$svc" sh -c "command -v $bin >/dev/null && echo FAIL:$svc:$bin || echo ok:$svc:$bin"
     done
     docker compose exec -T "$svc" sh -c 'echo "shell=$0"; cdfront >/dev/null 2>&1 && echo "alias_ok=$(pwd)"'
   done
   ```

   預期：4 × 2 = 8 行 `ok:<svc>:<bin>`，`shell=` 行非 `zsh`，`alias_ok=/var/www/API_Frontend/_release`。任一 `FAIL:` 即代表該容器有殘留工具。

8. **A4 SSH 私鑰唯讀驗證（兩容器都查）**：

   ```bash
   for svc in php-fpm php-fpm8; do
     docker inspect "$svc" --format '{{range .Mounts}}{{if eq .Destination "/root/.ssh/id_rsa"}}{{.Destination}} RW={{.RW}}{{println}}{{end}}{{end}}'
   done
   ```

   預期：兩行皆 `/root/.ssh/id_rsa RW=false`。

9. `cp .env.example /tmp/.env.test && docker compose --env-file /tmp/.env.test config` — 驗證 example 可獨立 render

## 4. 風險與回退

| 風險 | 機率 | 影響 | 回退 |
|------|------|------|------|
| 開發機某流程依賴 host 端 9000 / 9001 連 FPM | 低 | 該流程中斷 | git revert 該變更 commit |
| `.dockerignore` 規則誤殺需要 COPY 的檔案 | 低 | 對應 service build 失敗 | 調整規則，本 spec 不影響現有 build context |
| `restart: always` → `unless-stopped` 在 host 重開機後不會自啟 | 低 | 需手動 `docker compose up -d` | 個別服務改回 `always` |
| A6 移除工具後，舊有 docker-compose exec 腳本依賴失敗 | 低 | 該腳本中斷 | 改用 host 端執行；或 git revert A6 commit |
| `chsh -s $(which zsh)` 移除後 root 預設 shell 殘留為 zsh（image 內未升級時） | 低 | 既有容器直到 rebuild 前仍為 zsh | `docker compose build --no-cache php-fpm php-fpm8` 強制重建 |

## 5. 提交策略

拆為 3 個 commit，便於日後 bisect 與回退：

1. `chore: 對齊 .env.example 與 CLAUDE.md / .env 三方設定`（A1）
2. `chore: 統一 restart 策略、限制私鑰權限、補 .dockerignore 並收斂 FPM 對外 port`（A2 + A3 + A4 + A5）
3. `refactor: 移除 PHP 容器內 Oh My Zsh、gcloud、Claude/Copilot CLI 等非必要工具`（A6 + 同步 CLAUDE.md / AGENTS.md）

A6 獨立 commit 的原因：需 rebuild image，影響範圍與前兩個 commit 不同；獨立 commit 可在發現問題時單獨回退而不影響 A1–A5 的設定整理成果。

## 6. 後續階段（不在本 spec）

- **B 階段**：抽出 `php-fpm` / `php-fpm8` 共用 base image、合併 RUN layer、裁減未用 PHP 擴充與系統套件（`ffmpeg`、`wrk`、未使用的 PHP 擴充等）、pin 版本
- **C 階段**：Xdebug trigger 模式、MySQL buffer pool、healthcheck、compose profiles 分組
