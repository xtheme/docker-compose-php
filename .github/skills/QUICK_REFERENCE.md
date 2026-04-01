# 快速參考手冊

> 用途：高頻指令速查
>
> 適用對象：開發者、AI 助手
>
> 不包含內容：MySQL 原理、Tinker 深度教學、完整診斷流程
>
> 延伸閱讀：
> - [MYSQL_USAGE.md](MYSQL_USAGE.md)
> - [LARAVEL_TINKER.md](LARAVEL_TINKER.md)
> - [AI_SKILLS.md](AI_SKILLS.md)

---

## Q1. 服務與容器

```bash
docker-compose up -d web php-fpm php-fpm8 mysql mysql8 redis
docker-compose ps
docker-compose logs -f web
docker-compose restart php-fpm8
docker-compose up -d --build php-fpm8
docker-compose down
```

## Q2. 進入容器

```bash
docker-compose exec php-fpm bash
docker-compose exec php-fpm8 bash
docker-compose exec mysql bash
docker-compose exec mysql8 bash
docker-compose exec web sh
```

## Q3. MySQL 速查

```bash
docker-compose exec php-fpm8 bash
mysql57
mysql80
```

```bash
mysql -h 127.0.0.1 -P 3305 -u root -p
mysql -h 127.0.0.1 -P 3306 -u root -p
```

## Q4. Laravel Tinker 速查

```bash
docker-compose exec php-fpm8 bash
cdfront
tinker
```

## Q5. 常用別名

```bash
pa
artisan
tinker
mysql57
mysql80
cdfront
cdagent
cdinternal
cdexternal
cdcronjob
cdsocket
```

## Q6. 三步排查

### Nginx 502

```bash
docker-compose ps php-fpm8
docker-compose exec web sh -c "nc -zv php-fpm8 9000"
docker-compose restart php-fpm8 web
```

### MySQL 連線失敗

```bash
docker-compose ps mysql8
docker-compose exec php-fpm8 ping -c 1 mysql8
docker-compose exec php-fpm8 bash -lc "mysql80"
```

### 找不到 artisan

```bash
docker-compose exec php-fpm8 bash
pwd
cdfront
ls -la artisan
```

## Q7. 服務與埠號

| 服務 | 容器名稱 | 主機埠 | 容器內連線 |
|---|---|---|---|
| MySQL 5.7 | `mysql` | `3305` | `mysql:3305` |
| MySQL 8.0 | `mysql8` | `3306` | `mysql8:3306` |
| Redis | `redis` | `6379` | `redis:6379` |
| PHP-FPM 7.x | `php-fpm` | `9000` | `php-fpm:9000` |
| PHP-FPM 8.x | `php-fpm8` | `9001` | `php-fpm8:9000` |

## 注意事項

- 容器間通訊一律使用服務名稱，不用 `localhost`
- `.env` 不納入 git
- SQL Mode 已移除 `ONLY_FULL_GROUP_BY`（詳見 [MYSQL_USAGE.md](MYSQL_USAGE.md)）

---

**最後更新**：2026-03-25


