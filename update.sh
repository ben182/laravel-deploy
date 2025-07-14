#!/bin/bash

# Laravel Docker Deployment System - Update Script
# Usage: curl -fsSL https://raw.githubusercontent.com/ben182/laravel-deploy/main/update.sh | bash
# Or: ./update.sh

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
    echo "Laravel Docker Deployment System - Update Script"
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "This script will update the following files in the current directory:"
    echo "  - Dockerfile"
    echo "  - docker-compose.yml"
    echo "  - docker-compose.prod.yml"
    echo "  - docker.sh"
    echo "  - deploy.sh"
    echo "  - provision.sh"
    echo "  - configure.sh"
    echo "  - docker/ directory configurations"
    echo ""
    echo "Options:"
    echo "  --skip-backup   Skip backup creation"
    echo "  --force         Force update without confirmation"
    echo "  -h, --help      Show this help message"
    echo ""
    echo "Run this script from your Laravel project root directory."
    echo ""
    echo "One-liner update:"
    echo "  curl -fsSL ${GITHUB_RAW_URL}/update.sh | bash"
}

check_dependencies() {
    local missing_deps=()
    
    command -v curl >/dev/null 2>&1 || missing_deps+=("curl")
    command -v sed >/dev/null 2>&1 || missing_deps+=("sed")
    
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
    
    # Check if it looks like a Laravel project with deployment files
    if [ ! -f "$target_dir/deploy.yml" ] && [ ! -f "$target_dir/docker.sh" ]; then
        log_warning "Directory doesn't appear to have Laravel deployment files"
        
        # Check if running in non-interactive mode
        if [[ ! -t 0 ]]; then
            log_info "Non-interactive mode: Continuing anyway"
        else
            read -p "Continue anyway? (y/N): " -n 1 -r < /dev/tty
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log_info "Update cancelled"
                exit 0
            fi
        fi
    fi
}

backup_existing_files() {
    local target_dir="$1"
    local skip_backup="$2"
    
    if [ "$skip_backup" = "true" ]; then
        log_info "Skipping backup as requested"
        return 0
    fi
    
    local backup_dir="$target_dir/.deployment-backup-$(date +%Y%m%d_%H%M%S)"
    local files_to_backup=()
    
    # Check which files exist to backup
    local files_to_check=(
        "Dockerfile"
        "docker-compose.yml"
        "docker-compose.prod.yml"
        "docker.sh"
        "deploy.sh"
        "provision.sh"
        "configure.sh"
        "docker/"
    )
    
    for file in "${files_to_check[@]}"; do
        if [ -e "$target_dir/$file" ]; then
            files_to_backup+=("$file")
        fi
    done
    
    if [ ${#files_to_backup[@]} -gt 0 ]; then
        log_info "Creating backup of existing files..."
        
        # Create backup
        mkdir -p "$backup_dir"
        for file in "${files_to_backup[@]}"; do
            cp -r "$target_dir/$file" "$backup_dir/" 2>/dev/null || true
        done
        
        log_success "Backup created in: $backup_dir"
    else
        log_info "No existing files to backup"
    fi
}

download_file() {
    local url="$1"
    local target_path="$2"
    
    log_info "Updating: $(basename "$target_path")"
    
    if ! curl -fsSL "$url" -o "$target_path"; then
        log_error "Failed to download: $url"
        exit 1
    fi
}

update_files() {
    local target_dir="$1"
    
    log_info "Updating files from GitHub..."
    
    # Update main files
    local files_to_update=(
        "Dockerfile"
        "docker-compose.yml"
        "docker-compose.prod.yml"
        "docker.sh"
        "deploy.sh"
        "provision.sh"
        "configure.sh"
    )
    
    for file in "${files_to_update[@]}"; do
        download_file "${GITHUB_RAW_URL}/$file" "$target_dir/$file"
    done
    
    # Update docker directory files
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
    chmod +x "$target_dir/provision.sh"
    chmod +x "$target_dir/configure.sh"
    
    log_success "All files updated successfully"
}

preserve_deploy_yml() {
    local target_dir="$1"
    local deploy_yml="$target_dir/deploy.yml"
    
    if [ -f "$deploy_yml" ]; then
        log_info "Preserving existing deploy.yml configuration"
        log_info "deploy.yml was NOT updated to preserve your settings"
    else
        log_info "No existing deploy.yml found"
        log_info "You may want to run the installer to create one: ./install.sh"
    fi
}

show_whats_new() {
    echo ""
    log_info "🆕 What's new in this update:"
    echo "   - Latest Docker configurations"
    echo "   - Updated deployment scripts"
    echo "   - Bug fixes and improvements"
    echo "   - Enhanced security features"
    echo ""
    log_info "📋 Files updated:"
    echo "   - Dockerfile"
    echo "   - docker-compose.yml"
    echo "   - docker-compose.prod.yml"
    echo "   - docker.sh"
    echo "   - deploy.sh"
    echo "   - provision.sh"
    echo "   - configure.sh"
    echo "   - docker/ directory configurations"
    echo ""
    log_info "🔒 Files preserved:"
    echo "   - deploy.yml (your project configuration)"
    echo "   - .env files"
    echo "   - Laravel application files"
}

show_next_steps() {
    local target_dir="$1"
    
    echo ""
    log_success "Update completed successfully!"
    echo ""
    echo "Next steps:"
    echo "1. Review any breaking changes in the documentation"
    echo "2. Test your application: ./docker.sh up"
    echo "3. If needed, update your deploy.yml configuration"
    echo "4. Deploy with the updated system: ./deploy.sh"
    echo ""
    echo "Documentation: https://github.com/${GITHUB_REPO}"
    echo ""
}

main() {
    local target_dir="$PWD"
    local skip_backup="false"
    local force_update="false"
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --skip-backup)
                skip_backup="true"
                shift
                ;;
            --force)
                force_update="true"
                shift
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
    
    log_info "Laravel Docker Deployment System - Update Script"
    log_info "Repository: https://github.com/${GITHUB_REPO}"
    log_info "Target: $target_dir"
    
    # Checks
    check_dependencies
    check_target_directory "$target_dir"
    
    # Confirmation
    if [ "$force_update" != "true" ]; then
        # Check if running in non-interactive mode
        if [[ ! -t 0 ]]; then
            log_info "Non-interactive mode: Proceeding with update"
        else
            echo ""
            log_warning "This will update your deployment files with the latest versions from GitHub."
            log_warning "Your deploy.yml configuration will be preserved."
            echo ""
            read -p "Continue with update? (y/N): " -n 1 -r < /dev/tty
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log_info "Update cancelled"
                exit 0
            fi
        fi
    fi
    
    # Update process
    backup_existing_files "$target_dir" "$skip_backup"
    update_files "$target_dir"
    preserve_deploy_yml "$target_dir"
    
    # Show results
    show_whats_new
    show_next_steps "$target_dir"
}

main "$@"