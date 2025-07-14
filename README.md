# Laravel Docker Deployment System

Ein vollständiges Docker-basiertes Deployment-System für Laravel-Anwendungen mit Zero-Downtime-Strategien und automatisiertem Server-Provisioning.

## Übersicht

Dieses System bietet:

- **Docker-Setup**: Optimierte Container für Laravel, MySQL, Redis
- **Management-Skripte**: Einfache Verwaltung aller Docker-Operationen
- **Server-Provisioning**: Automatische Einrichtung von Hetzner Ubuntu 24.04 Servern
- **Zero-Downtime-Deployment**: Blue-Green und Rolling-Deployment-Strategien
- **Multi-Project-Support**: Mehrere Projekte auf einem Server

## Schnellstart

### 1. Server bereitstellen

```bash
# Auf dem Zielserver als root ausführen
./provision.sh
```

### 2. Laravel-Projekt vorbereiten

**Automatische Installation (empfohlen)**
```bash
# Im Laravel-Projekt-Verzeichnis
curl -fsSL https://raw.githubusercontent.com/ben182/laravel-deploy/main/install.sh | bash
```

**Interaktive Installation**
```bash
# Für interaktive Konfiguration
wget https://raw.githubusercontent.com/ben182/laravel-deploy/main/install.sh
chmod +x install.sh
./install.sh
```

**System-Update**
```bash
# Deployment-System auf die neueste Version aktualisieren
curl -fsSL https://raw.githubusercontent.com/ben182/laravel-deploy/main/update.sh | bash
```

**Manuelle Installation**
```bash
# Diese Dateien in Ihr Laravel-Projekt kopieren
cp Dockerfile /path/to/your/laravel/project/
cp docker-compose.yml /path/to/your/laravel/project/
cp docker-compose.prod.yml /path/to/your/laravel/project/
cp -r docker/ /path/to/your/laravel/project/
cp deploy.yml /path/to/your/laravel/project/
```

### 3. Projekt konfigurieren

```bash
# One-liner Installation verwendet Standard-Werte
# Für interaktive Konfiguration nach der Installation:
./configure.sh

# Oder deploy.yml manuell bearbeiten
# Server-Details, Domain, SSH-Keys, Datenbank-Credentials konfigurieren
```

**Die Installation erstellt automatisch:**
- ✅ `deploy.yml` - Konfiguriert mit Ihren Projekt-Details
- ✅ `.env` - Intelligente Aktualisierung nur Docker-relevanter Variablen
- ✅ Docker-Konfigurationsdateien
- ✅ Management-Skripte

**Intelligente .env-Aktualisierung:**
- Bestehende .env wird automatisch gesichert
- Nur Docker-relevante Variablen werden aktualisiert
- Ihre bestehenden Einstellungen bleiben erhalten
- Fehlende APP_KEY wird automatisch generiert

### 4. Development

```bash
# In Ihrem Laravel-Projekt
./docker.sh build
./docker.sh up

# Die .env-Datei ist bereits konfiguriert für:
# - MySQL-Datenbank (Host: mysql, Port: 3306)
# - Redis-Cache (Host: redis, Port: 6379)
# - APP_URL: http://localhost:8000
```

### 5. Deployment

```bash
# Im Laravel-Projekt-Verzeichnis
./deploy.sh
```

## Komponenten

### Docker Setup

#### Dockerfile
- **Basiert auf serversideup/php:8.4-fpm-nginx** - Produktionsbereite PHP-Images
- **Laravel-optimiert** - Speziell für Laravel-Anwendungen entwickelt
- **Native Health Checks** - Eingebaute Gesundheitsprüfungen
- **S6 Overlay** - Intelligentes Init-System für Multi-Process-Management
- **NGINX Unit Support** - Moderne PHP-Ausführung ohne FPM
- **Unified Logging** - Vereinheitlichte Logs (STDOUT & STDERR)
- **CloudFlare Support** - Korrekte IP-Adressen über Trusted Proxies
- **High Performance** - Optimiert für hohe Anfragezahlen
- **Produktionsbereite Konfiguration** - Sicher und performant

#### docker-compose.yml (Development)
- Hot-Reload für lokale Entwicklung
- Volumes für Code-Sync
- Debug-freundliche Konfiguration

#### docker-compose.prod.yml (Production)
- Optimiert für Produktionsumgebung
- Sicherheitsoptimierungen
- Resource-Limits
- Health-Checks

### Management-Skripte

#### ./docker.sh
Vollständiges Docker-Management:

```bash
./docker.sh build          # Images erstellen
./docker.sh up             # Container starten
./docker.sh down           # Container stoppen
./docker.sh logs           # Logs anzeigen
./docker.sh shell          # Shell öffnen
./docker.sh artisan        # Artisan-Befehle
./docker.sh composer       # Composer-Befehle
./docker.sh migrate        # Migrationen ausführen
./docker.sh test           # Tests ausführen
./docker.sh backup         # Datenbank-Backup
./docker.sh clean          # Docker-Cleanup
./docker.sh horizon        # Laravel Horizon starten (Produktion)
./docker.sh horizon-stop   # Laravel Horizon stoppen
```

#### ./provision.sh
Server-Provisioning für Ubuntu 24.04:

```bash
./provision.sh
```

**Features:**
- Docker-Installation
- Nginx-Setup als Reverse Proxy
- UFW-Firewall-Konfiguration
- Fail2ban-Sicherheit
- SSH-Härtung (SSH-Keys müssen manuell hinzugefügt werden)
- Automatische Updates
- Swap-Konfiguration
- Performance-Optimierungen
- Certbot für SSL-Zertifikate
- Erstellt 'deploy' Benutzer für Deployments

#### ./deploy.sh
Zero-Downtime-Deployment:

```bash
./deploy.sh [options]
```

**Optionen:**
- `--branch`: Spezifischen Branch deployen
- `--skip-backup`: Backup überspringen
- `--skip-build`: Build überspringen
- `--rollback`: Rollback zum vorherigen Release
- `--config`: Pfad zur Konfigurationsdatei (default: deploy.yml)
- `--force`: Deployment erzwingen

**Strategien:**
- **Blue-Green**: Neuer Stack parallel, dann Switch
- **Rolling**: Schrittweise Container-Updates
- **Recreate**: Kompletter Neustart

### Konfiguration

#### deploy.yml (pro Projekt)
Jedes Laravel-Projekt hat eine eigene Konfigurationsdatei:

```yaml
# Project Information
project:
  name: "My Laravel App"
  description: "Description of your Laravel application"
  
# Server Configuration
server:
  host: "your-server.example.com"
  user: "deploy"
  port: 22
  ssh_key: "~/.ssh/id_rsa"
  
# Domain Configuration
domain:
  primary: "myapp.com"
  aliases: 
    - "www.myapp.com"
  ssl:
    email: "admin@myapp.com"
    force_https: true  # Immer aktiviert

# Git Configuration
git:
  repository: "git@github.com:user/my-laravel-app.git"
  branch: "main"
  deploy_key: "~/.ssh/deploy_key"  # Optional

# Database Configuration
database:
  name: "myapp_prod"
  user: "myapp_user"
  password: "secure_random_password_here"
  
# Deployment Configuration
deployment:
  strategy: "blue-green"
  backup:
    before_deploy: true
  migrations:
    run: true
```

### Nginx-Konfiguration

Das System konfiguriert automatisch:
- **SSL-Zertifikate** via Certbot (immer aktiviert)
- **HTTP zu HTTPS Redirect** (kein unverschlüsselter Traffic)
- **Reverse Proxy** zu Docker-Containern mit automatischer Port-Zuweisung
- **Sicherheits-Headers** (HSTS, CSP, XSS Protection)
- **Rate-Limiting** gegen DoS-Angriffe
- **Gzip-Kompression** für bessere Performance
- **Static-File-Caching** für Assets

### Sicherheit

#### Server-Härtung
- SSH-Schlüssel-Authentifizierung
- Deaktivierter Root-Login
- UFW-Firewall (nur 80, 443, SSH)
- Fail2ban gegen Brute-Force-Angriffe
- Automatische Sicherheitsupdates

#### Container-Sicherheit
- Non-root User in Containern
- Minimale Base-Images
- Sichere Standard-Konfiguration
- Keine Secrets in Images

### Performance-Optimierungen

#### System-Level
- Optimierte Kernel-Parameter
- BBR TCP Congestion Control
- Erhöhte File-Limits
- Swap-Konfiguration

#### Laravel-Optimierungen
- OPcache aktiviert
- Config/Route/View-Caching
- Redis für Session/Cache
- Optimierte Composer-Autoloader

#### serversideup/php Features
- **Native Health Checks** - Kontinuierliche Überwachung der Anwendungsgesundheit
- **S6 Overlay** - Intelligentes Process-Management ohne traditionelle Init-Probleme
- **NGINX Unit** - Moderne PHP-Ausführung mit besserer Performance als FPM
- **Unified Logging** - Vereinheitlichte Log-Ausgabe für besseres Monitoring
- **CloudFlare Integration** - Korrekte Client-IP-Erkennung bei Proxy-Nutzung
- **High Performance Defaults** - Optimiert für hohe Anfragezahlen und Durchsatz

#### Nginx-Optimierungen
- Gzip-Kompression
- Static-File-Caching
- Optimierte Buffer-Größen
- HTTP/2 Support

### Monitoring & Logging

#### System-Monitoring
- Automatisches Disk-Space-Monitoring
- Memory-Usage-Überwachung
- Load-Average-Checks
- Log-Rotation

#### Application-Monitoring
- Health-Check-Endpoints
- Container-Health-Checks
- Deployment-Benachrichtigungen
- Error-Logging

### Backup & Recovery

#### Automatische Backups
- Datenbank-Backups vor Deployment
- Retention-Policy (7 Tage)
- Komprimierte Backups
- Rollback-Funktionalität

#### Disaster Recovery
- Vollständige Rollback-Unterstützung
- Backup-Wiederherstellung
- Container-Recovery
- Konfiguration-Backups

## System-Updates

### Automatisches Update

Das Deployment-System kann jederzeit auf die neueste Version aktualisiert werden:

```bash
# Im Laravel-Projekt-Verzeichnis
curl -fsSL https://raw.githubusercontent.com/ben182/laravel-deploy/main/update.sh | bash
```

**Update-Optionen:**
```bash
# Update ohne Backup
curl -fsSL https://raw.githubusercontent.com/ben182/laravel-deploy/main/update.sh | bash -s -- --skip-backup

# Update ohne Bestätigung
curl -fsSL https://raw.githubusercontent.com/ben182/laravel-deploy/main/update.sh | bash -s -- --force
```

**Was wird aktualisiert:**
- Dockerfile
- docker-compose.yml / docker-compose.prod.yml
- docker.sh, deploy.sh, provision.sh
- configure.sh
- docker/ Verzeichnis-Konfigurationen

**Was wird NICHT aktualisiert:**
- deploy.yml (Ihre Projekt-Konfiguration)
- .env Dateien
- Laravel-Anwendungsdateien

### Manuelle Updates

```bash
# Update-Skript herunterladen und ausführen
wget https://raw.githubusercontent.com/ben182/laravel-deploy/main/update.sh
chmod +x update.sh
./update.sh --help
```

## Erweiterte Nutzung

### Multi-Project-Setup

```bash
# In jedem Projekt-Verzeichnis
cd /path/to/project1 && ./deploy.sh
cd /path/to/project2 && ./deploy.sh
cd /path/to/api-service && ./deploy.sh
```

### Custom Domains

```yaml
# In jeder deploy.yml
domain:
  primary: "app.example.com"
  aliases: 
    - "www.app.example.com"
    - "app.example.org"
```

### SSL-Zertifikate

```bash
# Automatisch via Certbot - immer aktiviert
# Konfiguration in deploy.yml:
domain:
  ssl:
    email: "admin@example.com"
    force_https: true  # Immer true
```

### SSH-Key-Konfiguration

```yaml
# In deploy.yml
server:
  ssh_key: "~/.ssh/id_rsa"
  
git:
  deploy_key: "~/.ssh/deploy_key"  # Optional für Git
```

### Monitoring-Integration

```yaml
# In deploy.yml
monitoring:
  enabled: true
  webhook_url: "https://hooks.slack.com/services/..."
```

## Troubleshooting

### Logs anzeigen

```bash
./docker.sh logs -f              # Alle Container
./docker.sh logs -f app          # Nur App-Container
tail -f /home/deploy/logs/app_deploy.log  # Deployment-Logs
```

### Container-Status

```bash
./docker.sh status               # Container-Status
docker ps                        # Alle Container
docker stats                     # Resource-Nutzung
```

### Rollback

```bash
# Im Projekt-Verzeichnis
./deploy.sh --rollback    # Zum vorherigen Release
```

### Cleanup

```bash
./docker.sh clean        # Docker-Cleanup
./deploy.sh --force      # Deployment erzwingen
```

## serversideup/php Docker Image Features

Unser System nutzt die hochoptimierten `serversideup/php:8.4-fpm-nginx` Docker Images, die speziell für Laravel-Anwendungen entwickelt wurden:

### Produktions-Features
- **Native Health Checks** - Eingebaute Gesundheitsprüfungen für Container-Orchestrierung
- **S6 Overlay** - Intelligentes Init-System für zuverlässiges Multi-Process-Management
- **NGINX Unit Support** - Moderne PHP-Ausführung ohne traditionelle FPM-Probleme
- **Unified Logging** - Alle Logs gehen an STDOUT/STDERR für besseres Monitoring
- **CloudFlare Integration** - Korrekte Client-IP-Erkennung über Trusted Proxies

### Laravel-Optimierungen
- **Auto-Migrations** - Automatische Datenbankmigrationen beim Start
- **Storage Linking** - Automatisches Verknüpfen von Storage-Verzeichnissen
- **Horizon Integration** - Native Unterstützung für Laravel Horizon
- **Scheduler Support** - Eingebaute Unterstützung für Laravel Task Scheduler
- **Queue Processing** - Optimierte Queue-Worker-Konfiguration
- **Configuration Caching** - Automatisches Caching von Konfigurationsdateien
- **Route Caching** - Optimierte Route-Registrierung
- **View Caching** - Vorkompilierte Views für bessere Performance
- **Event Caching** - Optimierte Event-Listener-Registrierung

### Performance-Vorteile
- **High Performance Defaults** - Optimiert für hohe Anfragezahlen
- **Efficient Resource Usage** - Minimaler Memory-Footprint
- **Fast Startup Times** - Schnelle Container-Startzeiten
- **Concurrent Processing** - Effiziente Verarbeitung paralleler Requests

### Verfügbare Varianten
- **CLI** - Für Command-Line-Operationen (Artisan, Composer)
- **FPM** - Für separate Webserver-Konfigurationen
- **FPM-NGINX** - All-in-One-Lösung (empfohlen für Laravel)
- **Alpine & Debian** - Verschiedene Base-Images je nach Anforderung

### Laravel-spezifische Konfiguration

#### Task Scheduler
Der Laravel Task Scheduler läuft als separater Container:
```yaml
scheduler:
  command: ["php", "/var/www/html/artisan", "schedule:work"]
  stop_signal: SIGTERM
  healthcheck:
    test: ["CMD", "healthcheck-schedule"]
```

#### Queue Worker
Queue-Worker mit nativen Health-Checks:
```yaml
queue:
  command: ["php", "/var/www/html/artisan", "queue:work", "--tries=3"]
  stop_signal: SIGTERM
  healthcheck:
    test: ["CMD", "healthcheck-queue"]
```

#### Laravel Horizon (Optional)
Für erweiterte Queue-Verwaltung:
```bash
# Horizon starten (nur in Produktion)
./docker.sh horizon

# Horizon stoppen
./docker.sh horizon-stop
```

#### Automatisierungen (Produktion)
In der Produktion sind folgende Automatisierungen aktiviert:
- **AUTORUN_ENABLED=true** - Aktiviert Laravel-Automatisierungen
- **PHP_OPCACHE_ENABLE=1** - Aktiviert OPcache für bessere Performance
- Automatische Migrationen
- Storage-Linking
- Configuration/Route/View/Event-Caching

## Best Practices

### Entwicklung
1. Verwenden Sie `docker-compose.yml` für lokale Entwicklung
2. Testen Sie Ihre Anwendung gründlich vor dem Deployment
3. Nutzen Sie Feature-Branches für neue Funktionen

### Deployment
1. Immer Backup vor wichtigen Deployments
2. Testen Sie Deployments zuerst auf Staging
3. Verwenden Sie Blue-Green für kritische Anwendungen
4. Überwachen Sie die Anwendung nach dem Deployment

### Sicherheit
1. Regelmäßige Sicherheitsupdates
2. Starke Passwörter in der Konfiguration
3. Firewall-Regeln überprüfen
4. SSL-Zertifikate überwachen

### Performance
1. Überwachen Sie Resource-Nutzung
2. Optimieren Sie Datenbank-Queries
3. Nutzen Sie Redis für Caching
4. Komprimieren Sie Assets

## Integration in bestehende Projekte

### Schritt 1: Automatische Installation

```bash
# Im Laravel-Projekt-Verzeichnis
curl -fsSL https://raw.githubusercontent.com/ben182/laravel-deploy/main/install.sh | bash
```

### Schritt 2: Konfiguration anpassen

```bash
# Das Install-Skript konfiguriert deploy.yml automatisch
# Bei Bedarf weitere Anpassungen in deploy.yml vornehmen
```

### Schritt 3: Deployment

```bash
# Im Projekt-Verzeichnis
./deploy.sh
```

### Schritt 4: Weitere Projekte

```bash
# Jedes neue Projekt bekommt automatisch:
# - Eigene Datenbank
# - Eigenen Port (automatisch zugewiesen)
# - Eigene SSL-Zertifikate
# - Eigene Nginx-Konfiguration
```

## Support

- Prüfen Sie die Logs bei Problemen
- Verwenden Sie `--force` für Deployment-Probleme
- Nutzen Sie `--rollback` bei kritischen Fehlern
- Dokumentieren Sie Custom-Konfigurationen

## Wichtige Änderungen

- **Provision-Script**: Keine Parameter mehr nötig - erstellt automatisch 'deploy' Benutzer
- **Deploy-Script**: Läuft aus dem Projekt-Verzeichnis heraus, keine Pfad-Angabe nötig
- **SSH-Keys**: Müssen manuell zu `/home/deploy/.ssh/authorized_keys` hinzugefügt werden
- **SSL**: Immer aktiviert, kein HTTP-Traffic möglich

## Lizenz

MIT License - Frei für kommerzielle und private Nutzung.