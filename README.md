# Docker-Compose 開發環境

供本機開發使用的多版本 PHP / MySQL / Redis 容器編排，主要服務對象為 Laravel 框架的應用。

## 服務一覽

| 服務 | 內容 | 對外埠 |
|------|------|--------|
| `web` | Nginx alpine | 80 / 443 |
| `php-fpm` | PHP-FPM 7.3 | — |
| `php-fpm8` | PHP-FPM 8.4 | — |
| `mysql` | MySQL 5.7 | 3305 |
| `mysql8` | MySQL 8.0 | 3306 |
| `redis` | Redis | 6379 |

## 快速啟動

```bash
# 1. 複製環境變數範本，依個人需求調整 .env
cp .env.example .env

# 2. 啟動核心服務
docker compose up -d web php-fpm php-fpm8 mysql mysql8 redis

# 3. 進容器執行命令（範例）
docker compose exec php-fpm8 bash
```
