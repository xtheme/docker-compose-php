ARG PHP_VERSION
FROM php:${PHP_VERSION}-fpm

# Install system dependencies
RUN set -eux; \
    apt-get update \
    && apt-get install -y \
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
    ffmpeg

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
    xlswriter \
    xsl \
    yac \
    yaml \
    zip

# Install composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
# composer 降級
RUN composer self-update --1

# Install Xdebug
# https://matthewsetter.com/setup-step-debugging-php-xdebug3-docker/
RUN pecl install xdebug-3.1.6 \
    && docker-php-ext-enable xdebug

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
    echo "" >> ~/.bashrc && \
    echo "# Load Custom Aliases" >> ~/.bashrc && \
    echo "source ~/aliases.sh" >> ~/.bashrc && \
    echo "" >> ~/.bashrc

WORKDIR /var/www