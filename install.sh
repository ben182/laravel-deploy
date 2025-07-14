#!/bin/bash

# Laravel Docker Deployment System - GitHub Installer
# Usage: curl -fsSL https://raw.githubusercontent.com/ben182/laravel-deploy/main/install.sh | bash
# Or: ./install.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
GITHUB_REPO="ben182/laravel-deploy"
GITHUB_BRANCH="main"
GITHUB_RAW_URL="https://raw.githubusercontent.com/${GITHUB_REPO}/${GITHUB_BRANCH}"

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
    echo "Laravel Docker Deployment System - Installer"
    echo ""
    echo "Usage: $0"
    echo ""
    echo "This script will download and install the following files in the current directory:"
    echo "  - Dockerfile"
    echo "  - docker-compose.yml"
    echo "  - docker-compose.prod.yml"
    echo "  - docker.sh"
    echo "  - deploy.sh"
    echo "  - deploy.yml"
    echo "  - docker/ directory with configurations"
    echo ""
    echo "Run this script from your Laravel project root directory."
    echo ""
    echo "One-liner installation:"
    echo "  curl -fsSL ${GITHUB_RAW_URL}/install.sh | bash"
}

check_dependencies() {
    local missing_deps=()
    
    command -v curl >/dev/null 2>&1 || missing_deps+=("curl")
    command -v awk >/dev/null 2>&1 || missing_deps+=("awk")
    command -v openssl >/dev/null 2>&1 || missing_deps+=("openssl")
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        log_error "Missing dependencies: ${missing_deps[*]}"
        log_error "Please install the missing dependencies and try again"
        exit 1
    fi
}

check_target_directory() {
    local target_dir="$1"
    
    if [ ! -d "$target_dir" ]; then
        log_error "Target directory does not exist: $target_dir"
        exit 1
    fi
    
    # Check if it looks like a Laravel project
    if [ ! -f "$target_dir/artisan" ]; then
        log_warning "Target directory doesn't appear to be a Laravel project (no artisan file found)"
        
        # Check if running in non-interactive mode
        if [[ ! -t 0 ]]; then
            log_info "Non-interactive mode: Continuing anyway"
        else
            read -p "Continue anyway? (y/N): " -n 1 -r < /dev/tty
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log_info "Installation cancelled"
                exit 0
            fi
        fi
    fi
}

backup_existing_files() {
    local target_dir="$1"
    local backup_dir="$target_dir/.deployment-backup-$(date +%Y%m%d_%H%M%S)"
    local files_to_backup=()
    
    # Check which files already exist
    local files_to_check=(
        "Dockerfile"
        "docker-compose.yml"
        "docker-compose.prod.yml"
        "docker.sh"
        "deploy.sh"
        "deploy.yml"
        "docker/"
    )
    
    for file in "${files_to_check[@]}"; do
        if [ -e "$target_dir/$file" ]; then
            files_to_backup+=("$file")
        fi
    done
    
    if [ ${#files_to_backup[@]} -gt 0 ]; then
        log_warning "The following files already exist and will be backed up:"
        for file in "${files_to_backup[@]}"; do
            echo "  - $file"
        done
        
        # Check if running in non-interactive mode
        if [[ ! -t 0 ]]; then
            log_info "Non-interactive mode: Creating backup automatically"
        else
            read -p "Create backup and continue? (y/N): " -n 1 -r < /dev/tty
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log_info "Installation cancelled"
                exit 0
            fi
        fi
        
        # Create backup
        mkdir -p "$backup_dir"
        for file in "${files_to_backup[@]}"; do
            cp -r "$target_dir/$file" "$backup_dir/"
        done
        
        log_success "Backup created in: $backup_dir"
    fi
}

download_file() {
    local url="$1"
    local target_path="$2"
    
    log_info "Downloading: $(basename "$target_path")"
    
    if ! curl -fsSL "$url" -o "$target_path"; then
        log_error "Failed to download: $url"
        exit 1
    fi
}

download_files() {
    local target_dir="$1"
    
    log_info "Downloading files from GitHub..."
    
    # Download main files
    local files_to_download=(
        "Dockerfile"
        "docker-compose.yml"
        "docker-compose.prod.yml"
        "docker.sh"
        "deploy.sh"
        "deploy.yml"
        "configure.sh"
    )
    
    for file in "${files_to_download[@]}"; do
        download_file "${GITHUB_RAW_URL}/$file" "$target_dir/$file"
    done
    
    # Download docker directory files
    mkdir -p "$target_dir/docker/nginx"
    mkdir -p "$target_dir/docker/supervisor"
    mkdir -p "$target_dir/docker/php"
    mkdir -p "$target_dir/docker/mysql"
    
    # Docker configuration files
    local docker_files=(
        "docker/nginx/default.conf"
        "docker/supervisor/supervisord.conf"
        "docker/php/local.ini"
        "docker/mysql/init.sql"
        "docker/mysql/my.cnf"
    )
    
    for file in "${docker_files[@]}"; do
        download_file "${GITHUB_RAW_URL}/$file" "$target_dir/$file"
    done
    
    # Make scripts executable
    chmod +x "$target_dir/docker.sh"
    chmod +x "$target_dir/deploy.sh"
    chmod +x "$target_dir/configure.sh"
    
    log_success "All files downloaded successfully"
}

configure_deploy_yml() {
    local target_dir="$1"
    local deploy_yml="$target_dir/deploy.yml"
    
    log_info "Configuring deploy.yml..."
    
    # Try to detect project name from directory
    local project_name=$(basename "$target_dir")
    local domain_suggestion="${project_name}.com"
    
    # Check if running in non-interactive mode (e.g., via curl | bash)
    if [[ ! -t 0 ]]; then
        log_warning "Non-interactive mode detected. Using default values."
        log_info "You can edit deploy.yml manually after installation."
        
        # Use default values
        local domain="$domain_suggestion"
        local server_host="your-server.com"
        local ssl_email="admin@$domain"
        local db_name="${project_name}_prod"
        local db_user="${project_name}_user"
    else
        # Interactive configuration
        echo ""
        echo "Let's configure your deployment settings:"
        echo ""
        
        read -p "Project name [$project_name]: " input_project_name < /dev/tty
        project_name=${input_project_name:-$project_name}
        
        read -p "Primary domain [$domain_suggestion]: " input_domain < /dev/tty
        domain=${input_domain:-$domain_suggestion}
        
        read -p "Server hostname (e.g., your-server.com): " server_host < /dev/tty
        while [ -z "$server_host" ]; do
            read -p "Server hostname is required: " server_host < /dev/tty
        done
        
        read -p "SSL email address (e.g., admin@$domain): " ssl_email < /dev/tty
        while [ -z "$ssl_email" ]; do
            read -p "SSL email is required: " ssl_email < /dev/tty
        done
        
        read -p "Database name [${project_name}_prod]: " db_name < /dev/tty
        db_name=${db_name:-${project_name}_prod}
        
        read -p "Database user [${project_name}_user]: " db_user < /dev/tty
        db_user=${db_user:-${project_name}_user}
    fi
    
    echo ""
    log_info "Generating secure passwords..."
    
    # Generate secure passwords
    local db_password=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
    local db_root_password=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
    local redis_password=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
    
    # Update deploy.yml with user input using safe replacements
    cp "$deploy_yml" "$deploy_yml.bak"
    
    # Replace each line individually to avoid regex issues
    awk -v project="$project_name" -v host="$server_host" -v domain="$domain" \
        -v email="$ssl_email" -v db_name="$db_name" -v db_user="$db_user" \
        -v db_pass="$db_password" -v root_pass="$db_root_password" -v redis_pass="$redis_password" '
        /name: "My Laravel App"/ { gsub(/My Laravel App/, project) }
        /host: "your-server.example.com"/ { gsub(/your-server.example.com/, host) }
        /primary: "myapp.com"/ { gsub(/myapp.com/, domain) }
        /email: "admin@myapp.com"/ { gsub(/admin@myapp.com/, email) }
        /name: "myapp_prod"/ { gsub(/myapp_prod/, db_name) }
        /user: "myapp_user"/ { gsub(/myapp_user/, db_user) }
        /password: "secure_random_password_here"/ { gsub(/secure_random_password_here/, db_pass) }
        /root_password: "secure_root_password"/ { gsub(/secure_root_password/, root_pass) }
        /password: "secure_redis_password"/ { gsub(/secure_redis_password/, redis_pass) }
        { print }
    ' "$deploy_yml.bak" > "$deploy_yml"
    
    # Remove backup file
    rm -f "$deploy_yml.bak"
    
    log_success "deploy.yml configured successfully"
}

create_env_example() {
    local target_dir="$1"
    local env_example="$target_dir/.env.example"
    
    if [ -f "$env_example" ]; then
        log_info "Adding Docker-specific environment variables to .env.example..."
        
        # Check if Docker variables already exist
        if ! grep -q "DOCKER_APP_PORT" "$env_example"; then
            cat >> "$env_example" << 'EOF'

# Docker Configuration
DOCKER_APP_PORT=8000
DOCKER_DB_PORT=3306
DOCKER_REDIS_PORT=6379
EOF
            log_success "Docker environment variables added to .env.example"
        fi
    fi
}

create_or_update_env() {
    local target_dir="$1"
    local env_file="$target_dir/.env"
    local domain="$2"
    local db_name="$3"
    local db_user="$4"
    local db_password="$5"
    
    log_info "Creating/updating .env file for Docker configuration..."
    
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
    
    # Update or add specific Docker-related variables in organized sections
    organize_env_file "$env_file" "$db_name" "$db_user" "$db_password"
    
    # Update APP_URL if it exists
    if grep -q "^APP_URL=" "$env_file"; then
        update_env_variable "$env_file" "APP_URL" "http://localhost:8000"
    fi
    
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

organize_env_file() {
    local env_file="$1"
    local db_name="$2"
    local db_user="$3"
    local db_password="$4"
    
    # Simple approach: just update the variables in place
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
}

update_env_variable() {
    local env_file="$1"
    local var_name="$2"
    local var_value="$3"
    
    if grep -q "^${var_name}=" "$env_file"; then
        # Variable exists, replace it by removing old and adding new
        grep -v "^${var_name}=" "$env_file" > "$env_file.tmp"
        echo "${var_name}=${var_value}" >> "$env_file.tmp"
        mv "$env_file.tmp" "$env_file"
    else
        # Variable doesn't exist, add it
        echo "${var_name}=${var_value}" >> "$env_file"
    fi
}

show_next_steps() {
    local target_dir="$1"
    
    echo ""
    log_success "Installation completed successfully!"
    echo ""
    echo "Next steps:"
    echo "1. Review and customize deploy.yml with your specific settings"
    echo "2. Check the updated .env file (Docker-relevant variables updated)"
    echo "3. Add your SSH public key to your server: /home/deploy/.ssh/authorized_keys"
    echo "4. For development, run: ./docker.sh up"
    echo "5. For deployment, run: ./deploy.sh"
    echo ""
    echo "Files installed in: $target_dir"
    echo "- Dockerfile"
    echo "- docker-compose.yml"
    echo "- docker-compose.prod.yml"
    echo "- docker.sh"
    echo "- deploy.sh"
    echo "- deploy.yml (configured)"
    echo "- .env (configured for Docker)"
    echo "- configure.sh"
    echo "- docker/ (directory with configurations)"
    echo ""
    echo "Documentation: https://github.com/${GITHUB_REPO}"
    echo ""
    
    # Show configuration note if using defaults
    if [[ ! -t 0 ]]; then
        log_info "⚠️  Non-interactive installation completed with default values"
        log_info "🔧 Please edit deploy.yml to configure your specific settings:"
        log_info "   - Server hostname"
        log_info "   - Domain name"
        log_info "   - SSL email address"
        log_info "   - Database credentials"
        echo ""
        log_info "💡 For interactive configuration, run the downloaded script:"
        log_info "   ./configure.sh"
    fi
}

main() {
    local target_dir="$PWD"
    
    # Handle help
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        show_usage
        exit 0
    fi
    
    log_info "Laravel Docker Deployment System - Installer"
    log_info "Repository: https://github.com/${GITHUB_REPO}"
    log_info "Target: $target_dir"
    
    # Checks
    check_dependencies
    check_target_directory "$target_dir"
    backup_existing_files "$target_dir"
    
    # Installation
    download_files "$target_dir"
    configure_deploy_yml "$target_dir"
    create_env_example "$target_dir"
    
    # Configure .env file with Docker settings
    if [ "$force_update" != "true" ]; then
        # Use the same variables from deploy.yml configuration
        local project_name=$(basename "$target_dir")
        local domain_suggestion="${project_name}.com"
        local db_name="${project_name}_prod"
        local db_user="${project_name}_user"
        local db_password=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
        
        # Use configured values if available
        if [ -n "$domain" ]; then
            domain_suggestion="$domain"
        fi
        if [ -n "$db_name" ]; then
            db_name="$db_name"
        fi
        if [ -n "$db_user" ]; then
            db_user="$db_user"
        fi
        
        create_or_update_env "$target_dir" "$domain_suggestion" "$db_name" "$db_user" "$db_password"
    fi
    
    # Done
    show_next_steps "$target_dir"
}

main "$@"