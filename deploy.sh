#!/bin/bash

# Laravel Zero-Downtime Deployment Script
# Usage: ./deploy.sh [options]
# Run this script from your Laravel project root directory

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_LOCK_FILE="/tmp/deploy.lock"

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

show_usage() {
    echo "Laravel Zero-Downtime Deployment Script"
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Run this script from your Laravel project root directory."
    echo "The script will look for deploy.yml in the current directory."
    echo ""
    echo "Options:"
    echo "  --branch      Git branch to deploy (overrides config)"
    echo "  --skip-backup Skip database backup"
    echo "  --skip-build  Skip build process"
    echo "  --force       Force deployment (ignore checks)"
    echo "  --rollback    Rollback to previous deployment"
    echo "  --config      Path to deploy.yml (default: ./deploy.yml)"
    echo "  -h, --help    Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0"
    echo "  $0 --branch develop"
    echo "  $0 --skip-backup"
    echo "  $0 --rollback"
    echo "  $0 --config custom-deploy.yml"
}

check_dependencies() {
    local missing_deps=()
    
    command -v docker >/dev/null 2>&1 || missing_deps+=("docker")
    command -v docker-compose >/dev/null 2>&1 || missing_deps+=("docker-compose")
    command -v git >/dev/null 2>&1 || missing_deps+=("git")
    command -v nginx >/dev/null 2>&1 || missing_deps+=("nginx")
    command -v yq >/dev/null 2>&1 || missing_deps+=("yq")
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        log_error "Missing dependencies: ${missing_deps[*]}"
        log_info "Install missing dependencies and try again"
        exit 1
    fi
}

install_yq() {
    if ! command -v yq >/dev/null 2>&1; then
        log_info "Installing yq for YAML processing..."
        wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
        chmod +x /usr/local/bin/yq
        log_success "yq installed successfully"
    fi
}

check_lock() {
    if [ -f "$DEPLOY_LOCK_FILE" ]; then
        local lock_pid=$(cat "$DEPLOY_LOCK_FILE")
        if kill -0 "$lock_pid" 2>/dev/null; then
            log_error "Another deployment is already running (PID: $lock_pid)"
            exit 1
        else
            log_warning "Stale lock file found, removing it"
            rm -f "$DEPLOY_LOCK_FILE"
        fi
    fi
}

create_lock() {
    echo $$ > "$DEPLOY_LOCK_FILE"
}

remove_lock() {
    rm -f "$DEPLOY_LOCK_FILE"
}

cleanup() {
    log_info "Cleaning up..."
    remove_lock
}

check_deploy_config() {
    local config_file="${1:-deploy.yml}"
    
    DEPLOY_CONFIG="$PWD/$config_file"
    
    if [ ! -f "$DEPLOY_CONFIG" ]; then
        log_error "Deploy configuration not found: $DEPLOY_CONFIG"
        log_info "Please create a deploy.yml file in your project root"
        log_info "Run this script from your Laravel project directory"
        exit 1
    fi
    
    log_success "Found deploy configuration: $DEPLOY_CONFIG"
}

load_project_config() {
    log_info "Loading project configuration..."
    
    # Load project configuration from deploy.yml
    PROJECT_NAME=$(yq eval ".project.name" "$DEPLOY_CONFIG")
    PROJECT_DESCRIPTION=$(yq eval ".project.description" "$DEPLOY_CONFIG")
    
    # Server config
    SERVER_HOST=$(yq eval ".server.host" "$DEPLOY_CONFIG")
    SERVER_USER=$(yq eval ".server.user" "$DEPLOY_CONFIG")
    SERVER_PORT=$(yq eval ".server.port" "$DEPLOY_CONFIG")
    SSH_KEY=$(yq eval ".server.ssh_key" "$DEPLOY_CONFIG")
    
    # Domain config
    PROJECT_DOMAIN=$(yq eval ".domain.primary" "$DEPLOY_CONFIG")
    PROJECT_ALIASES=$(yq eval ".domain.aliases[]?" "$DEPLOY_CONFIG" 2>/dev/null | tr '\n' ' ' || echo "")
    SSL_EMAIL=$(yq eval ".domain.ssl.email" "$DEPLOY_CONFIG")
    FORCE_HTTPS=$(yq eval ".domain.ssl.force_https" "$DEPLOY_CONFIG")
    
    # Git config
    GIT_REPO=$(yq eval ".git.repository" "$DEPLOY_CONFIG")
    GIT_BRANCH=${OVERRIDE_BRANCH:-$(yq eval ".git.branch" "$DEPLOY_CONFIG")}
    GIT_DEPLOY_KEY=$(yq eval ".git.deploy_key" "$DEPLOY_CONFIG")
    
    # Database config
    DB_NAME=$(yq eval ".database.name" "$DEPLOY_CONFIG")
    DB_USER=$(yq eval ".database.user" "$DEPLOY_CONFIG")
    DB_PASS=$(yq eval ".database.password" "$DEPLOY_CONFIG")
    DB_ROOT_PASS=$(yq eval ".database.root_password" "$DEPLOY_CONFIG")
    
    # Redis config
    REDIS_PASSWORD=$(yq eval ".redis.password" "$DEPLOY_CONFIG")
    REDIS_MAX_MEMORY=$(yq eval ".redis.max_memory" "$DEPLOY_CONFIG")
    
    # Build config
    NODE_VERSION=$(yq eval ".build.node_version" "$DEPLOY_CONFIG")
    PHP_VERSION=$(yq eval ".build.php_version" "$DEPLOY_CONFIG")
    COMPOSER_INSTALL=$(yq eval ".build.composer.install" "$DEPLOY_CONFIG")
    COMPOSER_FLAGS=$(yq eval ".build.composer.flags" "$DEPLOY_CONFIG")
    NPM_INSTALL=$(yq eval ".build.npm.install" "$DEPLOY_CONFIG")
    NPM_BUILD_CMD=$(yq eval ".build.npm.build_command" "$DEPLOY_CONFIG")
    
    # App config
    APP_ENV=$(yq eval ".app.environment" "$DEPLOY_CONFIG")
    APP_DEBUG=$(yq eval ".app.debug" "$DEPLOY_CONFIG")
    APP_KEY=$(yq eval ".app.key" "$DEPLOY_CONFIG")
    APP_TIMEZONE=$(yq eval ".app.timezone" "$DEPLOY_CONFIG")
    
    # Deployment config
    DEPLOY_STRATEGY=$(yq eval ".deployment.strategy" "$DEPLOY_CONFIG")
    HEALTH_CHECK_URL=$(yq eval ".deployment.health_check.url" "$DEPLOY_CONFIG")
    HEALTH_CHECK_ENABLED=$(yq eval ".deployment.health_check.enabled" "$DEPLOY_CONFIG")
    BACKUP_BEFORE_DEPLOY=$(yq eval ".deployment.backup.before_deploy" "$DEPLOY_CONFIG")
    RUN_MIGRATIONS=$(yq eval ".deployment.migrations.run" "$DEPLOY_CONFIG")
    CLEAR_CACHE=$(yq eval ".deployment.cache.clear_before" "$DEPLOY_CONFIG")
    
    # Docker config
    DOCKER_MEMORY=$(yq eval ".docker.resources.memory" "$DEPLOY_CONFIG")
    DOCKER_CPU=$(yq eval ".docker.resources.cpu" "$DEPLOY_CONFIG")
    
    # Queue config
    QUEUE_WORKERS=$(yq eval ".queue.workers" "$DEPLOY_CONFIG")
    QUEUE_CONNECTION=$(yq eval ".queue.connection" "$DEPLOY_CONFIG")
    
    # Monitoring config
    MONITORING_ENABLED=$(yq eval ".monitoring.enabled" "$DEPLOY_CONFIG")
    WEBHOOK_URL=$(yq eval ".monitoring.webhook_url" "$DEPLOY_CONFIG")
    
    # Generate project identifier from domain
    PROJECT_ID=$(echo "$PROJECT_DOMAIN" | sed 's/[^a-zA-Z0-9]/_/g')
    
    # Get/assign port for this project
    PROJECT_PORT=$(ssh_exec "/home/$SERVER_USER/deploy/port-manager.sh get $PROJECT_ID")
    if [ $? -ne 0 ]; then
        log_error "Failed to assign port for project"
        exit 1
    fi
    
    # Set server paths
    PROJECTS_DIR="/home/$SERVER_USER/projects"
    BACKUPS_DIR="/home/$SERVER_USER/backups"
    LOGS_DIR="/home/$SERVER_USER/logs"
    
    # Set project paths
    PROJECT_DIR="$PROJECTS_DIR/$PROJECT_ID"
    CURRENT_DIR="$PROJECT_DIR/current"
    RELEASES_DIR="$PROJECT_DIR/releases"
    SHARED_DIR="$PROJECT_DIR/shared"
    BACKUP_DIR="$BACKUPS_DIR/$PROJECT_ID"
    LOG_FILE="$LOGS_DIR/${PROJECT_ID}_deploy.log"
    
    log_info "Project: $PROJECT_NAME"
    log_info "Domain: $PROJECT_DOMAIN"
    log_info "Server: $SERVER_HOST"
    log_info "Branch: $GIT_BRANCH"
    log_info "Strategy: $DEPLOY_STRATEGY"
}

# SSH connection helper
ssh_exec() {
    local command="$1"
    local ssh_key_expanded="${SSH_KEY/#\~/$HOME}"
    
    ssh -i "$ssh_key_expanded" \
        -p "$SERVER_PORT" \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -o LogLevel=ERROR \
        "$SERVER_USER@$SERVER_HOST" \
        "$command"
}

# SCP file transfer helper
scp_upload() {
    local local_file="$1"
    local remote_file="$2"
    local ssh_key_expanded="${SSH_KEY/#\~/$HOME}"
    
    scp -i "$ssh_key_expanded" \
        -P "$SERVER_PORT" \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -o LogLevel=ERROR \
        "$local_file" \
        "$SERVER_USER@$SERVER_HOST:$remote_file"
}

create_project_structure() {
    log_info "Creating project directory structure on server..."
    
    ssh_exec "mkdir -p $PROJECT_DIR"
    ssh_exec "mkdir -p $RELEASES_DIR"
    ssh_exec "mkdir -p $SHARED_DIR"
    ssh_exec "mkdir -p $BACKUP_DIR"
    ssh_exec "mkdir -p $LOGS_DIR"
    ssh_exec "mkdir -p /home/$SERVER_USER/deploy"
    
    # Create shared directories
    ssh_exec "mkdir -p $SHARED_DIR/storage"
    ssh_exec "mkdir -p $SHARED_DIR/bootstrap/cache"
    
    # Upload port manager script if not exists
    if ! ssh_exec "test -f /home/$SERVER_USER/deploy/port-manager.sh"; then
        scp_upload "$SCRIPT_DIR/server/port-manager.sh" "/home/$SERVER_USER/deploy/port-manager.sh"
        ssh_exec "chmod +x /home/$SERVER_USER/deploy/port-manager.sh"
    fi
    
    log_success "Project structure created on server"
}

backup_database() {
    if [ "$SKIP_BACKUP" = true ]; then
        log_info "Skipping database backup (--skip-backup)"
        return
    fi
    
    if [ "$BACKUP_BEFORE_DEPLOY" != "true" ]; then
        log_info "Database backup disabled in config"
        return
    fi
    
    log_info "Creating database backup..."
    
    local backup_file="${DB_NAME}_$(date +%Y%m%d_%H%M%S).sql"
    
    ssh_exec "docker exec ${PROJECT_ID}-mysql mysqldump -u $DB_USER -p$DB_PASS $DB_NAME > $BACKUP_DIR/$backup_file"
    ssh_exec "gzip $BACKUP_DIR/$backup_file"
    
    log_success "Database backup created: ${backup_file}.gz"
    
    # Clean old backups (keep last 7 days)
    ssh_exec "find $BACKUP_DIR -name '*.sql.gz' -mtime +7 -delete"
}

clone_repository() {
    local release_id=$(date +%Y%m%d_%H%M%S)
    local release_dir="$RELEASES_DIR/$release_id"
    
    CURRENT_RELEASE_DIR="$release_dir"
    
    log_info "Cloning repository to server..."
    
    # Setup SSH key for git if deploy key is specified
    if [ "$GIT_DEPLOY_KEY" != "null" ] && [ -n "$GIT_DEPLOY_KEY" ]; then
        local deploy_key_expanded="${GIT_DEPLOY_KEY/#\~/$HOME}"
        ssh_exec "eval \$(ssh-agent -s) && ssh-add $deploy_key_expanded"
    fi
    
    ssh_exec "git clone --depth 1 --branch $GIT_BRANCH $GIT_REPO $release_dir"
    
    # Create commit info file
    ssh_exec "cd $release_dir && echo 'Branch: $GIT_BRANCH' > deployment-info.txt"
    ssh_exec "cd $release_dir && echo 'Commit: \$(git rev-parse HEAD)' >> deployment-info.txt"
    ssh_exec "cd $release_dir && echo 'Date: \$(date)' >> deployment-info.txt"
    ssh_exec "cd $release_dir && echo 'User: \$(whoami)' >> deployment-info.txt"
    
    log_success "Repository cloned successfully"
}

setup_environment() {
    log_info "Setting up environment..."
    
    cd "$CURRENT_RELEASE_DIR"
    
    # Copy environment file
    if [ -f "$SCRIPT_DIR/$ENV_FILE" ]; then
        cp "$SCRIPT_DIR/$ENV_FILE" .env
        log_success "Environment file copied"
    else
        log_warning "Environment file not found: $SCRIPT_DIR/$ENV_FILE"
    fi
    
    # Link shared directories
    rm -rf storage bootstrap/cache
    ln -sf "$SHARED_DIR/storage" storage
    ln -sf "$SHARED_DIR/bootstrap/cache" bootstrap/cache
    
    log_success "Environment setup completed"
}

build_application() {
    if [ "$SKIP_BUILD" = true ]; then
        log_info "Skipping build process (--skip-build)"
        return
    fi
    
    log_info "Building application..."
    
    cd "$CURRENT_RELEASE_DIR"
    
    # Install Composer dependencies
    if [ "$COMPOSER_INSTALL" = "true" ]; then
        log_info "Installing Composer dependencies..."
        composer install --no-dev --optimize-autoloader --no-interaction
    fi
    
    # Install NPM dependencies
    if [ "$NPM_INSTALL" = "true" ]; then
        log_info "Installing NPM dependencies..."
        npm ci --production
    fi
    
    # Build assets
    if [ "$NPM_BUILD" = "true" ]; then
        log_info "Building assets..."
        npm run build
    fi
    
    log_success "Application built successfully"
}

run_migrations() {
    if [ "$RUN_MIGRATIONS" != "true" ]; then
        log_info "Migrations disabled in config"
        return
    fi
    
    log_info "Running database migrations..."
    
    cd "$CURRENT_RELEASE_DIR"
    
    # Run migrations using Docker
    docker run --rm \
        -v "$CURRENT_RELEASE_DIR:/var/www/html" \
        -e DB_HOST="${project}-mysql" \
        -e DB_DATABASE="$DB_NAME" \
        -e DB_USERNAME="$DB_USER" \
        -e DB_PASSWORD="$DB_PASS" \
        --network="${project}_default" \
        serversideup/php:${PHP_VERSION}-cli \
        php artisan migrate --force
    
    log_success "Migrations completed"
}

clear_cache() {
    if [ "$CLEAR_CACHE" != "true" ]; then
        log_info "Cache clearing disabled in config"
        return
    fi
    
    log_info "Clearing application cache..."
    
    cd "$CURRENT_RELEASE_DIR"
    
    # Clear cache using Docker
    docker run --rm \
        -v "$CURRENT_RELEASE_DIR:/var/www/html" \
        serversideup/php:${PHP_VERSION}-cli \
        sh -c "php artisan config:cache && php artisan route:cache && php artisan view:cache"
    
    log_success "Cache cleared successfully"
}

deploy_blue_green() {
    log_info "Deploying using Blue-Green strategy..."
    
    # Build new Docker image
    cd "$CURRENT_RELEASE_DIR"
    
    local new_image="${project}:$(date +%Y%m%d_%H%M%S)"
    local current_image="${project}:current"
    
    # Build new image
    docker build -t "$new_image" .
    
    # Update docker-compose with new image
    sed -i "s|image: .*|image: $new_image|g" "$COMPOSE_FILE"
    
    # Start new containers
    PROJECT_NAME="$project" docker-compose -f "$COMPOSE_FILE" up -d
    
    # Health check
    if perform_health_check; then
        # Tag as current
        docker tag "$new_image" "$current_image"
        
        # Update symlink
        ln -sfn "$CURRENT_RELEASE_DIR" "$CURRENT_DIR"
        
        # Update Nginx configuration
        update_nginx_config
        
        log_success "Blue-Green deployment completed successfully"
    else
        log_error "Health check failed, rolling back..."
        docker-compose -f "$COMPOSE_FILE" down
        exit 1
    fi
}

deploy_rolling() {
    log_info "Deploying using Rolling strategy..."
    
    cd "$CURRENT_RELEASE_DIR"
    
    # Build and deploy incrementally
    docker build -t "${project}:latest" .
    
    # Update containers one by one
    PROJECT_NAME="$project" docker-compose -f "$COMPOSE_FILE" up -d --no-deps app
    
    # Health check
    if perform_health_check; then
        # Update symlink
        ln -sfn "$CURRENT_RELEASE_DIR" "$CURRENT_DIR"
        
        # Update Nginx configuration
        update_nginx_config
        
        log_success "Rolling deployment completed successfully"
    else
        log_error "Health check failed, rolling back..."
        rollback_deployment
        exit 1
    fi
}

deploy_recreate() {
    log_info "Deploying using Recreate strategy..."
    
    cd "$CURRENT_RELEASE_DIR"
    
    # Stop existing containers
    PROJECT_NAME="$project" docker-compose -f "$COMPOSE_FILE" down
    
    # Build new image
    docker build -t "${project}:latest" .
    
    # Start new containers
    PROJECT_NAME="$project" docker-compose -f "$COMPOSE_FILE" up -d
    
    # Health check
    if perform_health_check; then
        # Update symlink
        ln -sfn "$CURRENT_RELEASE_DIR" "$CURRENT_DIR"
        
        # Update Nginx configuration
        update_nginx_config
        
        log_success "Recreate deployment completed successfully"
    else
        log_error "Health check failed"
        exit 1
    fi
}

perform_health_check() {
    if [ "$HEALTH_CHECK_URL" = "null" ] || [ -z "$HEALTH_CHECK_URL" ]; then
        log_info "No health check URL configured"
        return 0
    fi
    
    log_info "Performing health check..."
    
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if curl -f -s "http://$PROJECT_DOMAIN$HEALTH_CHECK_URL" >/dev/null 2>&1; then
            log_success "Health check passed"
            return 0
        fi
        
        log_info "Health check attempt $attempt/$max_attempts failed, retrying..."
        sleep 10
        ((attempt++))
    done
    
    log_error "Health check failed after $max_attempts attempts"
    return 1
}

update_nginx_config() {
    log_info "Updating Nginx configuration..."
    
    local nginx_config="/etc/nginx/sites-available/$PROJECT_ID"
    
    # Create Nginx configuration from template
    ssh_exec "cat > $nginx_config << 'EOF'
server {
    listen 80;
    server_name $PROJECT_DOMAIN$([ -n "$PROJECT_ALIASES" ] && echo " $PROJECT_ALIASES");
    
    # Always redirect HTTP to HTTPS
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $PROJECT_DOMAIN$([ -n "$PROJECT_ALIASES" ] && echo " $PROJECT_ALIASES");
    
    # SSL configuration (managed by Certbot)
    ssl_certificate /etc/letsencrypt/live/$PROJECT_DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$PROJECT_DOMAIN/privkey.pem;
    
    # SSL settings
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-SHA256:ECDHE-RSA-AES256-SHA384;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    ssl_stapling on;
    ssl_stapling_verify on;
    
    # Security headers
    add_header Strict-Transport-Security \"max-age=31536000; includeSubDomains\" always;
    add_header X-Frame-Options \"SAMEORIGIN\" always;
    add_header X-Content-Type-Options \"nosniff\" always;
    add_header X-XSS-Protection \"1; mode=block\" always;
    add_header Referrer-Policy \"strict-origin-when-cross-origin\" always;
    
    # Rate limiting
    limit_req zone=api burst=20 nodelay;
    
    # Proxy to Docker container
    location / {
        proxy_pass http://127.0.0.1:$PROJECT_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$server_name;
        
        # Proxy timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        
        # Buffer settings
        proxy_buffering on;
        proxy_buffer_size 128k;
        proxy_buffers 4 256k;
        proxy_busy_buffers_size 256k;
    }
    
    # Health check endpoint
    location /health {
        access_log off;
        proxy_pass http://127.0.0.1:$PROJECT_PORT/health;
        proxy_set_header Host \$host;
    }
    
    # Static file handling
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|woff|woff2|ttf|eot|svg)$ {
        expires 1y;
        add_header Cache-Control \"public, immutable\";
        access_log off;
    }
    
    # Deny access to hidden files
    location ~ /\. {
        deny all;
    }
    
    # Client settings
    client_max_body_size 50M;
    client_body_timeout 60s;
    client_header_timeout 60s;
}
EOF"
    
    # Enable site
    ssh_exec "ln -sf $nginx_config /etc/nginx/sites-enabled/$PROJECT_ID"
    
    # Test and reload Nginx
    ssh_exec "nginx -t && systemctl reload nginx"
    
    # Setup SSL certificate
    setup_ssl
    
    log_success "Nginx configuration updated"
}

setup_ssl() {
    log_info "Setting up SSL certificate..."
    
    local domains="$PROJECT_DOMAIN"
    if [ -n "$PROJECT_ALIASES" ]; then
        domains="$domains,$(echo "$PROJECT_ALIASES" | tr ' ' ',')"
    fi
    
    ssh_exec "certbot --nginx --non-interactive --agree-tos --email $SSL_EMAIL -d $domains"
    
    log_success "SSL certificate configured"
}

rollback_deployment() {
    log_info "Rolling back deployment..."
    
    # Find previous release
    local previous_release=$(ls -1 "$RELEASES_DIR" | sort -r | sed -n '2p')
    
    if [ -z "$previous_release" ]; then
        log_error "No previous release found for rollback"
        return 1
    fi
    
    local previous_dir="$RELEASES_DIR/$previous_release"
    
    log_info "Rolling back to: $previous_release"
    
    # Update symlink
    ln -sfn "$previous_dir" "$CURRENT_DIR"
    
    # Restart containers
    cd "$previous_dir"
    PROJECT_NAME="$project" docker-compose -f "$COMPOSE_FILE" up -d
    
    log_success "Rollback completed successfully"
}

cleanup_old_releases() {
    log_info "Cleaning up old releases..."
    
    # Keep last 5 releases
    ls -1 "$RELEASES_DIR" | sort -r | tail -n +6 | while read -r release; do
        rm -rf "$RELEASES_DIR/$release"
        log_info "Removed old release: $release"
    done
    
    log_success "Old releases cleaned up"
}

send_notification() {
    local status=$1
    local message=$2
    
    log_info "Deployment $status: $message"
    
    # Log to file
    echo "$(date): $PROJECT_NAME - $status: $message" >> "$LOG_FILE"
    
    # Send webhook notification if configured
    local webhook_url=$(yq eval ".projects.${project}.monitoring.webhook_url" "$CONFIG_FILE")
    if [ "$webhook_url" != "null" ] && [ -n "$webhook_url" ]; then
        curl -X POST -H "Content-Type: application/json" \
            -d "{\"text\":\"$PROJECT_NAME deployment $status: $message\"}" \
            "$webhook_url" >/dev/null 2>&1 || true
    fi
}

main() {
    local config_file="deploy.yml"
    
    # Parse options
    while [[ $# -gt 0 ]]; do
        case $1 in
            --branch)
                OVERRIDE_BRANCH="$2"
                shift 2
                ;;
            --skip-backup)
                SKIP_BACKUP=true
                shift
                ;;
            --skip-build)
                SKIP_BUILD=true
                shift
                ;;
            --force)
                FORCE_DEPLOY=true
                shift
                ;;
            --rollback)
                ROLLBACK_ONLY=true
                shift
                ;;
            --config)
                config_file="$2"
                shift 2
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # Set trap for cleanup
    trap cleanup EXIT
    
    # Pre-deployment checks
    install_yq
    check_dependencies
    check_deploy_config "$config_file"
    check_lock
    create_lock
    
    # Load project configuration
    load_project_config
    
    # Handle rollback
    if [ "$ROLLBACK_ONLY" = true ]; then
        rollback_deployment
        send_notification "SUCCESS" "Rollback completed"
        exit 0
    fi
    
    # Start deployment
    send_notification "STARTED" "Deployment started"
    
    create_project_structure
    backup_database
    clone_repository
    setup_environment
    build_application
    run_migrations
    clear_cache
    
    # Deploy based on strategy
    case "$DEPLOY_STRATEGY" in
        "blue-green")
            deploy_blue_green
            ;;
        "rolling")
            deploy_rolling
            ;;
        "recreate")
            deploy_recreate
            ;;
        *)
            log_error "Unknown deployment strategy: $DEPLOY_STRATEGY"
            exit 1
            ;;
    esac
    
    cleanup_old_releases
    send_notification "SUCCESS" "Deployment completed successfully"
    
    log_success "Deployment completed successfully!"
    log_info "Project URL: https://$PROJECT_DOMAIN"
}

main "$@"