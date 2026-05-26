ARG PHP_VERSION
FROM php:${PHP_VERSION}-fpm

# Install system dependencies
RUN set -eux; \
    apt-get update && \
    apt-get install -y \
    apache2-utils \
    wrk \
    git \
    curl \
    gnupg \
    libpng-dev \
    libonig-dev \
    libxml2-dev \
    zip \
    unzip \
    cron  \
    ffmpeg \
    default-mysql-client

# Add docker php ext repo (pin version, /releases/latest/ 會踩到上游突變如 PECL yaml)
ADD https://github.com/mlocati/docker-php-extension-installer/releases/download/2.11.1/install-php-extensions /usr/local/bin/

RUN set -eux; \
    chmod +x /usr/local/bin/install-php-extensions; \
    install-php-extensions \
    apcu \
    bcmath \
    bz2 \
    calendar \
    decimal \
    enchant \
    event \
    exif \
    gd \
    gettext \
    gmp \
    igbinary \
    imagick \
    intl \
    lzf \
    memcached \
    mongodb \
    msgpack \
    mysqli \
    opcache \
    pcntl \
    pdo_mysql \
    redis \
    sockets \
    swoole \
    tidy \
    timezonedb \
    uuid \
    pcov \
    xdebug \
    xlswriter \
    xsl \
    yac \
    yaml \
    zip

# Copy php.ini for current PHP version (截取 major.minor，排除 patch 版本號)
COPY ./ini/ /tmp/php-ini/
RUN VERSION=$(echo ${PHP_VERSION} | cut -d. -f1,2) && \
    cp /tmp/php-ini/php${VERSION}.ini /usr/local/etc/php/php.ini && \
    rm -rf /tmp/php-ini

# Install composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Install NodeJS (latest Active LTS via NodeSource setup_lts.x;
# 若需鎖版本可在 .env 設 NODEJS_VERSION=<major>)
ARG NODEJS_VERSION
RUN set -eux; \
    if [ -n "$NODEJS_VERSION" ]; then \
        ENDPOINT="setup_${NODEJS_VERSION}.x"; \
    else \
        ENDPOINT="setup_lts.x"; \
    fi; \
    apt-get update -yq; \
    curl -fsSL https://deb.nodesource.com/${ENDPOINT} | bash -; \
    apt-get install -yq nodejs

# Clear cache
RUN apt-get clean && rm -rf /var/lib/apt/lists/*

# Timezone
ARG TIMEZONE=UTC
ENV TZ ${TIMEZONE}
RUN ln -snf /usr/share/zoneinfo/${TZ} /etc/localtime && echo ${TZ} > /etc/timezone

# Copy aliases
COPY ./aliases.sh /root/aliases.sh

RUN sed -i 's/\r//' /root/aliases.sh && \
    echo "" >> /root/.bashrc && \
    echo "# Load Custom Aliases" >> /root/.bashrc && \
    echo "source /root/aliases.sh" >> /root/.bashrc && \
    echo "" >> /root/.bashrc

WORKDIR /var/www