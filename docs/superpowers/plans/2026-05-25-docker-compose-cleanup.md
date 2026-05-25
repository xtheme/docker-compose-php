# Docker-Compose A 階段優化實作計畫

> **給代理工作者：** 必要子技能：使用 superpowers:subagent-driven-development（推薦）或 superpowers:executing-plans 逐 task 執行本計畫。步驟以核取框（`- [ ]`）追蹤。

**目標：** 套用 `docs/superpowers/specs/2026-05-25-docker-compose-cleanup-design.md` 中的 A1–A6 變更：對齊 `.env.example`、統一 restart 策略、新增 `.dockerignore`、SSH 私鑰改為唯讀掛載、移除 PHP-FPM 對 host 不必要的 port，並從兩個 PHP 容器中移除 Oh My Zsh / Google Cloud CLI / Claude / Copilot CLI。

**整體架構：** 三個依序的 commit ——（1）只動 `.env.example`；（2）`docker-compose.yml` 的設定與安全性集合；（3）A6 涵蓋 Dockerfile、compose 卷掛載、文件同步。只有 A6 需要 `docker compose build`，A1–A5 都是純設定編輯。

**技術棧：** Docker Compose v2、Dockerfile（PHP 7.3 / 8.4 官方 `php:*-fpm` image）、容器內 bash。

---

## 檔案結構

| 檔案 | 動作 | 用途 |
|------|------|------|
| `.env.example` | 修改 | 對齊 `.env` 與 CLAUDE.md 的 port / Node 版本；移除過時的 ClickHouse 區塊（A1） |
| `docker-compose.yml` | 修改 | 統一 restart 策略（A2）、SSH `:ro`（A4）、移除 FPM 對外 port（A5）、移除 AI 工具卷（A6） |
| `.dockerignore` | 新增 | 瘦化 build context，避免把 `mysql/data/`、`.git/`、`.idea/`、`.claude/` 等帶進 image 邊界（A3） |
| `php-fpm/Dockerfile` | 修改 | 移除 `zsh` apt 套件、Claude/Copilot CLI npm install、Google Cloud CLI 安裝、Oh My Zsh + plugin + chsh、`.zshrc` 寫入（A6） |
| `php-fpm8/Dockerfile` | 修改 | 與 php-fpm 同步（A6） |
| `CLAUDE.md` | 修改 | 從「容器內 host 掛載」清單移除 `~/.claude`（A6 文件同步） |
| `AGENTS.md` | 修改 | 與 CLAUDE.md 同（第 187 行） |

**本計畫不新增測試** —— 這是基礎設施清理，沒有應用程式碼變更。驗證依靠 `docker compose config` 解析、`docker compose build`、以及 spec 中的驗證矩陣。

---

## Task 1：A1 — 改寫 `.env.example`

**檔案：**
- 修改：`/Users/rb/Docker-Compose/.env.example`

- [ ] **Step 1：先確認當前內容**

```bash
cat /Users/rb/Docker-Compose/.env.example
```

預期當前內容應包含 `MYSQL_PORT=3306`、`MYSQL8_PORT=3308`、`NODEJS_VERSION=23`、以及兩行 `#CLICKHOUSE_*`。

- [ ] **Step 2：用以下確切內容覆寫 `.env.example`**

用 `Write` 工具將 `/Users/rb/Docker-Compose/.env.example` 替換為：

```dotenv
WORKSPACE_PATH=../www
SSH_KEY_PATH=~/.ssh/id_rsa

TIMEZONE=Asia/Shanghai
PHP_VERSION=7.3
NODEJS_VERSION=20

MYSQL_VERSION=5.7
MYSQL_CONNECTION=mysql
MYSQL_HOST=localhost
MYSQL_PORT=3305
MYSQL_DATABASE=database
MYSQL_USER=user
MYSQL_PASSWORD=pass
MYSQL_ROOT_PASSWORD=pass

PHP8_VERSION=8.4
MYSQL8_VERSION=8.0.30
MYSQL8_PORT=3306

REDIS_PORT=6379
REDIS_CLUSTER_PORT_RANGE=7000-7005
```

變更項目：

| Key | 變更前 | 變更後 |
|-----|--------|--------|
| `NODEJS_VERSION` | `23` | `20` |
| `MYSQL_PORT` | `3306` | `3305` |
| `MYSQL8_PORT` | `3308` | `3306` |
| `#CLICKHOUSE_USER` / `#CLICKHOUSE_PASSWORD` | 存在（已註解） | 移除 |

**不要新增 `MYSQL8_DATABASE` / `MYSQL8_USER` / `MYSQL8_PASSWORD` / `MYSQL8_ROOT_PASSWORD`** —— 依 spec §A1，`mysql8` service 目前仍消費 `MYSQL_*`，加上 `MYSQL8_*` 反而會誤導開發者。

- [ ] **Step 3：驗證 example 可獨立 render compose**

```bash
cd /Users/rb/Docker-Compose
cp .env.example /tmp/.env.test
docker compose --env-file /tmp/.env.test config > /tmp/compose-rendered.yml
echo "exit=$?"
grep -E 'MYSQL_PORT|MYSQL8_PORT|NODEJS_VERSION' /tmp/.env.test
```

預期：
- `exit=0`
- `MYSQL_PORT=3305`、`MYSQL8_PORT=3306`、`NODEJS_VERSION=20`
- `docker compose config` 不應印出任何「未定義變數」警告

- [ ] **Step 4：Commit（3 個 commit 中的第 1 個）**

```bash
cd /Users/rb/Docker-Compose
git add .env.example
git commit -m "chore: 對齊 .env.example 與 CLAUDE.md / .env 三方設定

- MYSQL_PORT 3306 → 3305、MYSQL8_PORT 3308 → 3306 對齊 .env 與
  CLAUDE.md 中表格說明的對外埠
- NODEJS_VERSION 23 → 20 對齊 .env 實際使用的 LTS 版本
- 移除已不存在於 docker-compose.yml 的 ClickHouse 註解區塊

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

驗證：

```bash
git log --oneline -1
git show --stat HEAD
```

---

## Task 2：A2 — 統一 restart 策略

**檔案：**
- 修改：`/Users/rb/Docker-Compose/docker-compose.yml`（2 處）

- [ ] **Step 1：將 `web` service 的 restart 改為 `unless-stopped`**

用 `Edit` 工具於 `/Users/rb/Docker-Compose/docker-compose.yml`：

```
old_string:
        depends_on:
            - php-fpm
        restart: always
        networks:
            - default

    #  PHP-FPM workspace for admin service
    php-fpm:

new_string:
        depends_on:
            - php-fpm
        restart: unless-stopped
        networks:
            - default

    #  PHP-FPM workspace for admin service
    php-fpm:
```

- [ ] **Step 2：將 `open-webui` service 的 restart 改為 `unless-stopped`**

用 `Edit`：

```
old_string:
    open-webui:
        image: ghcr.io/open-webui/open-webui:main
        container_name: open-webui
        restart: always

new_string:
    open-webui:
        image: ghcr.io/open-webui/open-webui:main
        container_name: open-webui
        restart: unless-stopped
```

- [ ] **Step 3：確認沒有 `restart: always` 殘留**

```bash
cd /Users/rb/Docker-Compose
grep -nE '^\s*restart:' docker-compose.yml
```

預期：每個未被註解的 service 都是 `restart: unless-stopped`。被註解的 `rabbitmq` / `gitlab-runner` / `elasticsearch` 區塊內可能還是 `always`，那可接受。

---

## Task 3：A3 — 新增 `.dockerignore`

**檔案：**
- 新增：`/Users/rb/Docker-Compose/.dockerignore`

- [ ] **Step 1：確認檔案不存在**

```bash
ls -la /Users/rb/Docker-Compose/.dockerignore 2>&1
```

預期：`No such file or directory`。

- [ ] **Step 2：用 spec 中的內容建立 `.dockerignore`**

用 `Write` 寫入 `/Users/rb/Docker-Compose/.dockerignore`，內容如下：

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

# Docs (not consumed during build)
docs/
README.md
CLAUDE.md
AGENTS.md
```

- [ ] **Step 3：檢查檔案**

```bash
wc -l /Users/rb/Docker-Compose/.dockerignore
head -5 /Users/rb/Docker-Compose/.dockerignore
```

預期：約 30 行（空行誤差可接受），第一個有內容的行為 `# Version control & IDE`。

---

## Task 4：A4 — SSH 私鑰改為唯讀掛載

**檔案：**
- 修改：`/Users/rb/Docker-Compose/docker-compose.yml`（2 處）

- [ ] **Step 1：修改 `php-fpm` 服務的私鑰掛載**

用 `Edit` 於 `/Users/rb/Docker-Compose/docker-compose.yml`。下列四行 anchor 中的 `php${PHP_VERSION}.ini` 唯一鎖定 `php-fpm`（`php-fpm8` 使用 `${PHP8_VERSION}`，不會誤中）：

```
old_string:
        volumes:
            - ${WORKSPACE_PATH}:/var/www:cached
            - ./php-fpm/ini/php${PHP_VERSION}.ini:/usr/local/etc/php/php.ini
            - ${SSH_KEY_PATH}:/root/.ssh/id_rsa
            - ${SSH_KEY_PATH}.pub:/root/.ssh/id_rsa.pub:ro

new_string:
        volumes:
            - ${WORKSPACE_PATH}:/var/www:cached
            - ./php-fpm/ini/php${PHP_VERSION}.ini:/usr/local/etc/php/php.ini
            - ${SSH_KEY_PATH}:/root/.ssh/id_rsa:ro
            - ${SSH_KEY_PATH}.pub:/root/.ssh/id_rsa.pub:ro
```

- [ ] **Step 2：修改 `php-fpm8` 服務的私鑰掛載**

```
old_string:
        volumes:
            - ${WORKSPACE_PATH}:/var/www:cached
            - ./php-fpm8/ini/php${PHP8_VERSION}.ini:/usr/local/etc/php/php.ini
            - ${SSH_KEY_PATH}:/root/.ssh/id_rsa
            - ${SSH_KEY_PATH}.pub:/root/.ssh/id_rsa.pub:ro

new_string:
        volumes:
            - ${WORKSPACE_PATH}:/var/www:cached
            - ./php-fpm8/ini/php${PHP8_VERSION}.ini:/usr/local/etc/php/php.ini
            - ${SSH_KEY_PATH}:/root/.ssh/id_rsa:ro
            - ${SSH_KEY_PATH}.pub:/root/.ssh/id_rsa.pub:ro
```

- [ ] **Step 3：確認兩個掛載都帶上 `:ro`**

```bash
cd /Users/rb/Docker-Compose
grep -n 'id_rsa' docker-compose.yml
```

預期：四行 `id_rsa`，其中 `id_rsa`（私鑰）的兩行結尾為 `:ro`，`id_rsa.pub`（公鑰）的兩行也是 `:ro`。

---

## Task 5：A5 — 移除 PHP-FPM 對 host 的 port

**檔案：**
- 修改：`/Users/rb/Docker-Compose/docker-compose.yml`（2 處 `ports:`）

- [ ] **Step 1：移除 `php-fpm` 的 `ports:` 區塊**

用 `Edit`：

```
old_string:
        container_name: php-fpm
        ports:
            - "9000:9000"
        volumes:

new_string:
        container_name: php-fpm
        volumes:
```

- [ ] **Step 2：移除 `php-fpm8` 的 `ports:` 區塊**

```
old_string:
        container_name: php-fpm8
        ports:
            - "9001:9000"
        volumes:

new_string:
        container_name: php-fpm8
        volumes:
```

- [ ] **Step 3：確認只剩預期的 port**

```bash
cd /Users/rb/Docker-Compose
grep -nB1 -A1 -E '"[0-9]+:[0-9]+"' docker-compose.yml | head -40
```

預期 port 清單：
- `web`：`"80:80"`、`"443:443"`
- `api`（Swoole）：`"9501:9501"`
- `mysql`：`"${MYSQL_PORT}:3306"`
- `mysql8`：`"${MYSQL8_PORT}:3306"`
- `redis`：`"${REDIS_PORT}:6379"`
- `open-webui`：`"3000:8080"`

不應再有 `9000:9000` 或 `9001:9000`。

---

## Task 6：驗證 A2–A5 整組變更並 commit（3 個 commit 中的第 2 個）

**檔案：** 本 task 不再修改檔案，只做驗證與 commit。

- [ ] **Step 1：render compose 抓語法錯誤**

```bash
cd /Users/rb/Docker-Compose
docker compose config > /tmp/compose-after-a2-a5.yml
echo "exit=$?"
```

預期：`exit=0`。若出現 `level=warning msg="services.x: ..."` 之類的警告，要先看是不是良性訊息（例如環境變數 default）。錯誤必須為零。

- [ ] **Step 2：檢查 render 後的 yaml 反映了新的狀態**

```bash
grep -E 'restart:|id_rsa|"9000:|"9001:' /tmp/compose-after-a2-a5.yml
```

預期：所有 `restart:` 都是 `unless-stopped`、所有 `id_rsa`（非 `.pub`）都是唯讀、不再出現 `9000:` 或 `9001:`。

- [ ] **Step 3：用新設定重啟核心服務**

```bash
cd /Users/rb/Docker-Compose
docker compose up -d web php-fpm php-fpm8 mysql mysql8 redis
docker compose ps
```

預期：六個服務都 `running` 或 `healthy`。

- [ ] **Step 4：煙霧測試 nginx → PHP-FPM 經 service network 是否仍通**

```bash
docker compose exec -T web sh -c 'wget -qO- --timeout=3 http://php-fpm:9000 2>&1 | head -1 ; echo "status=$?"'
docker compose exec -T web sh -c 'wget -qO- --timeout=3 http://php-fpm8:9000 2>&1 | head -1 ; echo "status=$?"'
```

PHP-FPM 不講 HTTP，所以 wget 一定會在協定層失敗 —— 重點是 TCP 連線成功代表容器間 9000 仍可達。看 `status=`，預期是 `0`、`1` 或 `8`（HTTP 層失敗），**不是** `4` / `5`（網路不可達）。如果 `status=4`，代表 FPM port 真的不通，A5 把可達性弄壞了。

更可靠的檢測是經由 nginx：

```bash
curl -sS -o /dev/null -w "%{http_code}\n" -H "Host: front-api.local" http://127.0.0.1/ || echo "curl-failed"
```

預期：來自 PHP 的 200 / 302 / 404（代表 nginx 透過 FPM 成功路由）。如果是 502 代表 nginx 連不到 FPM，A5 弄壞了路徑 —— 重新加回 `ports:` 區塊並調查。

- [ ] **Step 5：驗證兩個容器的 SSH 私鑰都是唯讀**

```bash
for svc in php-fpm php-fpm8; do
  docker inspect "$svc" --format '{{range .Mounts}}{{if eq .Destination "/root/.ssh/id_rsa"}}{{.Destination}} RW={{.RW}}{{println}}{{end}}{{end}}'
done
```

預期輸出：

```
/root/.ssh/id_rsa RW=false
/root/.ssh/id_rsa RW=false
```

若任一行 `RW=true` 代表 `:ro` 沒生效 —— 檢查 Edit 結果並 `docker compose up -d` 重建容器。

- [ ] **Step 6：Commit（3 個 commit 中的第 2 個）**

```bash
cd /Users/rb/Docker-Compose
git add docker-compose.yml .dockerignore
git commit -m "chore: 統一 restart 策略、限制私鑰權限、補 .dockerignore 並收斂 FPM 對外 port

- web、open-webui 由 always 改 unless-stopped，與其他服務一致
- php-fpm / php-fpm8 的 SSH 私鑰掛載加上 :ro，避免容器內 root 誤
  寫覆蓋 host 私鑰
- 新增 .dockerignore 排除 .git、.idea、mysql/data 等不該進入 build
  context 的目錄
- 移除 php-fpm 9000:9000、php-fpm8 9001:9000 對 host 的曝露，nginx
  經 docker network 直接連 service name 不需要這兩個埠

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

驗證：

```bash
git show --stat HEAD
```

應列出兩個檔案異動：`.dockerignore`（新增）、`docker-compose.yml`（修改）。

---

## Task 7：A6 — 從 `php-fpm/Dockerfile` 移除非必要工具

**檔案：**
- 修改：`/Users/rb/Docker-Compose/php-fpm/Dockerfile`

此 task 在同一檔案做 5 處精準編輯。**請由上往下依序套用**，避免前面的編輯讓後面的 anchor 失效。

- [ ] **Step 1：從 apt 套件清單移除 `zsh`**

用 `Edit`：

```
old_string:
    ffmpeg \
    zsh \
    default-mysql-client

new_string:
    ffmpeg \
    default-mysql-client
```

- [ ] **Step 2：移除 Claude / Copilot CLI 安裝**

```
old_string:
# Install Claude CLI & GitHub Copilot CLI
RUN npm install -g @anthropic-ai/claude-code @github/copilot

# Install Google Cloud CLI

new_string:
# Install Google Cloud CLI
```

註：這一步保留下一段的 `# Install Google Cloud CLI` 標題，Step 3 再移除整段。

- [ ] **Step 3：移除 Google Cloud CLI 安裝區塊**

```
old_string:
# Install Google Cloud CLI
RUN curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" \
       > /etc/apt/sources.list.d/google-cloud-sdk.list \
    && apt-get update \
    && apt-get install -y google-cloud-cli

# Clear cache

new_string:
# Clear cache
```

- [ ] **Step 4：移除 Oh My Zsh、plugin clone、plugin 啟用、`chsh`**

```
old_string:
# Install Oh My Zsh
RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

# Install zsh plugins: autosuggestions + syntax highlighting + completions
RUN git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions \
        ${ZSH_CUSTOM:-/root/.oh-my-zsh/custom}/plugins/zsh-autosuggestions && \
    git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting \
        ${ZSH_CUSTOM:-/root/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting && \
    git clone --depth=1 https://github.com/zsh-users/zsh-completions \
        ${ZSH_CUSTOM:-/root/.oh-my-zsh/custom}/plugins/zsh-completions

# Enable plugins in .zshrc and configure autosuggestions
RUN sed -i 's/^plugins=(git)/plugins=(git zsh-autosuggestions zsh-syntax-highlighting zsh-completions docker composer)/' /root/.zshrc && \
    echo 'autoload -U compinit && compinit' >> /root/.zshrc && \
    echo 'ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=244"' >> /root/.zshrc && \
    echo 'ZSH_AUTOSUGGEST_STRATEGY=(history completion)' >> /root/.zshrc

# Set zsh as default shell
RUN chsh -s $(which zsh)

# Timezone

new_string:
# Timezone
```

**Anchor 注意事項：** php-fpm 的 `ZSH_AUTOSUGGEST_STRATEGY` 行為 `(history completion)`；plugin 註解行為 `# Install zsh plugins: autosuggestions + syntax highlighting + completions`。php-fpm8 與這兩處可能略有不同 —— 詳見 Task 8 的 Step 0。

- [ ] **Step 5：移除 aliases 安裝中寫到 `.zshrc` 的部分（`.bashrc` 保留）**

```
old_string:
RUN sed -i 's/\r//' /root/aliases.sh && \
    echo "" >> /root/.bashrc && \
    echo "# Load Custom Aliases" >> /root/.bashrc && \
    echo "source /root/aliases.sh" >> /root/.bashrc && \
    echo "" >> /root/.bashrc && \
    echo "" >> /root/.zshrc && \
    echo "# Load Custom Aliases" >> /root/.zshrc && \
    echo "source /root/aliases.sh" >> /root/.zshrc && \
    echo "" >> /root/.zshrc

new_string:
RUN sed -i 's/\r//' /root/aliases.sh && \
    echo "" >> /root/.bashrc && \
    echo "# Load Custom Aliases" >> /root/.bashrc && \
    echo "source /root/aliases.sh" >> /root/.bashrc && \
    echo "" >> /root/.bashrc
```

- [ ] **Step 6：確認所有應移除的字串都已消失**

```bash
cd /Users/rb/Docker-Compose
grep -nE 'zsh|claude-code|@github/copilot|google-cloud|ohmyzsh|chsh' php-fpm/Dockerfile
```

預期：輸出為空。

```bash
wc -l php-fpm/Dockerfile
tail -20 php-fpm/Dockerfile
```

預期：檔案約 75–80 行（由 141 行縮減），結尾為 timezone + aliases + `WORKDIR /var/www` 區塊。

---

## Task 8：A6 — 從 `php-fpm8/Dockerfile` 移除非必要工具

**檔案：**
- 修改：`/Users/rb/Docker-Compose/php-fpm8/Dockerfile`

以下 5 處編輯與 Task 7 形狀相同，但每段 inline 重複以便此 task 可獨立執行。**請由上往下依序套用**。

- [ ] **Step 0：先確認此檔案中的 `ZSH_AUTOSUGGEST_STRATEGY` 值**

兩個 Dockerfile 此處可能不同（`(history completion)` 或 `(git completion)`）。先看：

```bash
grep -n 'ZSH_AUTOSUGGEST_STRATEGY' /Users/rb/Docker-Compose/php-fpm8/Dockerfile
```

若實際值與 Step 4 anchor 中的不同，先把 Step 4 的 `old_string` 改成檔案的實際值，再執行 `Edit`，否則會比對失敗。

- [ ] **Step 1：從 apt 套件清單移除 `zsh`**

用 `Edit` 於 `/Users/rb/Docker-Compose/php-fpm8/Dockerfile`：

```
old_string:
    ffmpeg \
    zsh \
    default-mysql-client

new_string:
    ffmpeg \
    default-mysql-client
```

- [ ] **Step 2：移除 Claude / Copilot CLI 安裝**

```
old_string:
# Install Claude CLI & GitHub Copilot CLI
RUN npm install -g @anthropic-ai/claude-code @github/copilot

# Install Google Cloud CLI

new_string:
# Install Google Cloud CLI
```

- [ ] **Step 3：移除 Google Cloud CLI 安裝區塊**

```
old_string:
# Install Google Cloud CLI
RUN curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" \
       > /etc/apt/sources.list.d/google-cloud-sdk.list \
    && apt-get update \
    && apt-get install -y google-cloud-cli

# Clear cache

new_string:
# Clear cache
```

- [ ] **Step 4：移除 Oh My Zsh、plugin clone、plugin 啟用、`chsh`**

```
old_string:
# Install Oh My Zsh
RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

# Install zsh plugins: autosuggestions (Fish-like history suggestions) + syntax highlighting
RUN git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions \
        ${ZSH_CUSTOM:-/root/.oh-my-zsh/custom}/plugins/zsh-autosuggestions && \
    git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting \
        ${ZSH_CUSTOM:-/root/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting && \
    git clone --depth=1 https://github.com/zsh-users/zsh-completions \
        ${ZSH_CUSTOM:-/root/.oh-my-zsh/custom}/plugins/zsh-completions

# Enable plugins in .zshrc and configure autosuggestions
RUN sed -i 's/^plugins=(git)/plugins=(git zsh-autosuggestions zsh-syntax-highlighting zsh-completions docker composer)/' /root/.zshrc && \
    echo 'autoload -U compinit && compinit' >> /root/.zshrc && \
    echo 'ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=244"' >> /root/.zshrc && \
    echo 'ZSH_AUTOSUGGEST_STRATEGY=(history completion)' >> /root/.zshrc

# Set zsh as default shell
RUN chsh -s $(which zsh)

# Timezone

new_string:
# Timezone
```

**若 Step 0 顯示 `ZSH_AUTOSUGGEST_STRATEGY` 為不同值（如 `(git completion)`）**，先把上面 `old_string` 對應行改成實際值再執行 `Edit`，否則比對會失敗。Plugin 註解行也可能是 `# Install zsh plugins: autosuggestions + syntax highlighting + completions` 而非 `(Fish-like history suggestions)`，要對齊檔案實際值。

- [ ] **Step 5：移除 aliases 安裝中寫到 `.zshrc` 的部分（`.bashrc` 保留）**

```
old_string:
RUN sed -i 's/\r//' /root/aliases.sh && \
    echo "" >> /root/.bashrc && \
    echo "# Load Custom Aliases" >> /root/.bashrc && \
    echo "source /root/aliases.sh" >> /root/.bashrc && \
    echo "" >> /root/.bashrc && \
    echo "" >> /root/.zshrc && \
    echo "# Load Custom Aliases" >> /root/.zshrc && \
    echo "source /root/aliases.sh" >> /root/.zshrc && \
    echo "" >> /root/.zshrc

new_string:
RUN sed -i 's/\r//' /root/aliases.sh && \
    echo "" >> /root/.bashrc && \
    echo "# Load Custom Aliases" >> /root/.bashrc && \
    echo "source /root/aliases.sh" >> /root/.bashrc && \
    echo "" >> /root/.bashrc
```

- [ ] **Step 6：確認所有應移除的字串都已消失**

```bash
cd /Users/rb/Docker-Compose
grep -nE 'zsh|claude-code|@github/copilot|google-cloud|ohmyzsh|chsh' php-fpm8/Dockerfile
wc -l php-fpm8/Dockerfile
tail -20 php-fpm8/Dockerfile
```

預期：grep 輸出為空，檔案約 75–80 行（由 141 行縮減），結尾為 timezone + aliases + `WORKDIR /var/www` 區塊。

---

## Task 9：A6 — 移除 AI / 雲端設定的 host 卷掛載

**檔案：**
- 修改：`/Users/rb/Docker-Compose/docker-compose.yml`

- [ ] **Step 1：從 `php-fpm` 服務移除 `~/.claude` 與 `~/.copilot`**

用 `Edit`：

```
old_string:
        volumes:
            - ${WORKSPACE_PATH}:/var/www:cached
            - ./php-fpm/ini/php${PHP_VERSION}.ini:/usr/local/etc/php/php.ini
            - ${SSH_KEY_PATH}:/root/.ssh/id_rsa:ro
            - ${SSH_KEY_PATH}.pub:/root/.ssh/id_rsa.pub:ro
            - ~/.ssh/known_hosts:/root/.ssh/known_hosts
            - ~/.gitconfig:/root/.gitconfig:ro
            - ./php-fpm/php-fpm.d/www.conf:/usr/local/etc/php-fpm.d/www.conf
            - ./php-fpm/conf.d/xdebug.ini:/usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini
            - ./php-fpm/conf.d/error_reporting.ini:/usr/local/etc/php/conf.d/error_reporting.ini
            - ~/.claude:/root/.claude
            - ~/.copilot:/root/.copilot

new_string:
        volumes:
            - ${WORKSPACE_PATH}:/var/www:cached
            - ./php-fpm/ini/php${PHP_VERSION}.ini:/usr/local/etc/php/php.ini
            - ${SSH_KEY_PATH}:/root/.ssh/id_rsa:ro
            - ${SSH_KEY_PATH}.pub:/root/.ssh/id_rsa.pub:ro
            - ~/.ssh/known_hosts:/root/.ssh/known_hosts
            - ~/.gitconfig:/root/.gitconfig:ro
            - ./php-fpm/php-fpm.d/www.conf:/usr/local/etc/php-fpm.d/www.conf
            - ./php-fpm/conf.d/xdebug.ini:/usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini
            - ./php-fpm/conf.d/error_reporting.ini:/usr/local/etc/php/conf.d/error_reporting.ini
```

- [ ] **Step 2：從 `php-fpm8` 服務移除 `~/.claude`、`~/.copilot`、`~/.config/gcloud`**

```
old_string:
        volumes:
            - ${WORKSPACE_PATH}:/var/www:cached
            - ./php-fpm8/ini/php${PHP8_VERSION}.ini:/usr/local/etc/php/php.ini
            - ${SSH_KEY_PATH}:/root/.ssh/id_rsa:ro
            - ${SSH_KEY_PATH}.pub:/root/.ssh/id_rsa.pub:ro
            - ~/.ssh/known_hosts:/root/.ssh/known_hosts
            - ~/.gitconfig:/root/.gitconfig:ro
            - ./php-fpm8/php-fpm.d/www.conf:/usr/local/etc/php-fpm.d/www.conf
            - ./php-fpm8/conf.d/xdebug.ini:/usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini
            - ./php-fpm8/conf.d/error_reporting.ini:/usr/local/etc/php/conf.d/error_reporting.ini
            - ~/.claude:/root/.claude
            - ~/.copilot:/root/.copilot
            - ~/.config/gcloud:/root/.config/gcloud

new_string:
        volumes:
            - ${WORKSPACE_PATH}:/var/www:cached
            - ./php-fpm8/ini/php${PHP8_VERSION}.ini:/usr/local/etc/php/php.ini
            - ${SSH_KEY_PATH}:/root/.ssh/id_rsa:ro
            - ${SSH_KEY_PATH}.pub:/root/.ssh/id_rsa.pub:ro
            - ~/.ssh/known_hosts:/root/.ssh/known_hosts
            - ~/.gitconfig:/root/.gitconfig:ro
            - ./php-fpm8/php-fpm.d/www.conf:/usr/local/etc/php-fpm.d/www.conf
            - ./php-fpm8/conf.d/xdebug.ini:/usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini
            - ./php-fpm8/conf.d/error_reporting.ini:/usr/local/etc/php/conf.d/error_reporting.ini
```

- [ ] **Step 3：確認沒有 `.claude` / `.copilot` / `gcloud` 殘留**

```bash
cd /Users/rb/Docker-Compose
grep -nE '\.claude|\.copilot|gcloud' docker-compose.yml
```

預期：輸出為空。

---

## Task 10：A6 — 同步文件（`CLAUDE.md`、`AGENTS.md`）

**檔案：**
- 修改：`/Users/rb/Docker-Compose/CLAUDE.md`（1 行）
- 修改：`/Users/rb/Docker-Compose/AGENTS.md`（1 行）

- [ ] **Step 1：更新 `CLAUDE.md` 安全注意事項段落**

用 `Edit` 於 `/Users/rb/Docker-Compose/CLAUDE.md`：

```
old_string:
- 容器內的 `~/.ssh/`、`~/.gitconfig`、`~/.claude` 為 host 端掛載，操作會影響 host

new_string:
- 容器內的 `~/.ssh/`、`~/.gitconfig` 為 host 端掛載，操作會影響 host
```

- [ ] **Step 2：更新 `AGENTS.md` 安全注意事項段落**

用 `Edit` 於 `/Users/rb/Docker-Compose/AGENTS.md`：

```
old_string:
- 容器內的 `~/.ssh/`、`~/.gitconfig`、`~/.claude` 為 host 端掛載，操作會影響 host

new_string:
- 容器內的 `~/.ssh/`、`~/.gitconfig` 為 host 端掛載，操作會影響 host
```

- [ ] **Step 3：確認兩個檔案中只提及 `~/.ssh/` 與 `~/.gitconfig`**

```bash
cd /Users/rb/Docker-Compose
grep -n -E '容器內的.*為 host 端掛載' CLAUDE.md AGENTS.md
```

預期：兩行都只有 `~/.ssh/` 與 `~/.gitconfig`，不再有 `~/.claude`。

---

## Task 11：A6 — 重建 image 並執行完整驗證矩陣

**檔案：** 不修改任何檔案；此 task 是 spec §3 的驗證關卡。

- [ ] **Step 1：重建兩個 PHP image**

```bash
cd /Users/rb/Docker-Compose
docker compose build php-fpm php-fpm8
echo "build_exit=$?"
```

預期：`build_exit=0`。Build 應該明顯比之前快（少了 Oh My Zsh clone、gcloud apt install、npm global install）。

- [ ] **Step 2：強制 recreate 容器讓新 image 與新的卷設定生效**

```bash
docker compose up -d --force-recreate php-fpm php-fpm8
docker compose ps php-fpm php-fpm8
```

預期：兩個容器都 `running`。

- [ ] **Step 3：執行工具移除矩陣（4 工具 × 2 容器，每項獨立報告）**

```bash
for svc in php-fpm php-fpm8; do
  for bin in zsh claude copilot gcloud; do
    docker compose exec -T "$svc" sh -c "command -v $bin >/dev/null && echo FAIL:$svc:$bin || echo ok:$svc:$bin"
  done
  docker compose exec -T "$svc" sh -c 'echo "shell=$0"; cdfront >/dev/null 2>&1 && echo "alias_ok=$(pwd)"'
done
```

預期：剛好 8 行 `ok:<svc>:<bin>`，加上每個服務各一行 `shell=`（不應為 `zsh`）以及 `alias_ok=/var/www/API_Frontend/_release`。任一 `FAIL:` 都代表該容器尚有殘留工具 —— 先查清楚再決定是否 commit。

註：`cdfront` 指向 `/var/www/API_Frontend/_release`。如果你的 workspace 沒有這個目錄，`alias_ok=` 行就不會出現 —— 這**不算** A6 失敗，只代表 workspace 結構與 CLAUDE.md 不同。

- [ ] **Step 4：recreate 之後再驗證一次 SSH 私鑰唯讀**

```bash
for svc in php-fpm php-fpm8; do
  docker inspect "$svc" --format '{{range .Mounts}}{{if eq .Destination "/root/.ssh/id_rsa"}}{{.Destination}} RW={{.RW}}{{println}}{{end}}{{end}}'
done
```

預期：兩行，都是 `RW=false`。

- [ ] **Step 5：煙霧測試 nginx → PHP-FPM 仍可通**

```bash
docker compose up -d web
curl -sS -o /dev/null -w "%{http_code}\n" -H "Host: front-api.local" http://127.0.0.1/ || echo "curl-failed"
```

預期：200 / 302 / 404（任何來自 PHP 的回應）；不應為 502。

- [ ] **Step 6：再次以 example env 渲染 compose，確認 A1 仍正確**

```bash
cp .env.example /tmp/.env.test
docker compose --env-file /tmp/.env.test config > /dev/null
echo "exit=$?"
```

預期：`exit=0`。

如果 Task 11 任一步驟失敗，**不要** commit。回頭修 Tasks 7–10，或回退已動的編輯重新規劃。

---

## Task 12：A6 — Commit（3 個 commit 中的第 3 個）

**檔案：** 不再修改檔案，commit Tasks 7–10 的成果。

- [ ] **Step 1：檢視 staged 變更**

```bash
cd /Users/rb/Docker-Compose
git status
git diff --stat
```

預期修改檔案：
- `php-fpm/Dockerfile`
- `php-fpm8/Dockerfile`
- `docker-compose.yml`
- `CLAUDE.md`
- `AGENTS.md`

- [ ] **Step 2：Stage 並 commit**

```bash
git add php-fpm/Dockerfile php-fpm8/Dockerfile docker-compose.yml CLAUDE.md AGENTS.md
git commit -m "refactor: 移除 PHP 容器內 Oh My Zsh、gcloud、Claude/Copilot CLI 等非必要工具

容器內日常開發不會用到 zsh / gcloud / claude / copilot CLI，每次
build 都要 clone repo、跑 npm install -g、安裝 gcloud apt 套件，
維護成本與 image 體積都不划算。

- php-fpm / php-fpm8 Dockerfile：移除 zsh apt 套件、Oh My Zsh 與
  三個 plugin 的 git clone、.zshrc plugin 啟用、chsh、Claude /
  Copilot npm global install、Google Cloud CLI apt 安裝；容器內
  shell 回到官方 php-fpm 預設的 bash，aliases.sh 透過 .bashrc 載入
- docker-compose.yml：移除 ~/.claude、~/.copilot、~/.config/gcloud
  共 5 條 volume 掛載
- CLAUDE.md / AGENTS.md：同步更新「容器內 host 掛載」清單，移除
  ~/.claude

反向了 d84a32a（升級 Zsh）與 2b30853（雙 shell）的部分變更。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

- [ ] **Step 3：確認 commit**

```bash
git log --oneline -3
git show --stat HEAD
```

預期：HEAD 有 5 個檔案異動，commit message 以 `refactor:` 開頭。

---

## Task 13：3 個 commit 完成後的整合確認

**檔案：** 不修改檔案。

- [ ] **Step 1：列出新增的三個 commit**

```bash
cd /Users/rb/Docker-Compose
git log --oneline -4
```

預期（由上到下）：
1. `refactor: 移除 PHP 容器內 Oh My Zsh、gcloud、Claude/Copilot CLI 等非必要工具`（HEAD）
2. `chore: 統一 restart 策略、限制私鑰權限、補 .dockerignore 並收斂 FPM 對外 port`
3. `chore: 對齊 .env.example 與 CLAUDE.md / .env 三方設定`
4. 上一個 A 階段 spec 的 `docs:` commit。

- [ ] **Step 2：最終 compose config render**

```bash
docker compose config > /dev/null
echo "exit=$?"
```

預期：`exit=0`。

- [ ] **Step 3：最終運行狀態**

```bash
docker compose ps
```

預期：`web`、`php-fpm`、`php-fpm8`、`mysql`、`mysql8`、`redis` 全部 running，restart 策略為 `unless-stopped`。`api`、`open-webui` 是否 running 視使用者習慣而定，本計畫不額外操作。

- [ ] **Step 4：再執行一次 A6 確認矩陣**

```bash
for svc in php-fpm php-fpm8; do
  for bin in zsh claude copilot gcloud; do
    docker compose exec -T "$svc" sh -c "command -v $bin >/dev/null && echo FAIL:$svc:$bin || echo ok:$svc:$bin"
  done
done
```

預期：8 行 `ok:`。計畫完成。

---

## 回退備忘（若出狀況）

| 症狀 | 可能原因 | 回退方式 |
|------|----------|----------|
| Task 2/4/5 編輯後 `docker compose config` 報錯 | `docker-compose.yml` 縮排錯誤或多餘文字 | `git checkout docker-compose.yml`，逐項重做 |
| A5 之後 nginx 出現 502 | 某條 PHP 路徑原本依賴 host 9000 直連 | `git revert <第 2 個 commit 的 sha>`（或手動加回 `ports:` 區塊） |
| Task 11 Step 1 build 失敗 | 某次 Dockerfile 編輯留下殘餘 `\` 或語法錯 | `git checkout php-fpm/Dockerfile php-fpm8/Dockerfile`，重做 Task 7/8 |
| rebuild 後容器內 shell 仍是 zsh | image cache | `docker compose build --no-cache php-fpm php-fpm8` 後 recreate |
| 矩陣出現 `FAIL:<svc>:<bin>` | 某容器的 Dockerfile 編輯漏了一步 | 對應服務重做 Task 7 或 Task 8，再 rebuild |

若多處同時出問題，優先用 `git revert` 直接退掉該 commit，不要逐項零碎修補 —— 三個 commit 拆分就是為了任一可獨立回退。
