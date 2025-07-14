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