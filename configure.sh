#!/bin/bash

# Laravel Deploy Configuration Script
# Usage: ./configure.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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
    echo "Laravel Deploy Configuration Script"
    echo ""
    echo "Usage: $0"
    echo ""
    echo "This script helps you configure deploy.yml interactively."
    echo "Run this script from your Laravel project root directory."
}

update_env_file() {
    local project_name="$1"
    local domain="$2"
    local db_name="$3"
    local db_user="$4"
    local db_password="$5"
    
    local env_file="./.env"
    
    log_info "Updating .env file with Docker configuration..."
    
    # Create backup of existing .env if it exists
    if [ -f "$env_file" ]; then
        cp "$env_file" "$env_file.backup-$(date +%Y%m%d_%H%M%S)"
        log_info "Existing .env backed up"
    fi
    
    # If no .env exists, create a basic one
    if [ ! -f "$env_file" ]; then
        log_info "Creating new .env file..."
        cat > "$env_file" << 'EOF'
APP_NAME=Laravel
APP_ENV=local
APP_KEY=
APP_DEBUG=true
APP_TIMEZONE=UTC
APP_URL=http://localhost:8000

LOG_CHANNEL=stack
LOG_LEVEL=debug

DB_CONNECTION=mysql
DB_HOST=mysql
DB_PORT=3306
DB_DATABASE=laravel
DB_USERNAME=laravel
DB_PASSWORD=secret

REDIS_HOST=redis
REDIS_PASSWORD=null
REDIS_PORT=6379

CACHE_STORE=redis
SESSION_DRIVER=redis
QUEUE_CONNECTION=redis

MAIL_MAILER=log
EOF
    fi
    
    # Update or add specific Docker-related variables
    update_env_variable "$env_file" "APP_NAME" "$project_name"
    update_env_variable "$env_file" "APP_URL" "http://localhost:8000"
    update_env_variable "$env_file" "DB_CONNECTION" "mysql"
    update_env_variable "$env_file" "DB_HOST" "mysql"
    update_env_variable "$env_file" "DB_PORT" "3306"
    update_env_variable "$env_file" "DB_DATABASE" "$db_name"
    update_env_variable "$env_file" "DB_USERNAME" "$db_user"
    update_env_variable "$env_file" "DB_PASSWORD" "$db_password"
    update_env_variable "$env_file" "REDIS_HOST" "redis"
    update_env_variable "$env_file" "REDIS_PASSWORD" "null"
    update_env_variable "$env_file" "REDIS_PORT" "6379"
    update_env_variable "$env_file" "CACHE_STORE" "redis"
    update_env_variable "$env_file" "SESSION_DRIVER" "redis"
    update_env_variable "$env_file" "QUEUE_CONNECTION" "redis"
    
    # Generate APP_KEY if not exists or empty
    if ! grep -q "APP_KEY=" "$env_file" || grep -q "APP_KEY=$" "$env_file" || grep -q "APP_KEY=\"\"" "$env_file"; then
        local app_key="base64:$(openssl rand -base64 32)"
        update_env_variable "$env_file" "APP_KEY" "$app_key"
        log_info "Generated new APP_KEY"
    fi
    
    # Add Docker-specific variables if not present
    if ! grep -q "DOCKER_APP_PORT" "$env_file"; then
        echo "" >> "$env_file"
        echo "# Docker Configuration" >> "$env_file"
        echo "DOCKER_APP_PORT=8000" >> "$env_file"
        echo "DOCKER_DB_PORT=3306" >> "$env_file"
        echo "DOCKER_REDIS_PORT=6379" >> "$env_file"
    fi
    
    log_success ".env file updated with Docker configuration"
}

update_env_variable() {
    local env_file="$1"
    local var_name="$2"
    local var_value="$3"
    
    if grep -q "^${var_name}=" "$env_file"; then
        # Variable exists, update it using awk (more reliable)
        awk -v var="${var_name}" -v val="${var_value}" '
            $0 ~ "^" var "=" { print var "=" val; next }
            { print }
        ' "$env_file" > "$env_file.tmp"
        mv "$env_file.tmp" "$env_file"
    else
        # Variable doesn't exist, add it
        echo "${var_name}=${var_value}" >> "$env_file"
    fi
}

configure_deploy_yml() {
    local deploy_yml="./deploy.yml"
    
    if [ ! -f "$deploy_yml" ]; then
        log_error "deploy.yml not found in current directory"
        log_info "Please run this script from your Laravel project root"
        exit 1
    fi
    
    log_info "Configuring deploy.yml..."
    
    # Try to detect project name from directory
    local project_name=$(basename "$PWD")
    local domain_suggestion="${project_name}.com"
    
    # Interactive configuration
    echo ""
    echo "Let's configure your deployment settings:"
    echo ""
    
    read -p "Project name [$project_name]: " input_project_name
    project_name=${input_project_name:-$project_name}
    
    read -p "Primary domain [$domain_suggestion]: " input_domain
    domain=${input_domain:-$domain_suggestion}
    
    read -p "Server hostname (e.g., your-server.com): " server_host
    while [ -z "$server_host" ]; do
        read -p "Server hostname is required: " server_host
    done
    
    read -p "SSL email address (e.g., admin@$domain): " ssl_email
    while [ -z "$ssl_email" ]; do
        read -p "SSL email is required: " ssl_email
    done
    
    read -p "Database name [${project_name}_prod]: " db_name
    db_name=${db_name:-${project_name}_prod}
    
    read -p "Database user [${project_name}_user]: " db_user
    db_user=${db_user:-${project_name}_user}
    
    echo ""
    log_info "Generating secure passwords..."
    
    # Generate secure passwords
    local db_password=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
    local db_root_password=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
    local redis_password=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
    
    # Create backup
    cp "$deploy_yml" "$deploy_yml.backup"
    
    # Update deploy.yml with user input
    sed -i.tmp \
        -e "s/name: \"My Laravel App\"/name: \"$project_name\"/" \
        -e "s/host: \"your-server.example.com\"/host: \"$server_host\"/" \
        -e "s/primary: \"myapp.com\"/primary: \"$domain\"/" \
        -e "s/email: \"admin@myapp.com\"/email: \"$ssl_email\"/" \
        -e "s/name: \"myapp_prod\"/name: \"$db_name\"/" \
        -e "s/user: \"myapp_user\"/user: \"$db_user\"/" \
        -e "s/password: \"secure_random_password_here\"/password: \"$db_password\"/" \
        -e "s/root_password: \"secure_root_password\"/root_password: \"$db_root_password\"/" \
        -e "s/password: \"secure_redis_password\"/password: \"$redis_password\"/" \
        "$deploy_yml"
    
    # Remove temp file
    rm -f "$deploy_yml.tmp"
    
    log_success "deploy.yml configured successfully"
    log_info "Backup created: $deploy_yml.backup"
    
    # Update .env file with Docker configuration
    update_env_file "$project_name" "$domain" "$db_name" "$db_user" "$db_password"
    
    echo ""
    echo "Configuration summary:"
    echo "  Project: $project_name"
    echo "  Domain: $domain"
    echo "  Server: $server_host"
    echo "  SSL Email: $ssl_email"
    echo "  Database: $db_name"
    echo "  DB User: $db_user"
    echo "  Passwords: Generated automatically"
}

main() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        show_usage
        exit 0
    fi
    
    log_info "Laravel Deploy Configuration Script"
    
    configure_deploy_yml
    
    echo ""
    log_success "Configuration completed!"
    log_info "You can now run: ./deploy.sh"
}

main "$@"