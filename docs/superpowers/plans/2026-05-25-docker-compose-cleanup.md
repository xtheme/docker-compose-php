# Docker-Compose A 階段優化 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Apply A1–A6 changes from `docs/superpowers/specs/2026-05-25-docker-compose-cleanup-design.md`: align `.env.example`, unify restart policy, add `.dockerignore`, mount SSH private key read-only, drop unused FPM host ports, and strip Oh My Zsh / Google Cloud CLI / Claude / Copilot CLI from both PHP containers.

**Architecture:** Three sequential commits — (1) `.env.example` only, (2) `docker-compose.yml` setting / security cluster, (3) Dockerfile + compose volume + docs cleanup for A6. A6 is the only one that requires `docker compose build`; A1–A5 are pure config edits.

**Tech Stack:** Docker Compose v2, Dockerfile (PHP 7.3 / 8.4 official `php:*-fpm` images), bash inside container.

---

## File Structure

| File | Action | Purpose |
|------|--------|---------|
| `.env.example` | Modify | Align port / Node version with `.env` and CLAUDE.md; drop ClickHouse leftover (A1) |
| `docker-compose.yml` | Modify | Restart policy unification (A2), SSH `:ro` (A4), drop FPM host ports (A5), drop AI-tool volumes (A6) |
| `.dockerignore` | Create | Trim build context, never leak `mysql/data/`, `.git/`, `.idea/`, `.claude/`, etc. (A3) |
| `php-fpm/Dockerfile` | Modify | Remove `zsh` apt entry, Claude/Copilot CLI npm install, Google Cloud CLI install, Oh My Zsh + plugins + chsh, `.zshrc` writes (A6) |
| `php-fpm8/Dockerfile` | Modify | Same as php-fpm (A6, two-container sync) |
| `CLAUDE.md` | Modify | Remove `~/.claude` from container-mount list (A6 doc sync) |
| `AGENTS.md` | Modify | Same as CLAUDE.md (line 187) |

**No tests will be added** — this is infrastructure cleanup with no application code. Verification is via `docker compose config` parse, `docker compose build`, and the validation matrix from the spec.

---

## Task 1: A1 — Rewrite `.env.example`

**Files:**
- Modify: `/Users/rb/Docker-Compose/.env.example`

- [ ] **Step 1: Snapshot current state**

```bash
cat /Users/rb/Docker-Compose/.env.example
```

Expected current content includes `MYSQL_PORT=3306`, `MYSQL8_PORT=3308`, `NODEJS_VERSION=23`, and two `#CLICKHOUSE_*` lines.

- [ ] **Step 2: Replace `.env.example` with aligned values**

Use `Write` to overwrite `/Users/rb/Docker-Compose/.env.example` with the following exact content:

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

Changes vs. previous:

| Key | Before | After |
|-----|--------|-------|
| `NODEJS_VERSION` | `23` | `20` |
| `MYSQL_PORT` | `3306` | `3305` |
| `MYSQL8_PORT` | `3308` | `3306` |
| `#CLICKHOUSE_USER` / `#CLICKHOUSE_PASSWORD` | present (commented) | removed |

**Do NOT add `MYSQL8_DATABASE` / `MYSQL8_USER` / `MYSQL8_PASSWORD` / `MYSQL8_ROOT_PASSWORD`** — per spec §A1 the `mysql8` service still consumes `MYSQL_*`; adding `MYSQL8_*` would mislead developers.

- [ ] **Step 3: Verify the example renders standalone with compose**

```bash
cd /Users/rb/Docker-Compose
cp .env.example /tmp/.env.test
docker compose --env-file /tmp/.env.test config > /tmp/compose-rendered.yml
echo "exit=$?"
grep -E 'MYSQL_PORT|MYSQL8_PORT|NODEJS_VERSION' /tmp/.env.test
```

Expected:
- `exit=0`
- `MYSQL_PORT=3305`, `MYSQL8_PORT=3306`, `NODEJS_VERSION=20`
- `docker compose config` prints no warnings about undefined variables

- [ ] **Step 4: Commit (commit #1 of 3)**

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

Verify:

```bash
git log --oneline -1
git show --stat HEAD
```

---

## Task 2: A2 — Unify restart policy

**Files:**
- Modify: `/Users/rb/Docker-Compose/docker-compose.yml` (two lines)

- [ ] **Step 1: Change `web` service restart to `unless-stopped`**

Use `Edit` on `/Users/rb/Docker-Compose/docker-compose.yml`:

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

- [ ] **Step 2: Change `open-webui` service restart to `unless-stopped`**

Use `Edit`:

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

- [ ] **Step 3: Confirm no `restart: always` remains**

```bash
cd /Users/rb/Docker-Compose
grep -nE '^\s*restart:' docker-compose.yml
```

Expected: every line in the (uncommented) services is `restart: unless-stopped`. Commented-out blocks for `rabbitmq` / `gitlab-runner` / `elasticsearch` may still show `always` — that is acceptable.

---

## Task 3: A3 — Create `.dockerignore`

**Files:**
- Create: `/Users/rb/Docker-Compose/.dockerignore`

- [ ] **Step 1: Confirm the file does not already exist**

```bash
ls -la /Users/rb/Docker-Compose/.dockerignore 2>&1
```

Expected: `No such file or directory`.

- [ ] **Step 2: Create `.dockerignore` with the spec content**

Use `Write` on `/Users/rb/Docker-Compose/.dockerignore` with exactly this content:

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

- [ ] **Step 3: Sanity-check file**

```bash
wc -l /Users/rb/Docker-Compose/.dockerignore
head -5 /Users/rb/Docker-Compose/.dockerignore
```

Expected: 30 lines (give or take blank lines), first content line is `# Version control & IDE`.

---

## Task 4: A4 — Mount SSH private key read-only

**Files:**
- Modify: `/Users/rb/Docker-Compose/docker-compose.yml` (two lines)

- [ ] **Step 1: Edit `php-fpm` private key mount**

Use `Edit` on `/Users/rb/Docker-Compose/docker-compose.yml`. The four-line block including the `php${PHP_VERSION}.ini` line uniquely anchors the `php-fpm` service (not `php-fpm8` which uses `${PHP8_VERSION}`):

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

- [ ] **Step 2: Edit `php-fpm8` private key mount**

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

- [ ] **Step 3: Confirm both mounts are now `:ro`**

```bash
cd /Users/rb/Docker-Compose
grep -n 'id_rsa' docker-compose.yml
```

Expected: four `id_rsa` lines, two end in `:ro` for `id_rsa` (private key) and two end in `:ro` for `id_rsa.pub`.

---

## Task 5: A5 — Remove FPM host ports

**Files:**
- Modify: `/Users/rb/Docker-Compose/docker-compose.yml` (two `ports:` blocks)

- [ ] **Step 1: Remove `php-fpm` `ports:` block**

Use `Edit`:

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

- [ ] **Step 2: Remove `php-fpm8` `ports:` block**

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

- [ ] **Step 3: Confirm only intended ports remain**

```bash
cd /Users/rb/Docker-Compose
grep -nB1 -A1 -E '"[0-9]+:[0-9]+"' docker-compose.yml | head -40
```

Expected ports list:
- `web`: `"80:80"`, `"443:443"`
- `api` (Swoole): `"9501:9501"`
- `mysql`: `"${MYSQL_PORT}:3306"`
- `mysql8`: `"${MYSQL8_PORT}:3306"`
- `redis`: `"${REDIS_PORT}:6379"`
- `open-webui`: `"3000:8080"`

No `9000:9000` or `9001:9000` should remain.

---

## Task 6: Verify A2–A5 cluster then commit (commit #2 of 3)

**Files:** none modified in this task; just verify and commit.

- [ ] **Step 1: Render compose to catch syntax errors**

```bash
cd /Users/rb/Docker-Compose
docker compose config > /tmp/compose-after-a2-a5.yml
echo "exit=$?"
```

Expected: `exit=0`. If it prints `level=warning msg="services.x: ..."` lines, read them — they may be benign (e.g., env var defaults). Errors must be zero.

- [ ] **Step 2: Inspect rendered yaml shows the new state**

```bash
grep -E 'restart:|id_rsa|"9000:|"9001:' /tmp/compose-after-a2-a5.yml
```

Expected: every `restart:` value is `unless-stopped`, every `id_rsa` (not `.pub`) entry is read-only, no `9000:` or `9001:` lines.

- [ ] **Step 3: Restart core services with new settings**

```bash
cd /Users/rb/Docker-Compose
docker compose up -d web php-fpm php-fpm8 mysql mysql8 redis
docker compose ps
```

Expected: all six services `running` or `healthy`.

- [ ] **Step 4: Smoke test that nginx can still reach PHP-FPM via service network**

```bash
docker compose exec -T web sh -c 'wget -qO- --timeout=3 http://php-fpm:9000 2>&1 | head -1 ; echo "status=$?"'
docker compose exec -T web sh -c 'wget -qO- --timeout=3 http://php-fpm8:9000 2>&1 | head -1 ; echo "status=$?"'
```

PHP-FPM does not speak HTTP, so wget will fail at the protocol layer — but the TCP connection itself succeeding is the proof that container-to-container 9000 still works. Look for `status=` to be `0`, `1`, or `8` (HTTP-protocol-level fail), **not** `4` / `5` (network unreachable). If `status=4`, the FPM port is genuinely unreachable and A5 broke something.

A more reliable check is via nginx itself:

```bash
curl -sS -o /dev/null -w "%{http_code}\n" -H "Host: front-api.local" http://127.0.0.1/ || echo "curl-failed"
```

Expected: a 200 / 302 / 404 from PHP (i.e., nginx routed through to FPM). A 502 means nginx cannot reach FPM and A5 broke the path — re-add the `ports:` block on the affected container and investigate.

- [ ] **Step 5: Verify SSH private key is read-only on both containers**

```bash
for svc in php-fpm php-fpm8; do
  docker inspect "$svc" --format '{{range .Mounts}}{{if eq .Destination "/root/.ssh/id_rsa"}}{{.Destination}} RW={{.RW}}{{println}}{{end}}{{end}}'
done
```

Expected output:

```
/root/.ssh/id_rsa RW=false
/root/.ssh/id_rsa RW=false
```

If `RW=true` for either, the `:ro` was not applied — re-check the edit and `docker compose up -d` to recreate the container.

- [ ] **Step 6: Commit (commit #2 of 3)**

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

Verify:

```bash
git show --stat HEAD
```

Should list 2 files changed: `.dockerignore` (new), `docker-compose.yml` (modified).

---

## Task 7: A6 — Strip non-essential tools from `php-fpm/Dockerfile`

**Files:**
- Modify: `/Users/rb/Docker-Compose/php-fpm/Dockerfile`

This task makes five surgical edits in one file. Apply them in the order below, top-to-bottom, so earlier edits do not invalidate later anchor strings.

- [ ] **Step 1: Drop `zsh` from the apt system-packages list**

Use `Edit`:

```
old_string:
    ffmpeg \
    zsh \
    default-mysql-client

new_string:
    ffmpeg \
    default-mysql-client
```

- [ ] **Step 2: Remove the Claude / Copilot CLI install**

```
old_string:
# Install Claude CLI & GitHub Copilot CLI
RUN npm install -g @anthropic-ai/claude-code @github/copilot

# Install Google Cloud CLI

new_string:
# Install Google Cloud CLI
```

Note: this leaves the next `# Install Google Cloud CLI` heading in place — Step 3 removes it.

- [ ] **Step 3: Remove the Google Cloud CLI install block**

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

- [ ] **Step 4: Remove Oh My Zsh, plugin clones, plugin enablement, and `chsh`**

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

**Anchor check:** the php-fpm Dockerfile uses `ZSH_AUTOSUGGEST_STRATEGY=(history completion)`. The php-fpm8 Dockerfile may use a slightly different string — see Task 8 note 1.

- [ ] **Step 5: Drop the `.zshrc` half of the aliases install (`.bashrc` stays)**

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

- [ ] **Step 6: Verify no removed strings remain**

```bash
cd /Users/rb/Docker-Compose
grep -nE 'zsh|claude-code|@github/copilot|google-cloud|ohmyzsh|chsh' php-fpm/Dockerfile
```

Expected: empty output.

```bash
wc -l php-fpm/Dockerfile
tail -20 php-fpm/Dockerfile
```

Expected: file should be ~75–80 lines (down from 141) and end with the timezone + aliases + `WORKDIR /var/www` block.

---

## Task 8: A6 — Strip non-essential tools from `php-fpm8/Dockerfile`

**Files:**
- Modify: `/Users/rb/Docker-Compose/php-fpm8/Dockerfile`

The five edits below are the same shape as Task 7 but each is repeated inline so this task can be executed independently. Apply in order top-to-bottom.

- [ ] **Step 0: Capture the exact `ZSH_AUTOSUGGEST_STRATEGY` value used in this file**

The two Dockerfiles may differ on this one line (`(history completion)` vs `(git completion)`). Run:

```bash
grep -n 'ZSH_AUTOSUGGEST_STRATEGY' /Users/rb/Docker-Compose/php-fpm8/Dockerfile
```

If the value differs from what Step 4 below shows, update the anchor in Step 4 to match before running the `Edit`.

- [ ] **Step 1: Drop `zsh` from the apt system-packages list**

Use `Edit` on `/Users/rb/Docker-Compose/php-fpm8/Dockerfile`:

```
old_string:
    ffmpeg \
    zsh \
    default-mysql-client

new_string:
    ffmpeg \
    default-mysql-client
```

- [ ] **Step 2: Remove the Claude / Copilot CLI install**

```
old_string:
# Install Claude CLI & GitHub Copilot CLI
RUN npm install -g @anthropic-ai/claude-code @github/copilot

# Install Google Cloud CLI

new_string:
# Install Google Cloud CLI
```

- [ ] **Step 3: Remove the Google Cloud CLI install block**

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

- [ ] **Step 4: Remove Oh My Zsh, plugin clones, plugin enablement, and `chsh`**

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

**If Step 0 showed a different value for `ZSH_AUTOSUGGEST_STRATEGY` (e.g., `(git completion)`)**, change the corresponding line in `old_string` above before running the `Edit`, otherwise the match will fail. The plugin clone comment may also be `# Install zsh plugins: autosuggestions + syntax highlighting + completions` instead of the `(Fish-like history suggestions)` variant — adjust to match the file.

- [ ] **Step 5: Drop the `.zshrc` half of the aliases install (`.bashrc` stays)**

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

- [ ] **Step 6: Verify no removed strings remain**

```bash
cd /Users/rb/Docker-Compose
grep -nE 'zsh|claude-code|@github/copilot|google-cloud|ohmyzsh|chsh' php-fpm8/Dockerfile
wc -l php-fpm8/Dockerfile
tail -20 php-fpm8/Dockerfile
```

Expected: empty grep output, file should be ~75–80 lines (down from 141) and end with the timezone + aliases + `WORKDIR /var/www` block.

---

## Task 9: A6 — Remove host-mounted AI / cloud config volumes

**Files:**
- Modify: `/Users/rb/Docker-Compose/docker-compose.yml`

- [ ] **Step 1: Strip `~/.claude` and `~/.copilot` from the `php-fpm` service**

Use `Edit`:

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

- [ ] **Step 2: Strip `~/.claude`, `~/.copilot`, `~/.config/gcloud` from the `php-fpm8` service**

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

- [ ] **Step 3: Confirm no `.claude` / `.copilot` / `gcloud` mounts remain**

```bash
cd /Users/rb/Docker-Compose
grep -nE '\.claude|\.copilot|gcloud' docker-compose.yml
```

Expected: empty output.

---

## Task 10: A6 — Sync docs (`CLAUDE.md`, `AGENTS.md`)

**Files:**
- Modify: `/Users/rb/Docker-Compose/CLAUDE.md` (one line)
- Modify: `/Users/rb/Docker-Compose/AGENTS.md` (one line)

- [ ] **Step 1: Update `CLAUDE.md` security note**

Use `Edit` on `/Users/rb/Docker-Compose/CLAUDE.md`:

```
old_string:
- 容器內的 `~/.ssh/`、`~/.gitconfig`、`~/.claude` 為 host 端掛載，操作會影響 host

new_string:
- 容器內的 `~/.ssh/`、`~/.gitconfig` 為 host 端掛載，操作會影響 host
```

- [ ] **Step 2: Update `AGENTS.md` security note**

Use `Edit` on `/Users/rb/Docker-Compose/AGENTS.md`:

```
old_string:
- 容器內的 `~/.ssh/`、`~/.gitconfig`、`~/.claude` 為 host 端掛載，操作會影響 host

new_string:
- 容器內的 `~/.ssh/`、`~/.gitconfig` 為 host 端掛載，操作會影響 host
```

- [ ] **Step 3: Confirm both files mention only `~/.ssh/` and `~/.gitconfig`**

```bash
cd /Users/rb/Docker-Compose
grep -n -E '容器內的.*為 host 端掛載' CLAUDE.md AGENTS.md
```

Expected: both lines show only `~/.ssh/` and `~/.gitconfig`, no `~/.claude`.

---

## Task 11: A6 — Rebuild images and run the full validation matrix

**Files:** none modified; this is the spec §3 verification gate.

- [ ] **Step 1: Rebuild both PHP images**

```bash
cd /Users/rb/Docker-Compose
docker compose build php-fpm php-fpm8
echo "build_exit=$?"
```

Expected: `build_exit=0`. Build should be noticeably faster than before (no Oh My Zsh clones, no gcloud apt install, no npm global install).

- [ ] **Step 2: Recreate containers so the new image and updated volumes take effect**

```bash
docker compose up -d --force-recreate php-fpm php-fpm8
docker compose ps php-fpm php-fpm8
```

Expected: both `running`.

- [ ] **Step 3: Run the removal-matrix check (4 binaries × 2 containers, independent reporting)**

```bash
for svc in php-fpm php-fpm8; do
  for bin in zsh claude copilot gcloud; do
    docker compose exec -T "$svc" sh -c "command -v $bin >/dev/null && echo FAIL:$svc:$bin || echo ok:$svc:$bin"
  done
  docker compose exec -T "$svc" sh -c 'echo "shell=$0"; cdfront >/dev/null 2>&1 && echo "alias_ok=$(pwd)"'
done
```

Expected exactly 8 `ok:<svc>:<bin>` lines plus per-service `shell=` (non-zsh) and `alias_ok=/var/www/API_Frontend/_release`. Any `FAIL:` line indicates that container still has the binary — investigate, do not commit.

Note: `cdfront` resolves to `/var/www/API_Frontend/_release`. If this directory does not exist in your workspace, the `alias_ok=` line will be missing — that is **not** a failure of A6; it just means the workspace layout differs from CLAUDE.md.

- [ ] **Step 4: Verify SSH private key is read-only on both containers (re-check after recreate)**

```bash
for svc in php-fpm php-fpm8; do
  docker inspect "$svc" --format '{{range .Mounts}}{{if eq .Destination "/root/.ssh/id_rsa"}}{{.Destination}} RW={{.RW}}{{println}}{{end}}{{end}}'
done
```

Expected: two lines, both `RW=false`.

- [ ] **Step 5: Smoke-test nginx → PHP-FPM path still works**

```bash
docker compose up -d web
curl -sS -o /dev/null -w "%{http_code}\n" -H "Host: front-api.local" http://127.0.0.1/ || echo "curl-failed"
```

Expected: 200 / 302 / 404 (anything from PHP); not 502.

- [ ] **Step 6: Render compose with example env to confirm A1 still valid**

```bash
cp .env.example /tmp/.env.test
docker compose --env-file /tmp/.env.test config > /dev/null
echo "exit=$?"
```

Expected: `exit=0`.

If any step in Task 11 fails, do **not** commit. Either fix the underlying issue in Tasks 7–10 and re-run, or revert in-progress edits and re-plan.

---

## Task 12: A6 — Commit (commit #3 of 3)

**Files:** none modified; commit work from Tasks 7–10.

- [ ] **Step 1: Review staged changes**

```bash
cd /Users/rb/Docker-Compose
git status
git diff --stat
```

Expected modified files:
- `php-fpm/Dockerfile`
- `php-fpm8/Dockerfile`
- `docker-compose.yml`
- `CLAUDE.md`
- `AGENTS.md`

- [ ] **Step 2: Stage and commit**

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

- [ ] **Step 3: Confirm commit**

```bash
git log --oneline -3
git show --stat HEAD
```

Expected: 5 files changed in HEAD, message starts with `refactor:`.

---

## Task 13: Final integration check across all 3 commits

**Files:** none modified.

- [ ] **Step 1: List the three new commits**

```bash
cd /Users/rb/Docker-Compose
git log --oneline -4
```

Expected (top → bottom):
1. `refactor: 移除 PHP 容器內 Oh My Zsh、gcloud、Claude/Copilot CLI 等非必要工具` (HEAD)
2. `chore: 統一 restart 策略、限制私鑰權限、補 .dockerignore 並收斂 FPM 對外 port`
3. `chore: 對齊 .env.example 與 CLAUDE.md / .env 三方設定`
4. The previous `docs:` commit for the A階段 spec update.

- [ ] **Step 2: Full final compose config render**

```bash
docker compose config > /dev/null
echo "exit=$?"
```

Expected: `exit=0`.

- [ ] **Step 3: Final running state**

```bash
docker compose ps
```

Expected: `web`, `php-fpm`, `php-fpm8`, `mysql`, `mysql8`, `redis` all running with `unless-stopped` restart policy. `api`, `open-webui` may or may not be running depending on user preference (not exercised by this plan).

- [ ] **Step 4: Confirm one more time that A6 removed everything**

```bash
for svc in php-fpm php-fpm8; do
  for bin in zsh claude copilot gcloud; do
    docker compose exec -T "$svc" sh -c "command -v $bin >/dev/null && echo FAIL:$svc:$bin || echo ok:$svc:$bin"
  done
done
```

Expected: 8 `ok:` lines. Plan complete.

---

## Rollback notes (if anything goes wrong)

| Symptom | Likely cause | Rollback |
|---------|--------------|----------|
| `docker compose config` errors after Task 2/4/5 edits | Wrong indentation or stray text in `docker-compose.yml` | `git checkout docker-compose.yml`, re-apply edits one at a time |
| 502 from nginx after A5 | Some PHP path was hitting host port 9000 directly | `git revert <commit-#2-sha>` (or re-add `ports:` block manually) |
| Build failure in Task 11 Step 1 | One of the Dockerfile edits left dangling `\` or broken syntax | `git checkout php-fpm/Dockerfile php-fpm8/Dockerfile`, re-apply Task 7/8 |
| Container shell still zsh after rebuild | Image cache | `docker compose build --no-cache php-fpm php-fpm8` then recreate |
| `FAIL:<svc>:<bin>` in matrix | Edit missed in that container's Dockerfile | Re-apply Task 7 or 8 to the affected service, then rebuild |

If multiple things break, prefer `git revert` on the affected commit over piecemeal fixes — the three commits were intentionally separated so each is independently revertible.
