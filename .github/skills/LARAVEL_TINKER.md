# Laravel Tinker 使用指南

> 用途：在 Docker 容器內快速使用 Tinker 做資料驗證與除錯
>
> 適用對象：Laravel 開發者、AI 助手
>
> 不包含內容：MySQL 備份還原與 SQL Mode 深度說明
>
> 延伸閱讀：
> - [QUICK_REFERENCE.md](QUICK_REFERENCE.md)
> - [MYSQL_USAGE.md](MYSQL_USAGE.md)

---

## T1. 啟動流程

```bash
docker-compose exec php-fpm8 bash
cdfront
tinker
```

可用專案別名：`cdfront`、`cdagent`、`cdinternal`、`cdexternal`、`cdcronjob`、`cdsocket`。

---

## T2. 常用檢查片段

### 資料庫連線

```php
DB::connection()->getPdo();
DB::connection()->getDatabaseName();
DB::select("SELECT VERSION()");
DB::select("SELECT @@sql_mode");
```

### 查詢資料

```php
use App\Models\User;

User::count();
User::first();
User::where('status', 1)->limit(10)->get();
```

### 測試 Redis / Cache

```php
Redis::ping();
Cache::put('tinker:test', 'ok', 60);
Cache::get('tinker:test');
Cache::forget('tinker:test');
```

---

## T3. 模型 CRUD 範例

### Create

```php
use App\Models\User;

$user = User::create([
    'name' => 'Tinker User',
    'email' => 'tinker@example.com',
    'password' => bcrypt('secret'),
]);
```

### Read

```php
User::find($user->id);
User::where('email', 'tinker@example.com')->first();
```

### Update

```php
$user = User::find($user->id);
$user->name = 'Tinker User Updated';
$user->save();
```

### Delete

```php
$user = User::find($user->id);
$user->delete();
```

---

## T4. 安全測試（交易回滾）

```php
DB::beginTransaction();

$tmp = User::create([
    'name' => 'Rollback Demo',
    'email' => 'rollback@example.com',
    'password' => bcrypt('secret'),
]);

User::find($tmp->id);

DB::rollBack();
```

---

## T5. 除錯技巧

### 看 SQL 與參數

```php
User::where('status', 1)->toSql();
User::where('status', 1)->getBindings();
```

### 監聽查詢

```php
DB::listen(function ($query) {
    dump($query->sql, $query->bindings, $query->time);
});

User::where('status', 1)->get();
```

### 限制輸出

```php
User::select('id', 'name')->limit(5)->get();
```

---

## T6. 故障排除

### `tinker` 找不到

```bash
docker-compose exec php-fpm8 bash
pwd
cdfront
ls -la artisan
tinker
```

### `Class not found`

```bash
composer dump-autoload
tinker
```

### 記憶體不足

```bash
php -d memory_limit=512M artisan tinker
```

### 資料庫連線失敗

```php
try {
    DB::connection()->getPdo();
    echo 'ok';
} catch (\Throwable $e) {
    echo $e->getMessage();
}
```

MySQL 詳解請看 [MYSQL_USAGE.md](MYSQL_USAGE.md)。

---

## 相關文件

- [QUICK_REFERENCE.md](QUICK_REFERENCE.md)
- [MYSQL_USAGE.md](MYSQL_USAGE.md)
- [../../CLAUDE.md](../../CLAUDE.md)

---

**最後更新**：2026-03-25


