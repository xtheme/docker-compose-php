ARG PHP_VERSION
ARG SWOOLE_VERSION
FROM phpswoole/swoole:${SWOOLE_VERSION}-php${PHP_VERSION}-alpine

RUN apk update && \
    apk --update add  \
    wget  \
    curl  \
    git  \
    libmcrypt-dev \
    libxml2-dev \
    vim  \
    busybox-extras  \
    iputils  \
    make  \
    procps

RUN docker-php-ext-install pcntl

WORKDIR /var/www