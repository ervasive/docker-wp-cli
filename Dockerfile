FROM php:7-fpm

# Install packages and php extensions
RUN apt-get update && apt-get install -y \
        sudo \
        less \
        mysql-client \
        libmysqlclient-dev \
        libfreetype6-dev \
        libjpeg62-turbo-dev \
        libpng12-dev \
    && docker-php-ext-configure gd --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/ \
    && docker-php-ext-install -j$(nproc) gd mysqli opcache \
    && apt-get clean; rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/*

# Set custom PHP overrides
RUN { \
        echo 'upload_max_filesize=100M'; \
        echo 'post_max_size=100M'; \
        echo 'cgi.fix_pathinfo=0'; \
    } > /usr/local/etc/php/conf.d/.user.ini

# Set recommended opcache settings
RUN { \
        echo 'opcache.memory_consumption=128'; \
        echo 'opcache.interned_strings_buffer=8'; \
        echo 'opcache.max_accelerated_files=4000'; \
        echo 'opcache.revalidate_freq=60'; \
        echo 'opcache.fast_shutdown=1'; \
        echo 'opcache.enable_cli=1'; \
    } > /usr/local/etc/php/conf.d/opcache-recommended.ini

# Add WP-CLI
RUN curl -o /bin/wp-cli.phar https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
COPY wp-su.sh /bin/wp
RUN chmod +x /bin/wp-cli.phar && chmod +x /bin/wp

WORKDIR /usr/share/nginx/html

# Set entrypoint script
COPY docker-entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
