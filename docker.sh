#!/bin/bash

# Laravel Docker Management Script
# Usage: ./docker.sh [command] [options]
# Run this script from your Laravel project root directory

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
COMPOSE_FILE="docker-compose.yml"
COMPOSE_PROD_FILE="docker-compose.prod.yml"
APP_CONTAINER="laravel-app"

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

check_docker() {
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed or not in PATH"
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        log_error "Docker Compose is not installed or not in PATH"
        exit 1
    fi
}

show_usage() {
    echo "Laravel Docker Management Script"
    echo ""
    echo "Usage: $0 [command] [options]"
    echo ""
    echo "Commands:"
    echo "  build         Build Docker images"
    echo "  up            Start containers (development mode)"
    echo "  prod          Start containers (production mode)"
    echo "  down          Stop and remove containers"
    echo "  restart       Restart containers"
    echo "  logs          Show container logs"
    echo "  exec          Execute command in app container"
    echo "  shell         Open shell in app container"
    echo "  mysql         Connect to MySQL database"
    echo "  redis         Connect to Redis"
    echo "  artisan       Run Laravel Artisan commands"
    echo "  composer      Run Composer commands"
    echo "  npm           Run NPM commands"
    echo "  test          Run PHPUnit tests"
    echo "  migrate       Run database migrations"
    echo "  seed          Run database seeders"
    echo "  optimize      Optimize Laravel application"
    echo "  backup        Create database backup"
    echo "  restore       Restore database backup"
    echo "  status        Show container status"
    echo "  clean         Clean up unused Docker resources"
    echo "  reset         Reset everything (rebuild containers)"
    echo "  horizon       Start Laravel Horizon (production only)"
    echo "  horizon-stop  Stop Laravel Horizon"
    echo ""
    echo "Options:"
    echo "  -f, --follow  Follow log output"
    echo "  -d, --detach  Run in background"
    echo "  -h, --help    Show this help message"
}

# Docker operations
docker_build() {
    log_info "Building Docker images..."
    docker-compose -f $COMPOSE_FILE build
    log_success "Docker images built successfully"
}

docker_up() {
    log_info "Starting containers in development mode..."
    docker-compose -f $COMPOSE_FILE up -d
    log_success "Containers started successfully"
    show_status
    
    # Show browser access information
    echo ""
    log_info "🌐 Your application is now running at:"
    echo -e "${GREEN}   → http://localhost:8000${NC}"
    echo ""
    echo "Other services:"
    echo -e "${BLUE}   → MySQL:${NC} localhost:3306"
    echo -e "${BLUE}   → Redis:${NC} localhost:6379"
    echo ""
}

docker_prod() {
    log_info "Starting containers in production mode..."
    if [ ! -f ".env.production" ]; then
        log_error "Production environment file (.env.production) not found"
        exit 1
    fi
    docker-compose -f $COMPOSE_PROD_FILE up -d
    log_success "Production containers started successfully"
    show_status
}

docker_down() {
    log_info "Stopping and removing containers..."
    docker-compose -f $COMPOSE_FILE down
    docker-compose -f $COMPOSE_PROD_FILE down 2>/dev/null || true
    log_success "Containers stopped successfully"
}

docker_restart() {
    log_info "Restarting containers..."
    docker-compose -f $COMPOSE_FILE restart
    log_success "Containers restarted successfully"
}

show_logs() {
    local follow_flag=""
    if [ "$1" = "-f" ] || [ "$1" = "--follow" ]; then
        follow_flag="-f"
    fi
    
    if [ -n "$2" ]; then
        docker-compose -f $COMPOSE_FILE logs $follow_flag "$2"
    else
        docker-compose -f $COMPOSE_FILE logs $follow_flag
    fi
}

docker_exec() {
    if [ -z "$1" ]; then
        log_error "Command is required"
        exit 1
    fi
    
    docker-compose -f $COMPOSE_FILE exec $APP_CONTAINER "$@"
}

docker_shell() {
    log_info "Opening shell in app container..."
    docker-compose -f $COMPOSE_FILE exec $APP_CONTAINER /bin/bash
}

mysql_connect() {
    log_info "Connecting to MySQL database..."
    docker-compose -f $COMPOSE_FILE exec mysql mysql -u laravel -psecret laravel
}

redis_connect() {
    log_info "Connecting to Redis..."
    docker-compose -f $COMPOSE_FILE exec redis redis-cli
}

run_artisan() {
    if [ -z "$1" ]; then
        log_error "Artisan command is required"
        exit 1
    fi
    
    log_info "Running: php artisan $*"
    docker-compose -f $COMPOSE_FILE exec $APP_CONTAINER php artisan "$@"
}

run_composer() {
    if [ -z "$1" ]; then
        log_error "Composer command is required"
        exit 1
    fi
    
    log_info "Running: composer $*"
    docker-compose -f $COMPOSE_FILE exec $APP_CONTAINER composer "$@"
}

run_npm() {
    if [ -z "$1" ]; then
        log_error "NPM command is required"
        exit 1
    fi
    
    log_info "Running: npm $*"
    docker-compose -f $COMPOSE_FILE exec $APP_CONTAINER npm "$@"
}

run_tests() {
    log_info "Running PHPUnit tests..."
    docker-compose -f $COMPOSE_FILE exec $APP_CONTAINER php artisan test
}

run_migrate() {
    log_info "Running database migrations..."
    docker-compose -f $COMPOSE_FILE exec $APP_CONTAINER php artisan migrate --force
    log_success "Migrations completed successfully"
}

run_seed() {
    log_info "Running database seeders..."
    docker-compose -f $COMPOSE_FILE exec $APP_CONTAINER php artisan db:seed --force
    log_success "Seeders completed successfully"
}

optimize_app() {
    log_info "Optimizing Laravel application..."
    docker-compose -f $COMPOSE_FILE exec $APP_CONTAINER php artisan config:cache
    docker-compose -f $COMPOSE_FILE exec $APP_CONTAINER php artisan route:cache
    docker-compose -f $COMPOSE_FILE exec $APP_CONTAINER php artisan view:cache
    docker-compose -f $COMPOSE_FILE exec $APP_CONTAINER php artisan event:cache
    log_success "Application optimized successfully"
}

backup_database() {
    local backup_file="backup_$(date +%Y%m%d_%H%M%S).sql"
    log_info "Creating database backup: $backup_file"
    
    mkdir -p backups
    docker-compose -f $COMPOSE_FILE exec mysql mysqldump -u laravel -psecret laravel > "backups/$backup_file"
    log_success "Database backup created: backups/$backup_file"
}

restore_database() {
    if [ -z "$1" ]; then
        log_error "Backup file is required"
        exit 1
    fi
    
    if [ ! -f "$1" ]; then
        log_error "Backup file not found: $1"
        exit 1
    fi
    
    log_info "Restoring database from: $1"
    docker-compose -f $COMPOSE_FILE exec -T mysql mysql -u laravel -psecret laravel < "$1"
    log_success "Database restored successfully"
}

show_status() {
    log_info "Container status:"
    docker-compose -f $COMPOSE_FILE ps
}

clean_docker() {
    log_info "Cleaning up unused Docker resources..."
    docker system prune -f
    docker volume prune -f
    log_success "Docker cleanup completed"
}

reset_everything() {
    log_warning "This will destroy all containers, volumes, and rebuild everything"
    read -p "Are you sure? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "Resetting everything..."
        docker_down
        docker-compose -f $COMPOSE_FILE down -v
        docker-compose -f $COMPOSE_PROD_FILE down -v 2>/dev/null || true
        docker_build
        docker_up
        log_success "Reset completed successfully"
    else
        log_info "Reset cancelled"
    fi
}

start_horizon() {
    log_info "Starting Laravel Horizon..."
    docker-compose -f $COMPOSE_PROD_FILE --profile horizon up -d horizon
    log_success "Laravel Horizon started successfully"
    show_status
}

stop_horizon() {
    log_info "Stopping Laravel Horizon..."
    docker-compose -f $COMPOSE_PROD_FILE stop horizon
    docker-compose -f $COMPOSE_PROD_FILE rm -f horizon
    log_success "Laravel Horizon stopped successfully"
}

# Main script logic
main() {
    check_docker
    
    case "$1" in
        "build")
            docker_build
            ;;
        "up")
            docker_up
            ;;
        "prod")
            docker_prod
            ;;
        "down")
            docker_down
            ;;
        "restart")
            docker_restart
            ;;
        "logs")
            shift
            show_logs "$@"
            ;;
        "exec")
            shift
            docker_exec "$@"
            ;;
        "shell")
            docker_shell
            ;;
        "mysql")
            mysql_connect
            ;;
        "redis")
            redis_connect
            ;;
        "artisan")
            shift
            run_artisan "$@"
            ;;
        "composer")
            shift
            run_composer "$@"
            ;;
        "npm")
            shift
            run_npm "$@"
            ;;
        "test")
            run_tests
            ;;
        "migrate")
            run_migrate
            ;;
        "seed")
            run_seed
            ;;
        "optimize")
            optimize_app
            ;;
        "backup")
            backup_database
            ;;
        "restore")
            shift
            restore_database "$@"
            ;;
        "status")
            show_status
            ;;
        "clean")
            clean_docker
            ;;
        "reset")
            reset_everything
            ;;
        "horizon")
            start_horizon
            ;;
        "horizon-stop")
            stop_horizon
            ;;
        "-h"|"--help"|"help"|"")
            show_usage
            ;;
        *)
            log_error "Unknown command: $1"
            show_usage
            exit 1
            ;;
    esac
}

main "$@"