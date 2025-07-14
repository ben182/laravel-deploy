# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a complete Laravel Docker deployment system providing production-ready infrastructure for Laravel applications with zero-downtime deployment strategies.

## Architecture

The system consists of three main components:

1. **Docker Infrastructure** (`Dockerfile`, `docker-compose.yml`, `docker-compose.prod.yml`)
   - Laravel application container with PHP 8.4 + Nginx
   - MySQL 8.0 database container (defaults: name=laravel, user=laravel)
   - Redis cache/session container
   - Separate scheduler and queue worker containers
   - **Dynamic container names** based on APP_NAME for multi-project support

2. **Management Scripts**
   - `install.sh` - Interactive installation script with automatic container naming
   - `docker.sh` - Complete Docker operations management
   - `provision.sh` - Server provisioning for Ubuntu 24.04
   - `deploy.sh` - Zero-downtime deployment with Blue-Green strategy

3. **Configuration System**
   - `deploy-config.yml` - Configuration template
   - `deploy.yml` - Per-project configuration file (generated from template)
   - `server/port-manager.sh` - Automatic port assignment for multi-project hosting
   - `templates/` - Nginx and Docker Compose templates

## Common Commands

### Development (Local)
```bash
./docker.sh build          # Build Docker images
./docker.sh up             # Start development containers
./docker.sh down           # Stop containers
./docker.sh logs           # View logs
./docker.sh shell          # Open shell in app container
./docker.sh artisan [cmd]  # Run Laravel Artisan commands
./docker.sh composer [cmd] # Run Composer commands
./docker.sh migrate        # Run database migrations
./docker.sh test           # Run PHPUnit tests
./docker.sh backup         # Create database backup
```

### Server Provisioning
```bash
./provision.sh                      # Provision Ubuntu 24.04 server (creates 'deploy' user)
```

### Production Deployment
```bash
# Run from Laravel project root directory
./deploy.sh                         # Deploy project
./deploy.sh --rollback             # Rollback deployment
./deploy.sh --config custom.yml    # Use custom config file
```

## Project Structure

```
/
├── Dockerfile                    # Laravel app container
├── docker-compose.yml           # Development environment
├── docker-compose.prod.yml      # Production environment
├── docker.sh                    # Docker management script
├── provision.sh                 # Server provisioning script
├── deploy.sh                    # Deployment script
├── deploy-config.yml            # Configuration template
├── deploy.yml                   # Per-project configuration (generated)
├── install.sh                   # Interactive installation script
├── server/
│   └── port-manager.sh          # Automatic port assignment for server
├── templates/
│   ├── nginx-site.conf          # Nginx configuration template
│   ├── docker-compose.template.yml
│   └── env.production.template
└── docker/
    ├── nginx/default.conf       # Nginx configuration
    ├── supervisor/supervisord.conf
    ├── php/local.ini
    └── mysql/
        ├── init.sql
        └── my.cnf
```

## Key Features

- **Zero-Downtime Deployment**: Blue-Green, Rolling, and Recreate strategies
- **Multi-Project Support**: Deploy multiple Laravel apps on one server with automatic port assignment
- **Per-Project Configuration**: Each project has its own deploy.yml configuration file
- **SSH Key Management**: Configurable SSH keys per project for secure deployment
- **Automatic SSL**: Always-on HTTPS with Certbot integration and auto-renewal
- **Security Hardening**: SSH hardening, UFW firewall, Fail2ban, HTTPS-only
- **Performance Optimization**: OPcache, Redis caching, Nginx optimization
- **Dynamic Container Names**: Automatic container naming based on APP_NAME to prevent conflicts
- **Backup System**: Automated database backups with retention
- **Interactive Installation**: User-friendly installation with automatic configuration

## Integration with Existing Laravel Projects

### Interactive Installation (Recommended)
```bash
# From Laravel project root directory
curl -fsSL https://raw.githubusercontent.com/ben182/laravel-deploy/main/install.sh -o install.sh && chmod +x install.sh && ./install.sh
```

### Manual Installation
```bash
cp Dockerfile /path/to/laravel/project/
cp docker-compose.yml /path/to/laravel/project/
cp docker-compose.prod.yml /path/to/laravel/project/
cp -r docker/ /path/to/laravel/project/
cp deploy-config.yml /path/to/laravel/project/deploy.yml
```

### Deploy
```bash
# From Laravel project root directory
./deploy.sh
```

## Notes

- All scripts are production-ready with comprehensive error handling
- Per-project configuration system for maximum flexibility
- **Interactive Installation**: User-friendly setup with automatic configuration
- **Dynamic Container Names**: Automatic naming based on APP_NAME to prevent conflicts
- **Database Defaults**: Uses laravel/laravel for database name/user (internal Docker)
- **APP_KEY Management**: Automatically generated on server, shared across deployments
- **Simplified usage**: Run scripts from project root directory, no path parameters needed
- **provision.sh**: Creates 'deploy' user automatically, SSH keys must be added manually
- **deploy.sh**: Runs from Laravel project root, looks for deploy.yml in current directory
- Automatic port assignment for multi-project hosting on single server
- SSH key management with separate deploy keys support
- Always-on HTTPS with automatic SSL certificate management
- Supports modern security best practices
- Optimized for Hetzner Ubuntu 24.04 servers
- Uses serversideup/php:8.4-fpm-nginx Docker images with Laravel-specific optimizations

## Documentation Update Requirements

**IMPORTANT**: After making ANY changes to the codebase, configuration files, or features, you MUST update both:

1. **CLAUDE.md** - Update architecture, features, commands, and notes sections to reflect changes
2. **README.md** - Update installation instructions, configuration examples, and feature descriptions

This ensures documentation stays synchronized with code changes and provides accurate information for users and future development.