# CLAUDE.md — Docker-Compose 開發環境

## 專案概述

這是一個用於本地開發的 Docker 容器編排環境，支援多版本 PHP、MySQL、Redis 等服務。主要服務對象為 Laravel 框架的應用開發。

## 技術棧

| 服務 | 技術 | 版本 |
|------|------|------|
| Web 伺服器 | Nginx | alpine |
| PHP (舊版) | PHP-FPM | 7.3 (預設) |
| PHP (新版) | PHP-FPM8 | 8.4 |
| 資料庫 (舊) | MySQL | 5.7 |
| 資料庫 (新) | MySQL8 | 8.0.30 |
| 快取 | Redis | latest |

## 目錄結構

```
Docker-Compose/
├── docker-compose.yml   # 主要編排設定
├── .env                 # 環境變數（不納入 git）
├── .env.example         # 環境變數範本
├── nginx/               # Nginx 設定與虛擬主機
│   ├── nginx.conf
│   ├── upstream.conf    # 定義 php-upstream / php-upstream8
│   └── sites/           # 各專案的 .conf 虛擬主機設定
├── php-fpm/             # PHP 7.x 容器
│   ├── Dockerfile
│   ├── conf.d/          # Xdebug 設定
│   ├── ini/             # 各 PHP 版本的 php.ini
│   └── php-fpm.d/       # FPM 進程池設定
├── php-fpm8/            # PHP 8.x 容器
├── mysql/               # MySQL 5.7
├── mysql8/              # MySQL 8.0
└── redis/               # Redis
```

## 環境變數

複製 `.env.example` 為 `.env` 並依實際情況調整：

```bash
cp .env.example .env
```

關鍵變數：

| 變數 | 說明 | 預設值 |
|------|------|--------|
| `WORKSPACE_PATH` | 應用程式碼根目錄 | `../www` |
| `PHP_VERSION` | PHP 7.x 版本 | `7.3` |
| `PHP8_VERSION` | PHP 8.x 版本 | `8.4` |
| `TIMEZONE` | 時區（同時套用至 php-fpm/php-fpm8/mysql/mysql8） | `UTC` |
| `NODEJS_VERSION` | NodeJS major 版本（留空 = 自動安裝當前 Active LTS） | 留空 |
| `INSTALL_ZSH` | 是否在 php-fpm / php-fpm8 容器內安裝 zsh（`true` / `false`） | `false` |
| `MYSQL_PORT` | MySQL 5.7 外部埠 | `3305` |
| `MYSQL8_PORT` | MySQL 8.0 外部埠 | `3306` |
| `REDIS_PORT` | Redis 埠 | `6379` |

## 開發工作流程（重要）

1. **PHP 相關命令進容器執行**：`~/Workspace/*` 子專案的 `composer` / `php` / `artisan` 操作須進 `php-fpm8` 容器執行，不要在 host 端直接跑（避免 PHP 版本與權限差異）。**`git`（含 commit / push）在 host 端直接做即可，不需進容器**（git 不依賴 PHP；hooks 安裝在 repo 的 `.git/hooks`，host 端一樣會觸發）。
2. **容器間連線用服務名稱**：應用連 DB / Redis 一律用 `mysql`、`mysql8`、`redis`，不用 `localhost`。
3. **標準步驟**：PHP 命令進容器 → `cdXxx` 切目錄 → 執行 → 驗證；git 直接在 host 對應路徑操作。
4. **GitLab 憑證**：本機 GitLab 私服為 `gitlab.terpro.com:1022`（非 gitlab.com），SSH key `~/.ssh/id_ed25519` 已透過 volume 掛入 php-fpm 容器。

## 容器內別名（php-fpm / php-fpm8）

定義於 `php-fpm/aliases.sh`、`php-fpm8/aliases.sh`：

| 別名 | 用途 |
|------|------|
| `pa`, `artisan` | `php artisan` |
| `tinker` | `php artisan tinker` |
| `mysql57`, `mysql80` | 互動式連線 MySQL 5.7 / 8.0（root）|
| `cdfront` | `cd /var/www/API_Frontend/_release` |
| `cdagent` | `cd /var/www/API_Agent/_release` |
| `cdexternal` | `cd /var/www/API_External/_release` |
| `cdinternal` | `cd /var/www/api-internal/_release` |
| `cdcronjob` | `cd /var/www/RD-Studio-01/_release` |
| `cdsocket` | `cd /var/www/WEB_CustomerServiceSocket/_release` |

## 常用指令

### 啟動服務

```bash
# 啟動核心服務
docker-compose up -d web php-fpm php-fpm8 mysql mysql8 redis

# 啟動全部服務
docker-compose up -d

# 重新建置並啟動
docker-compose up -d --build php-fpm
docker-compose up -d --build php-fpm8
```

### 進入容器

```bash
docker-compose exec php-fpm bash
docker-compose exec php-fpm8 bash
docker-compose exec web sh
docker-compose exec mysql mysql -u user -p
```

### 查看日誌

```bash
docker-compose logs -f web
docker-compose logs -f php-fpm
docker-compose logs -f mysql
```

### 停止服務

```bash
docker-compose down
docker-compose down -v   # 含 volumes（謹慎使用）
```

## 新增虛擬主機

1. 在 `nginx/sites/` 建立新的 `.conf` 檔案
2. 根據 PHP 版本選擇上游：
   - PHP 7.x → `fastcgi_pass php-upstream;`
   - PHP 8.x → `fastcgi_pass php-upstream8;`
3. 在 `docker-compose.yml` 的 `php-fpm` / `php-fpm8` `extra_hosts` 加入對應的 `.local` host
4. 重新啟動 Nginx：`docker-compose restart web`

## Xdebug 設定

配置檔位於 `php-fpm/conf.d/xdebug.ini`：

```ini
xdebug.mode = debug,develop
xdebug.start_with_request = yes
xdebug.client_host = host.docker.internal
xdebug.client_port = 9003
```

IDE 設定 Listen Port 為 `9003`。

## Commit 與 PR 規範

採用 Conventional Commits（標題以中文描述）：

```
<type>: <繁體中文簡述>
```

常用 `type`：

| Type | 用途 |
|------|------|
| `feat` | 新功能 / 新服務 |
| `fix` | 修正錯誤設定或行為 |
| `chore` | 維護性調整（時區、重啟策略、文件）|
| `docs` | 純文件變更 |
| `refactor` | 不影響行為的重構 |

範例（取自實際 git log）：

```
feat: 映射 GitLab 憑證至 PHP 容器
fix: 註解 PHP 8.4 已棄用的 session sid 相關設定
chore: 設定 MySQL 8 預設時區為 UTC
```

## 安全注意事項

- `.env` 不納入 git，請勿提交機密資訊（密碼、token、SSH key）
- MySQL 資料目錄 (`mysql/data/`, `mysql8/data/`) 不納入 git
- 範例設定（如 `.env.example`）一律以佔位符表示，不放實際憑證
- 對外開放埠口僅供本機開發，請勿暴露至公網
- 容器內的 `~/.ssh/`、`~/.gitconfig` 為 host 端掛載，操作會影響 host

## 其他注意事項

- 修改 Dockerfile 後需重新建置：`docker-compose up -d --build <service>`
- MySQL 5.7 對外埠為 `3305`，MySQL 8.0 為 `3306`（可在 `.env` 調整）
- 所有服務（php-fpm/php-fpm8/mysql/mysql8）時區統一由 `.env` 的 `TIMEZONE` 控制，預設 `UTC`
- PHP 8.4 已停用 `session.sid_*` 相關設定，請勿在 `php.ini` 加回（commit `4fd1111`）
- SSH key 走 `~/.ssh/id_ed25519`（搭配私服 GitLab `gitlab.terpro.com:1022`）；`.env.example` 內 `id_rsa` 為通用範例

---

**最後更新**：2026-05-14

