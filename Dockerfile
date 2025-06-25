FROM php:8.2-fpm

RUN apt-get update && apt-get install -y \
    nginx \
    git \
    openssh-server \
    zip unzip \
    libzip-dev \
    libpng-dev \
    libonig-dev \
    libxml2-dev \
    && docker-php-ext-install pdo_mysql zip mbstring exif pcntl bcmath gd

# Install Composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Fix Git ownership issue and clone repository
RUN git config --global --add safe.directory /var/www/html && \
    rm -rf /var/www/html/* && \
    git clone https://github.com/ChanSuvannet/DevOps_Final_Exam.git /var/www/html && \
    cd /var/www/html && \
    composer install --optimize-autoloader && \
    chown -R www-data:www-data /var/www/html && \
    chmod -R 775 /var/www/html/storage /var/www/html/bootstrap/cache

# Create .env file
RUN cd /var/www/html && \
    printf '%s\n' \
'APP_NAME=Laravel' \
'APP_ENV=production' \
'APP_KEY=' \
'APP_DEBUG=false' \
'APP_URL=http://localhost' \
'' \
'DB_CONNECTION=mysql' \
'DB_HOST=127.0.0.1' \
'DB_PORT=3306' \
'DB_DATABASE=chansuvannet-db' \
'DB_USERNAME=root' \
'DB_PASSWORD=Hello@123' \
> .env

# Install Pest and initialize
RUN cd /var/www/html && \
    composer require pestphp/pest pestphp/pest-plugin-laravel --dev && \
    ./vendor/bin/pest --init

COPY default.conf /etc/nginx/conf.d/default.conf

RUN mkdir /var/run/sshd

EXPOSE 8080 22

CMD ["sh", "-c", "service ssh start && nginx && php-fpm"]