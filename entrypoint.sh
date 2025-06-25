#!/bin/bash
set -e

# Function to log messages
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "Starting Laravel application setup..."

# Wait for database to be ready if DB_HOST is set
if [ -n "$DB_HOST" ] && [ "$DB_HOST" != "localhost" ] && [ "$DB_HOST" != "127.0.0.1" ]; then
    log "Waiting for database at $DB_HOST:${DB_PORT:-3306}..."
    
    max_attempts=30
    attempt=0
    
    while ! nc -z "$DB_HOST" "${DB_PORT:-3306}"; do
        attempt=$((attempt + 1))
        if [ $attempt -ge $max_attempts ]; then
            log "ERROR: Database is not ready after $max_attempts attempts"
            exit 1
        fi
        log "Database not ready, waiting... (attempt $attempt/$max_attempts)"
        sleep 2
    done
    
    log "Database is ready!"
fi

# Generate .env file
log "Generating .env configuration..."
cat <<EOF > /var/www/html/.env
APP_NAME=Laravel
APP_ENV=${APP_ENV:-production}
APP_KEY=
APP_DEBUG=${APP_DEBUG:-false}
APP_URL=${APP_URL:-http://localhost}

LOG_CHANNEL=stack
LOG_DEPRECATIONS_CHANNEL=null
LOG_LEVEL=debug

DB_CONNECTION=mysql
DB_HOST=${DB_HOST:-127.0.0.1}
DB_PORT=${DB_PORT:-3306}
DB_DATABASE=${DB_DATABASE:-chansuvannet-db}
DB_USERNAME=${DB_USERNAME:-root}
DB_PASSWORD=${DB_PASSWORD:-Hello@123}

BROADCAST_DRIVER=log
CACHE_DRIVER=file
FILESYSTEM_DISK=local
QUEUE_CONNECTION=sync
SESSION_DRIVER=file
SESSION_LIFETIME=120

MEMCACHED_HOST=127.0.0.1

REDIS_HOST=127.0.0.1
REDIS_PASSWORD=null
REDIS_PORT=6379

MAIL_MAILER=smtp
MAIL_HOST=mailpit
MAIL_PORT=1025
MAIL_USERNAME=null
MAIL_PASSWORD=null
MAIL_ENCRYPTION=null
MAIL_FROM_ADDRESS="hello@example.com"
MAIL_FROM_NAME="\${APP_NAME}"

AWS_ACCESS_KEY_ID=
AWS_SECRET_ACCESS_KEY=
AWS_DEFAULT_REGION=us-east-1
AWS_BUCKET=
AWS_USE_PATH_STYLE_ENDPOINT=false

PUSHER_APP_ID=
PUSHER_APP_KEY=
PUSHER_APP_SECRET=
PUSHER_HOST=
PUSHER_PORT=443
PUSHER_SCHEME=https
PUSHER_APP_CLUSTER=mt1

VITE_PUSHER_APP_KEY="\${PUSHER_APP_KEY}"
VITE_PUSHER_HOST="\${PUSHER_HOST}"
VITE_PUSHER_PORT="\${PUSHER_PORT}"
VITE_PUSHER_SCHEME="\${PUSHER_SCHEME}"
VITE_PUSHER_APP_CLUSTER="\${PUSHER_APP_CLUSTER}"
EOF

# Set proper permissions for .env
chown www-data:www-data /var/www/html/.env
chmod 600 /var/www/html/.env

# Generate application key if not exists
log "Generating application key..."
if ! grep -q "APP_KEY=base64:" /var/www/html/.env; then
    php artisan key:generate --force
fi

# Set proper permissions
log "Setting file permissions..."
chown -R www-data:www-data /var/www/html/storage
chown -R www-data:www-data /var/www/html/bootstrap/cache
chmod -R 775 /var/www/html/storage
chmod -R 775 /var/www/html/bootstrap/cache

# Clear Laravel caches
log "Clearing Laravel caches..."
php artisan config:clear
php artisan cache:clear
php artisan route:clear
php artisan view:clear

# Run database migrations if requested
if [ "$RUN_MIGRATIONS" = "true" ]; then
    log "Running database migrations..."
    php artisan migrate --force
fi

# Create symbolic link for storage
if [ ! -L /var/www/html/public/storage ]; then
    log "Creating storage symbolic link..."
    php artisan storage:link
fi

# Optimize Laravel for production
if [ "$APP_ENV" = "production" ]; then
    log "Optimizing Laravel for production..."
    php artisan config:cache
    php artisan route:cache
    php artisan view:cache
fi

# Start PHP-FPM in background
log "Starting PHP-FPM..."
php-fpm -D

# Start nginx in foreground
log "Starting Nginx..."
exec nginx -g 'daemon off;'