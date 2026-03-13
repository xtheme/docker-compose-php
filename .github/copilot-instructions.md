# Copilot Instructions — Docker-Compose 開發環境

## 專案背景

本專案是用於本地開發的 Docker 容器編排環境，支援多版本 PHP、MySQL、Redis 等服務，主要服務 Laravel 與 Hyperf 框架的應用開發。

## 語言偏好

- 所有回應與說明請使用**繁體中文**

## 技術棧

| 服務 | 技術 | 版本 |
|------|------|------|
| Web 伺服器 | Nginx | alpine |
| PHP (舊版) | PHP-FPM | 7.3 |
| PHP (新版) | PHP-FPM8 | 8.4 |
| 非同步框架 | PHP-Swoole (Hyperf) | 8.3 |
| 資料庫 (舊) | MySQL | 5.7 |
| 資料庫 (新) | MySQL8 | 8.0.30 |
| 快取 | Redis | latest |
| 訊息佇列 | RabbitMQ | 3.11（可選）|
| CI/CD | GitLab Runner | latest（可選）|

## 目錄結構慣例

- `nginx/sites/` — 各專案虛擬主機 `.conf` 設定
- `php-fpm/` — PHP 7.x 容器（Dockerfile、php.ini、Xdebug）
- `php-fpm8/` — PHP 8.x 容器
- `php-swoole/` — Hyperf 用 PHP-Swoole 容器
- `mysql/` / `mysql8/` — 資料庫設定（data/ 不納入 git）

## 開發慣例

### Nginx 虛擬主機
- PHP 7.x 專案使用 `fastcgi_pass php-upstream;`
- PHP 8.x 專案使用 `fastcgi_pass php-upstream8;`
- 新增虛擬主機後需在 `php-fpm` / `php-fpm8` 的 `extra_hosts` 中加入對應 `.local` host

### 環境變數
- 機密資訊一律存放於 `.env`，不提交至 git
- 新增環境變數時同步更新 `.env.example`

### Docker
- 修改 Dockerfile 後須重新建置：`docker-compose up -d --build <service>`
- 容器間通訊使用服務名稱（如 `mysql`、`redis`），不使用 `localhost`
- RabbitMQ 與 GitLab Runner 預設停用，使用時在 `docker-compose.yml` 取消註解

### Port 對應
- MySQL 5.7 對外埠：`3305`
- MySQL 8.0 對外埠：`3306`
- Redis：`6379`

### Xdebug
- 設定檔：`php-fpm/conf.d/xdebug.ini`
- IDE Listen Port：`9003`
- `xdebug.client_host = host.docker.internal`
