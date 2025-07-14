# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a complete Laravel Docker deployment system providing production-ready infrastructure for Laravel applications with zero-downtime deployment strategies.

## Architecture

The system consists of three main components:

1. **Docker Infrastructure** (`Dockerfile`, `docker-compose.yml`, `docker-compose.prod.yml`)
   - Laravel application container with PHP 8.3 + Nginx
   - MySQL 8.0 database container
   - Redis cache/session container
   - Separate scheduler and queue worker containers

2. **Management Scripts**
   - `docker.sh` - Complete Docker operations management
   - `provision.sh` - Server provisioning for Ubuntu 24.04
   - `deploy.sh` - Zero-downtime deployment with Blue-Green strategy

3. **Configuration System**
   - `deploy.yml` - Per-project configuration file
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
├── deploy.yml                   # Per-project configuration template
├── install.sh                   # GitHub installation script
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
- **Monitoring**: Health checks, system monitoring, deployment notifications
- **Backup System**: Automated database backups with retention

## Integration with Existing Laravel Projects

### Automatic Installation (Recommended)
```bash
# From Laravel project root directory
curl -fsSL https://raw.githubusercontent.com/ben182/laravel-deploy/main/install.sh | bash
```

### Manual Installation
```bash
cp Dockerfile /path/to/laravel/project/
cp docker-compose.yml /path/to/laravel/project/
cp docker-compose.prod.yml /path/to/laravel/project/
cp -r docker/ /path/to/laravel/project/
cp deploy.yml /path/to/laravel/project/
```

### Deploy
```bash
# From Laravel project root directory
./deploy.sh
```

## Notes

- All scripts are production-ready with comprehensive error handling
- Per-project configuration system for maximum flexibility
- **Simplified usage**: Run scripts from project root directory, no path parameters needed
- **provision.sh**: Creates 'deploy' user automatically, SSH keys must be added manually
- **deploy.sh**: Runs from Laravel project root, looks for deploy.yml in current directory
- Automatic port assignment for multi-project hosting on single server
- SSH key management with separate deploy keys support
- Always-on HTTPS with automatic SSL certificate management
- Supports modern security best practices
- Optimized for Hetzner Ubuntu 24.04 servers
- Uses serversideup/php:8.4-fpm-nginx Docker images with Laravel-specific optimizations
- Comprehensive logging and monitoring capabilities