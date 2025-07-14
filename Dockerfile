FROM serversideup/php:8.4-fpm-nginx

# Install additional extensions and tools
USER root
RUN apt-get update && apt-get install -y \
    cron \
    supervisor \
    && rm -rf /var/lib/apt/lists/*

# Configure PHP for production
RUN echo "upload_max_filesize = 50M" >> /usr/local/etc/php/conf.d/docker-php-ext-uploads.ini && \
    echo "post_max_size = 50M" >> /usr/local/etc/php/conf.d/docker-php-ext-uploads.ini && \
    echo "max_execution_time = 300" >> /usr/local/etc/php/conf.d/docker-php-ext-uploads.ini && \
    echo "memory_limit = 512M" >> /usr/local/etc/php/conf.d/docker-php-ext-uploads.ini

# Configure Nginx
COPY docker/nginx/default.conf /etc/nginx/sites-available/default

# Configure Supervisor
COPY docker/supervisor/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Set working directory
WORKDIR /var/www/html

# Copy application files
COPY . .

# Install Composer dependencies
RUN composer install --no-dev --optimize-autoloader --no-interaction

# Set proper permissions
RUN chown -R www-data:www-data /var/www/html && \
    chmod -R 755 /var/www/html/storage && \
    chmod -R 755 /var/www/html/bootstrap/cache

# Switch back to www-data user
USER www-data

# Expose port
EXPOSE 80

# Start supervisor
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]