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
    bc \
    cron  \
    ffmpeg \
    default-mysql-client

# Add docker php ext repo
ADD https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions /usr/local/bin/

RUN set -eux; \
    chmod +x /usr/local/bin/install-php-extensions; \
    install-php-extensions \
    amqp \
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
    pdo_pgsql \
    pgsql \
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

# 如果此用 PHP 8 以下版本，則 composer 降級
RUN if [ $(echo "$PHP_VERSION < 8" | bc) -eq 1 ]; then \
        # composer 降級
        composer self-update --1; \
    fi

# Install NodeJs 16.x
ARG NODEJS_VERSION
RUN apt-get update -yq \
    && curl -sL https://deb.nodesource.com/setup_${NODEJS_VERSION}.x | bash \
    && apt-get install nodejs -yq

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