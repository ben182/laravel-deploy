FROM serversideup/php:8.4-fpm-nginx

# Install additional extensions and tools
USER root
RUN apt-get update && apt-get install -y \
    cron \
    && rm -rf /var/lib/apt/lists/*

# Configure PHP for production
RUN echo "upload_max_filesize = 50M" >> /usr/local/etc/php/conf.d/docker-php-ext-uploads.ini && \
    echo "post_max_size = 50M" >> /usr/local/etc/php/conf.d/docker-php-ext-uploads.ini && \
    echo "max_execution_time = 300" >> /usr/local/etc/php/conf.d/docker-php-ext-uploads.ini && \
    echo "memory_limit = 512M" >> /usr/local/etc/php/conf.d/docker-php-ext-uploads.ini

# Set working directory
WORKDIR /var/www/html

# Copy application files
COPY . .

# Install Composer dependencies if composer.json exists
RUN if [ -f "composer.json" ]; then \
        composer install --no-dev --optimize-autoloader --no-interaction; \
    fi

# Set proper permissions
RUN chown -R www-data:www-data /var/www/html && \
    if [ -d "storage" ]; then chmod -R 755 /var/www/html/storage; fi && \
    if [ -d "bootstrap/cache" ]; then chmod -R 755 /var/www/html/bootstrap/cache; fi

# Switch back to www-data user
USER www-data

# Expose port
EXPOSE 8080

# Use the default serversideup/php entrypoint (S6 Overlay)
# This will automatically start PHP-FPM and Nginx