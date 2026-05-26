# PHP 7.3 image 無法 rebuild：install-php-extensions 抓 PECL yaml metadata 失敗

**狀態：** resolved（2026-05-26，採方案 C）
**發現日期：** 2026-05-25
**影響範圍：** `docker compose build php-fpm`（PHP 7.3）
**不影響：** `docker compose build php-fpm8`（PHP 8.4 同 Dockerfile pattern build 成功）

## 解決方式

採方案 C：從 `php-fpm/Dockerfile` 的 `install-php-extensions` 清單移除 `yaml`。
盤點 `~/Workspace/{API_Agent,API_External,API_Frontend,api-internal,RD-Studio-01,
WEB_CustomerServiceSocket}/_release` 6 個 PHP 7.3 服務：

- 0 個 `composer.json` / `composer.lock` 宣告 `ext-yaml`
- vendor 內全部 PHP 檔（合計約 32,688 個）grep `yaml_(parse|emit|parse_file|emit_file|parse_url)` 命中 0

代表 PHP 7.3 容器內的 yaml extension 從未被使用，整個依賴可以直接拿掉。
拿掉後 `docker compose build php-fpm` 通過，PHP 7.3.33 容器正常啟動，
nginx → php-fpm 9000 經 front-api.local 取得 HTTP 200。

---

## 症狀

執行 `docker compose build php-fpm` 時，在 `Dockerfile` L27 的 `install-php-extensions` 步驟失敗：

```
#15 325.4 ### INSTALLING REMOTE MODULE yaml ###
#15 325.4 Package "yaml" does not have REST info xml available
#15 325.4 install failed
#15 ERROR: process "/bin/sh -c set -eux; ... install-php-extensions ... yaml ..."
        did not complete successfully: exit code: 1
```

後續所有步驟（含 A6 在 L84 之後的編輯區域）都跑不到。

---

## 重現步驟

```bash
cd /Users/rb/Docker-Compose
docker compose build php-fpm
```

預期：build 成功。
實際：在 yaml 步驟 exit code 1。

對照組（成功）：

```bash
docker compose build php-fpm8
```

`php-fpm8` 用同樣的 `install-php-extensions ... yaml ...` 寫法但走 PHP 8.4，build 通過、image 內可看到 `/usr/local/etc/php/conf.d/docker-php-ext-yaml.ini`。

---

## 已知資訊

- `install-php-extensions` 版本：image 中為 v2.10.8（Dockerfile 透過 `ADD https://.../latest/download/install-php-extensions` 取得，每次 build 都會抓 GitHub Release 的最新版）
- 上游類似議題：[mlocati/docker-php-extension-installer#1124](https://github.com/mlocati/docker-php-extension-installer/issues/1124) — open，2025-06 回報 swoole 出現 `XML Error: 'Not well-formed (invalid token)'` 與 `No releases available for package`，模式一致
- 推測根因：PECL 的 REST XML metadata 對 yaml on 老版 PHP 已退役或損毀；新版 PHP 走預編譯路徑不受影響
- 現存 `docker-compose-php-fpm:latest` image 建於 2026-04-01；當時 Dockerfile 還沒加入 zsh / gcloud（之後加入但沒人能重 build，因此 image 一直沒更新到那兩項）

---

## 影響

1. PHP 7.3 image 卡在 2026-04-01 的版本，無法套用任何後續 Dockerfile 改動
2. A6 容器內工具清理：Dockerfile 編輯已 commit（83ae2e7），但 PHP 7.3 容器內 `claude` / `copilot` 仍存在（image 沒重 build）
3. 任何新增 PHP extension、改 base image、調整 build-time 設定都被擋住

---

## 候選修法

### 方案 A：用 Debian apt `php-yaml` 取代 PECL 安裝（推薦）

PHP 7.3 base image (`php:7.3-fpm`) 是 Debian buster，apt 有 `php-yaml` 套件。把 `yaml` 從 `install-php-extensions` 清單拿掉，改為：

```dockerfile
RUN apt-get update && apt-get install -y libyaml-dev php-yaml
```

優點：繞過 PECL，apt 比較穩。
缺點：需要驗證 ABI 是否相容 `php:7.3-fpm` 自帶的 PHP（debian 套件版可能對應系統 PHP 而非 image 的 PHP，要先測）。

### 方案 B：在 install-php-extensions 之外手動編譯 yaml

```dockerfile
RUN apt-get update && apt-get install -y libyaml-dev \
    && pecl install yaml \
    && docker-php-ext-enable yaml
```

優點：用 PHP 官方 `docker-php-ext-enable` 標準流程。
缺點：仍經 PECL，若 PECL 端問題未解可能一樣失敗。實測必要。

### 方案 C：移除 PHP 7.3 的 yaml extension

若沒有 PHP 7.3 專案實際使用 yaml extension（搜 `~/Workspace/*/composer.json` 與業務碼確認），直接從 `php-fpm/Dockerfile` 的 `install-php-extensions` 清單刪掉 `yaml`。

優點：最簡單。
缺點：需先盤點哪些 7.3 服務真的用 yaml。

### 方案 D：等上游修

訂閱 [mlocati/docker-php-extension-installer#1124](https://github.com/mlocati/docker-php-extension-installer/issues/1124)，等上游處理好 PECL 抓取退化。

優點：零本地維護成本。
缺點：時間不可控，期間 PHP 7.3 image 無法 rebuild。

---

## 建議優先順序

1. **先做方案 C 盤點**：如果 7.3 服務都沒用 yaml，直接刪一行解決
2. 若有服務需要：試方案 B（local PECL build），看是不是 install-php-extensions 特有的 metadata 路徑問題
3. 兩個都不行：方案 A apt 套件

---

## 相關 commit

- `83ae2e7` refactor: 移除 PHP 容器內 Oh My Zsh、gcloud、Claude/Copilot CLI 等非必要工具（其中 php-fpm/Dockerfile 編輯依本 issue 卡關，待解後 rebuild 才會生效）
