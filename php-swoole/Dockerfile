# Default Dockerfile
#
# @link     https://www.hyperf.io
# @document https://hyperf.wiki
# @contact  group@hyperf.io
# @license  https://github.com/hyperf/hyperf/blob/master/LICENSE

FROM hyperf/hyperf:8.3-alpine-v3.19-swoole-v5.1.2

LABEL maintainer="Hyperf Developers <group@hyperf.io>" version="1.0" license="MIT"

##
# ---------- env settings ----------
##
# --build-arg timezone=Asia/Shanghai
ARG timezone

ENV TIMEZONE=${timezone:-"Asia/Shanghai"} \
    COMPOSER_ALLOW_SUPERUSER=1

# update
RUN set -ex \
    # show php version and extensions
    && php -v \
    && php -m \
    && php --ri swoole \
    #  ---------- some config ----------
    && cd /etc/php* \
    # - config PHP
    && { \
    echo "upload_max_filesize=128M"; \
    echo "post_max_size=128M"; \
    echo "memory_limit=-1"; \
    echo "date.timezone=${TIMEZONE}"; \
    } | tee conf.d/99_overrides.ini \
    # - config timezone
    && ln -sf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime \
    && echo "${TIMEZONE}" > /etc/timezone \
    # ---------- clear works ----------
    && rm -rf /var/cache/apk/* /tmp/* /usr/share/man \
    && echo -e "\033[42;37m Build Completed :).\033[0m\n"

RUN apk upgrade \
    && apk add --update iputils curl nodejs-current npm apache2-utils wrk

# gif 轉 webp 工具
RUN apk add --no-cache libwebp libwebp-tools

# imagick
RUN apk add --no-cache php83-pecl-imagick

# User Aliases
COPY ./aliases.sh /root/aliases.sh

RUN sed -i 's/\r//' /root/aliases.sh && \
    echo "" >> ~/.bashrc && \
    echo "# Load Custom Aliases" >> ~/.bashrc && \
    echo "source ~/aliases.sh" >> ~/.bashrc && \
    echo "" >> ~/.bashrc

# Set default work directory
WORKDIR /var/www

# Composer Cache
# COPY ./composer.* /var/www/
# RUN composer install --no-dev --no-scripts

#COPY . /var/www
#RUN composer install --no-dev -o && php bin/hyperf.php

EXPOSE 8000 9500 9501 9502

ENTRYPOINT cd carrental_php && php bin/hyperf.php start