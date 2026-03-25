# Docker Compose PHP 开发环境

Laravel + PHP-FPM + MySQL + Nginx + Redis 完整开发环境

## 📚 文件導覽

### 核心文件
- **[CLAUDE.md](CLAUDE.md)** - 📖 專案完整說明文件

### 使用指南（技能知識庫）
- **[QUICK_REFERENCE.md](.github/skills/QUICK_REFERENCE.md)** - 🚀 快速參考手冊（推薦從這裡開始）
- **[MYSQL_USAGE.md](.github/skills/MYSQL_USAGE.md)** - 🗄️ MySQL 連接與操作完整指南
- **[LARAVEL_TINKER.md](.github/skills/LARAVEL_TINKER.md)** - 🎨 Laravel Tinker 使用指南
- **[AI_SKILLS.md](.github/skills/AI_SKILLS.md)** - 🤖 AI 助手技能範本

### AI 助手配置
- **[copilot-instructions.md](.github/copilot-instructions.md)** - GitHub Copilot 專用指令
- **[技能知識庫目錄](.github/skills/)** - AI 助手技能文件集

## 🚀 快速启动

```bash
# 启动所有核心服务
docker-compose up -d web mysql mysql8 redis php-fpm php-fpm8

# 查看運行狀態
docker-compose ps

# 查看日誌
docker-compose logs -f web
```

## 📦 服务列表

### Web 服务
- **Nginx** - 反向代理和 Web 服务器 (端口: 80, 443)

### PHP 服务
- **php-fpm** - PHP 7.x FPM 服务 (端口: 9000)
- **php-fpm8** - PHP 8.x FPM 服务 (端口: 9001)
- **api** - PHP Swoole 服务 (端口: 9501)

### 数据库服务
- **mysql** - MySQL 5.x (端口: 3305)
- **mysql8** - MySQL 8.0 (端口: 3306)

### 缓存服务
- **redis** - Redis 缓存 (端口: 6379)

## 🛠️ 新增功能

### ✅ MySQL 客户端工具

php-fpm 和 php-fpm8 容器现在包含 MySQL 客户端，可以直接在容器内执行 SQL 查询：

```bash
# 进入容器
docker exec -it php-fpm8 bash

# 连接 MySQL 8
mysql -h mysql8 -u root -p

# 连接 MySQL 5.x
mysql -h mysql -P 3305 -u root -p
```

### ✅ Laravel Tinker 快捷别名

使用 `tinker` 别名快速启动 Laravel Tinker：

```bash
# 进入容器
docker exec -it php-fpm8 bash

# 切换到项目（使用别名）
cdfront      # API_Frontend/_release
cdagent      # API_Agent/_release
cdexternal   # API_External/_release
cdinternal   # api-internal/_release

# 启动 Tinker（使用别名）
tinker

# 在 Tinker 中测试
>>> DB::select("SELECT VERSION()")
>>> User::count()
```

### ✅ 數據庫配置統一

所有數據庫的 SQL mode 配置已統一，移除了 `ONLY_FULL_GROUP_BY` 以保持向後兼容性。

詳細配置說明請參考：
- **[CLAUDE.md](CLAUDE.md)** - 專案完整說明
- **[MySQL 使用指南](.github/skills/MYSQL_USAGE.md)** - 數據庫操作完整指南

## 🔧 常用命令

### 容器管理

```bash
# 查看容器状态
docker-compose ps

# 查看容器日志
docker-compose logs -f php-fpm8

# 重启服务
docker-compose restart mysql8

# 停止所有服务
docker-compose down

# 重建服务
docker-compose build php-fpm8
docker-compose up -d php-fpm8
```

### 进入容器

```bash
# 进入 PHP-FPM8 容器
docker exec -it php-fpm8 bash

# 进入 PHP-FPM 容器
docker exec -it php-fpm bash

# 进入 MySQL 8 容器
docker exec -it mysql8 bash

# 进入 Nginx 容器
docker exec -it web bash
```

### Laravel 相关

```bash
# 执行 Artisan 命令
docker exec -it php-fpm8 bash -c "cd /var/www/项目目录 && php artisan migrate"

# 清除缓存
docker exec -it php-fpm8 bash -c "cd /var/www/项目目录 && php artisan cache:clear"

# 运行 Tinker
docker exec -it php-fpm8 bash -c "cd /var/www/项目目录 && php artisan tinker"
```

### 数据库操作

```bash
# 导出数据库
docker exec mysql8 mysqldump -u root -proot database_name > backup.sql

# 导入数据库
cat backup.sql | docker exec -i mysql8 mysql -u root -proot database_name

# 连接数据库
docker exec -it mysql8 mysql -u root -proot
```


## 📋 容器内可用别名

在 php-fpm 和 php-fpm8 容器中可用：

```bash
ll              # ls -l
pa              # php artisan
artisan         # php artisan
tinker          # php artisan tinker
sail            # Laravel Sail

# 项目快速切换
cdagent         # cd /var/www/API_Agent/_release
cdcronjob       # cd /var/www/RD-Studio-01/_release
cdexternal      # cd /var/www/API_External/_release
cdfront         # cd /var/www/API_Frontend/_release
cdinternal      # cd /var/www/api-internal/_release
cdsocket        # cd /var/www/WEB_CustomerServiceSocket/_release
```

## ⚙️ 配置说明

### 环境变量

在 `.env` 文件中配置：

```env
# PHP 版本
PHP_VERSION=7.4
PHP8_VERSION=8.4

# MySQL 配置
MYSQL_PORT=3305
MYSQL8_PORT=3306
MYSQL_DATABASE=laravel
MYSQL_USER=root
MYSQL_PASSWORD=secret
MYSQL_ROOT_PASSWORD=root

# Redis 配置
REDIS_PORT=6379

# 工作空间路径
WORKSPACE_PATH=./Workspace

# 时区
TIMEZONE=Asia/Shanghai

# Node.js 版本
NODEJS_VERSION=16
```

### MySQL SQL Mode

当前配置（已统一）：

```ini
STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION
```

**注意**: 已移除 `ONLY_FULL_GROUP_BY` 以保持向后兼容性。

## 🐛 故障排查

### 容器无法启动

```bash
# 查看日志
docker-compose logs mysql8

# 检查配置文件
docker-compose config --quiet
```

### 数据库连接失败

1. 检查容器是否运行: `docker-compose ps`
2. 检查 `.env` 配置是否正确
3. 验证数据库密码: `docker exec -it mysql8 mysql -u root -proot`

### GROUP BY 查询报错

如果仍然遇到 GROUP BY 错误：

1. 检查 MySQL 配置: `docker exec mysql8 bash -c "mysql -u root -proot -e 'SELECT @@GLOBAL.sql_mode'"`
2. 检查 Laravel 配置: 查看 `config/database.php` 中的 `'modes'` 配置
3. 重启容器: `docker-compose restart mysql8`
4. 清除 Laravel 配置缓存: `php artisan config:clear`

## 📞 支持與文檔

如有問題，請查看以下文檔：

- **專案說明** → [CLAUDE.md](CLAUDE.md)
- **快速參考** → [QUICK_REFERENCE.md](.github/skills/QUICK_REFERENCE.md)
- **MySQL 操作** → [MYSQL_USAGE.md](.github/skills/MYSQL_USAGE.md)
- **Laravel Tinker** → [LARAVEL_TINKER.md](.github/skills/LARAVEL_TINKER.md)
- **AI 助手技能** → [AI_SKILLS.md](.github/skills/AI_SKILLS.md)

---

**最後更新**: 2026-03-25
