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
    zsh \
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

# Install Claude CLI & GitHub Copilot CLI
RUN npm install -g @anthropic-ai/claude-code @github/copilot

# Install Google Cloud CLI
RUN curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" \
       > /etc/apt/sources.list.d/google-cloud-sdk.list \
    && apt-get update \
    && apt-get install -y google-cloud-cli

# Clear cache
RUN apt-get clean && rm -rf /var/lib/apt/lists/*

# Install Oh My Zsh
RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

# Install zsh plugins: autosuggestions + syntax highlighting + completions
RUN git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions \
        ${ZSH_CUSTOM:-/root/.oh-my-zsh/custom}/plugins/zsh-autosuggestions && \
    git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting \
        ${ZSH_CUSTOM:-/root/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting && \
    git clone --depth=1 https://github.com/zsh-users/zsh-completions \
        ${ZSH_CUSTOM:-/root/.oh-my-zsh/custom}/plugins/zsh-completions

# Enable plugins in .zshrc and configure autosuggestions
RUN sed -i 's/^plugins=(git)/plugins=(git zsh-autosuggestions zsh-syntax-highlighting zsh-completions docker composer)/' /root/.zshrc && \
    echo 'autoload -U compinit && compinit' >> /root/.zshrc && \
    echo 'ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=244"' >> /root/.zshrc && \
    echo 'ZSH_AUTOSUGGEST_STRATEGY=(history completion)' >> /root/.zshrc

# Set zsh as default shell
RUN chsh -s $(which zsh)

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
    echo "" >> /root/.bashrc && \
    echo "" >> /root/.zshrc && \
    echo "# Load Custom Aliases" >> /root/.zshrc && \
    echo "source /root/aliases.sh" >> /root/.zshrc && \
    echo "" >> /root/.zshrc

WORKDIR /var/www