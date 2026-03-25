# MySQL 完整使用指南

> 用途：MySQL 連線、查詢、備份、SQL Mode 與 Laravel 整合
>
> 適用對象：開發者、AI 助手
>
> 不包含內容：Laravel Tinker 深度教學
>
> 延伸閱讀：
> - [QUICK_REFERENCE.md](QUICK_REFERENCE.md)
> - [LARAVEL_TINKER.md](LARAVEL_TINKER.md)

---

## M1. 連線方式

### 容器內（推薦）

```bash
docker-compose exec php-fpm8 bash
mysql57
mysql80
```

### 主機端

```bash
mysql -h 127.0.0.1 -P 3305 -u root -p
mysql -h 127.0.0.1 -P 3306 -u root -p
```

### 服務參數

| 類型 | MySQL 5.7 | MySQL 8.0 |
|---|---|---|
| 容器服務名 | `mysql` | `mysql8` |
| 對外埠 | `3305` | `3306` |
| 容器內連線 | `mysql:3305` | `mysql8:3306` |

---

## M2. 常用 SQL

```sql
SHOW DATABASES;
USE database_name;
SHOW TABLES;
DESCRIBE table_name;
SHOW CREATE TABLE table_name;
SELECT VERSION();
SELECT @@GLOBAL.sql_mode;
SELECT USER();
```

```sql
CREATE DATABASE IF NOT EXISTS database_name CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
GRANT ALL PRIVILEGES ON database_name.* TO 'username'@'%';
FLUSH PRIVILEGES;
```

---

## M3. 備份與還原

> 建議先在主機設定：`export MYSQL_ROOT_PASSWORD='你的密碼'`

### 備份

```bash
docker-compose exec mysql8 mysqldump -u root -p"$MYSQL_ROOT_PASSWORD" database_name > backup.sql
docker-compose exec mysql8 mysqldump -u root -p"$MYSQL_ROOT_PASSWORD" --all-databases > all_databases.sql
docker-compose exec mysql8 mysqldump -u root -p"$MYSQL_ROOT_PASSWORD" --no-data database_name > structure.sql
docker-compose exec mysql8 mysqldump -u root -p"$MYSQL_ROOT_PASSWORD" database_name | gzip > backup.sql.gz
```

### 還原

```bash
docker-compose exec -T mysql8 mysql -u root -p"$MYSQL_ROOT_PASSWORD" database_name < backup.sql
gunzip < backup.sql.gz | docker-compose exec -T mysql8 mysql -u root -p"$MYSQL_ROOT_PASSWORD" database_name
```

### 匯入檔案

```bash
cat file.sql | docker-compose exec -T mysql8 mysql -u root -p"$MYSQL_ROOT_PASSWORD" database_name
docker cp file.sql mysql8:/tmp/file.sql
docker-compose exec mysql8 bash -lc "mysql -u root -p\"$MYSQL_ROOT_PASSWORD\" database_name < /tmp/file.sql"
```

---

## M4. Laravel 資料庫設定

### `.env`（容器內）

```env
DB_CONNECTION=mysql
DB_HOST=mysql8
DB_PORT=3306
DB_DATABASE=your_database
DB_USERNAME=root
DB_PASSWORD=secret

DB_HOST_READ=mysql8
DB_HOST_WRITE=mysql8
DB_USERNAME_READ=root
DB_PASSWORD_READ=secret
DB_USERNAME_WRITE=root
DB_PASSWORD_WRITE=secret
```

### `config/database.php` 重要片段

```php
'strict' => true,
'modes' => [
    'STRICT_TRANS_TABLES',
    'NO_ZERO_IN_DATE',
    'NO_ZERO_DATE',
    'ERROR_FOR_DIVISION_BY_ZERO',
    'NO_ENGINE_SUBSTITUTION',
],
```

---

## M5. SQL Mode 說明

### 目前基準

```ini
sql-mode="STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION"
```

| Mode | 說明 | 狀態 |
|---|---|---|
| `STRICT_TRANS_TABLES` | 事務寫入嚴格檢查 | 啟用 |
| `NO_ZERO_IN_DATE` | 禁止含 0 日期片段 | 啟用 |
| `NO_ZERO_DATE` | 禁止 `0000-00-00` | 啟用 |
| `ERROR_FOR_DIVISION_BY_ZERO` | 除零回錯 | 啟用 |
| `NO_ENGINE_SUBSTITUTION` | 禁止自動換引擎 | 啟用 |
| `ONLY_FULL_GROUP_BY` | 嚴格 GROUP BY 規則 | 已移除 |

### 查詢目前 SQL Mode

```sql
SELECT @@SESSION.sql_mode;
SELECT @@GLOBAL.sql_mode;
```

---

## M6. 故障排除

### Connection refused

```env
# 錯誤
DB_HOST=localhost

# 正確（容器內）
DB_HOST=mysql8
```

### Access denied

```bash
docker-compose exec mysql8 mysql -u root -p
docker-compose exec mysql8 mysql -u root -p -e "SELECT User, Host FROM mysql.user;"
```

### Unknown database

```bash
docker-compose exec mysql8 mysql -u root -p -e "CREATE DATABASE database_name CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
docker-compose exec mysql8 mysql -u root -p -e "SHOW DATABASES;"
```

### GROUP BY 錯誤仍出現

```bash
docker-compose exec mysql8 mysql -u root -p -e "SELECT @@GLOBAL.sql_mode;"
docker-compose exec php-fpm8 bash
cdfront
tinker
```

```php
config('database.connections.mysql.modes');
```

```bash
php artisan config:clear
docker-compose restart mysql8 php-fpm8
```


---

**最後更新**：2026-03-25


