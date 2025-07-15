# 🚀 Laravel Docker Production Setup

Ein vollständiges, produktionsbereites Laravel-Docker-Setup mit sauberer Konfigurationstrennung und Multi-Projekt-Support.

## 🎯 Hauptmerkmale

- **Saubere Konfigurationstrennung**: Statische vs. Sensitive vs. Umgebungsspezifische Daten
- **Multi-Projekt-Support**: Mehrere Laravel-Projekte parallel auf einem Server
- **Production-Ready**: OPcache, Redis, SSL, Nginx-Optimierungen
- **Emoji-basierte UX**: Intuitive Skripte mit visuellen Fortschrittsanzeigen
- **Automatisierte Workflows**: Setup, Deployment, Rollback, SSL-Management

## 📁 Projektstruktur

```
laravel-projekt/
├── docker/                          # Docker-Setup
│   ├── local/                      # Lokale Entwicklung
│   │   ├── scripts/               # Helper-Skripte
│   │   │   ├── setup.sh          # 🚀 Vollständiges Setup
│   │   │   ├── dev.sh            # 🚀 Development Helper
│   │   │   └── generate-compose.sh # 🐳 Compose Generator
│   │   └── templates/             # Docker Compose Templates
│   │       ├── docker-compose.dev.yml
│   │       ├── docker-compose.prod.yml
│   │       └── mysql-dev.cnf
│   ├── remote/                     # Remote Server Management
│   │   ├── provision/             # Server-Setup
│   │   │   └── server-setup.sh   # 🖥️ Server Provisioning
│   │   ├── deployment/            # Deployment
│   │   │   ├── deploy.sh         # 🚀 Production Deployment
│   │   │   └── rollback.sh       # 🔄 Rollback System
│   │   └── ssl/                   # SSL-Management
│   │       └── ssl-setup.sh      # 🔒 SSL Automatisierung
│   └── shared/                     # Gemeinsame Konfigurationen
│       ├── dockerfile/            # Optimierte Dockerfiles
│       │   ├── Dockerfile        # Multi-stage Build
│       │   ├── opcache.ini       # OPcache Optimierung
│       │   ├── php.ini           # PHP Production Config
│       │   ├── php-dev.ini       # PHP Development Config
│       │   └── supervisord.conf  # Process Management
│       └── nginx/                 # Nginx-Konfigurationen
│           ├── nginx.conf        # Nginx Hauptkonfiguration
│           ├── default.conf      # Laravel-spezifische Config
│           └── ssl.conf          # SSL-Template
├── deploy-config.yml              # 📄 Statische Projektdaten
├── .env.example                   # 📄 Sensitive/Umgebungsspezifische Daten
├── docker-compose.yml             # 🐳 Development (generiert)
└── docker-compose.prod.yml        # 🐳 Production (generiert)
```

## ⚙️ Konfigurationsstrategie

### 📄 `deploy-config.yml` (Statisch, eingecheckt)
```yaml
project:
  name: "mein-laravel-projekt"
  domain: "example.com"
  ssl_email: "admin@example.com"
  
versions:
  php: "8.3"
  mysql: "8.0"
  redis: "7"
  node: "20"
  
features:
  ssl_enabled: true
  redis_cache: true
  scheduler_enabled: true
  queue_workers: 2
```

### 🔒 `.env` (Sensitiv/Umgebungsspezifisch, NICHT eingecheckt)
```env
# Laravel Standard
APP_KEY=base64:xxx
DB_PASSWORD=supersecret123
REDIS_PASSWORD=anothersecret456

# Docker Ports (umgebungsspezifisch!)
HTTP_PORT=8100
HTTPS_PORT=8143
MYSQL_PORT=8106
REDIS_PORT=8179
```

## 🚀 Quick Start

### 1. Lokale Entwicklung

```bash
# Setup ausführen
./docker/local/scripts/setup.sh

# Development Helper verwenden
./docker/local/scripts/dev.sh up        # Services starten
./docker/local/scripts/dev.sh migrate   # Datenbank migrieren
./docker/local/scripts/dev.sh urls      # Service URLs anzeigen
```

### 2. Server Provisioning

```bash
# Server vorbereiten (als root)
sudo ./docker/remote/provision/server-setup.sh

# SSL-Zertifikat erstellen
sudo ./docker/remote/ssl/ssl-setup.sh create example.com
```

### 3. Production Deployment

```bash
# Als docker-user deployen
./docker/remote/deployment/deploy.sh

# Rollback falls nötig
./docker/remote/deployment/rollback.sh
```

## 🛠️ Verfügbare Skripte

### Lokale Entwicklung (`./docker/local/scripts/dev.sh`)

| Befehl | Beschreibung |
|--------|-------------|
| `up` | Services starten |
| `down` | Services stoppen |
| `restart` | Services neustarten |
| `rebuild` | Images neu bauen |
| `logs` | Logs anzeigen |
| `artisan` | Laravel Artisan Befehle |
| `migrate` | Datenbank migrieren |
| `composer` | Composer Befehle |
| `npm` | NPM Befehle |
| `clear` | Cache löschen |
| `urls` | Service URLs anzeigen |

### SSL-Management (`./docker/remote/ssl/ssl-setup.sh`)

| Befehl | Beschreibung |
|--------|-------------|
| `create <domain>` | SSL-Zertifikat erstellen |
| `renew <domain>` | Zertifikat erneuern |
| `renew-all` | Alle Zertifikate erneuern |
| `status <domain>` | Zertifikat-Status anzeigen |
| `list` | Alle Zertifikate auflisten |
| `auto-renew` | Automatische Erneuerung einrichten |

## 🔧 Technische Details

### Multi-Stage Docker Build
- **Stage 1**: Asset Building (Node.js, NPM)
- **Stage 2**: Production (PHP-FPM, Nginx, optimiert)
- **Stage 3**: Development (Xdebug, Development Tools)

### Performance-Optimierungen
- **OPcache**: Aktiviert mit optimierten Einstellungen
- **Redis**: Cache, Sessions, Queues
- **Nginx**: Gzip, Security Headers, Rate Limiting
- **PHP**: Optimierte php.ini für Production

### Security Features
- **SSL/TLS**: Automatische Let's Encrypt Integration
- **Security Headers**: X-Frame-Options, CSP, HSTS
- **Rate Limiting**: API und Login-Endpoints
- **SSH Hardening**: Key-only Authentication, Disabled Root

### Monitoring & Logging
- **Health Checks**: Alle Services haben Health Checks
- **Log Rotation**: Automatische Log-Rotation
- **Backup System**: Automatische Backups mit Retention

## 🌐 Service URLs (Development)

| Service | URL | Beschreibung |
|---------|-----|-------------|
| Laravel App | `http://localhost:8100` | Hauptanwendung |
| PhpMyAdmin | `http://localhost:8180` | Datenbankmanagement |
| MailHog | `http://localhost:8125` | Email-Testing |
| MySQL | `localhost:8106` | Datenbankverbindung |
| Redis | `localhost:8179` | Cache-Verbindung |

## 🔄 Deployment Workflow

1. **Backup**: Automatisches Backup vor jedem Deployment
2. **Code Update**: Git Repository aktualisieren
3. **Dependencies**: Composer Dependencies installieren
4. **Build**: Docker Images bauen
5. **Database**: Migrationen ausführen
6. **SSL**: SSL-Zertifikat prüfen/erstellen
7. **Health Check**: Service-Gesundheit prüfen
8. **Cleanup**: Alte Images und Backups aufräumen

## 🐳 Docker Compose Features

### Development Environment
- **Live Reload**: Source-Code-Volumes für Entwicklung
- **Xdebug**: Debugging-Support
- **MailHog**: Email-Testing
- **PhpMyAdmin**: Datenbankmanagement

### Production Environment
- **Optimized Images**: Multi-stage Build ohne Dev-Dependencies
- **Health Checks**: Automatische Gesundheitsprüfung
- **SSL Support**: Automatische HTTPS-Weiterleitung
- **Backup System**: Automatische Backups
- **Process Management**: Supervisor für Laravel Services

## 🔧 Anpassungen

### Ports ändern
Bearbeite `.env` und passe die Ports an:
```env
HTTP_PORT=8200
HTTPS_PORT=8243
MYSQL_PORT=8206
REDIS_PORT=8279
```

### Neue Services hinzufügen
1. Service in `docker/local/templates/docker-compose.dev.yml` hinzufügen
2. Production-Version in `docker/local/templates/docker-compose.prod.yml`
3. Compose-Dateien neu generieren: `./docker/local/scripts/generate-compose.sh`

### SSL-Domains hinzufügen
```bash
# Neue Domain hinzufügen
sudo ./docker/remote/ssl/ssl-setup.sh create neue-domain.com

# Alle Domains auflisten
sudo ./docker/remote/ssl/ssl-setup.sh list
```

## 🚨 Troubleshooting

### Container starten nicht
```bash
# Logs prüfen
./docker/local/scripts/dev.sh logs

# Container Status prüfen
./docker/local/scripts/dev.sh status

# Kompletter Neustart
./docker/local/scripts/dev.sh rebuild
```

### SSL-Probleme
```bash
# SSL-Status prüfen
sudo ./docker/remote/ssl/ssl-setup.sh status example.com

# Zertifikat erneuern
sudo ./docker/remote/ssl/ssl-setup.sh renew example.com
```

### Rollback durchführen
```bash
# Verfügbare Backups anzeigen und auswählen
./docker/remote/deployment/rollback.sh
```

## 📋 Entwicklungsdokumentation

### Kontinuierliche Dokumentation
Nach jedem Prompt wird das Vorgehen sowohl in der `CLAUDE.md` als auch in dieser README dokumentiert, um eine vollständige Nachverfolgung des Entwicklungsprozesses zu gewährleisten.

### Implementierungsansatz
Das Projekt wurde systematisch entwickelt mit:
1. **Konfigurationsstrategie-Design** - Saubere Trennung zwischen statischen und sensitiven Daten
2. **Multi-Projekt-Support** - Eindeutige Namensgebung und Port-Management
3. **Production-Optimierungen** - OPcache, Redis, Nginx-Tuning
4. **Emoji-basierte UX** - Intuitive Skripte mit visuellen Fortschrittsanzeigen
5. **Vollständige Automatisierung** - Von Setup bis Deployment und Rollback

### Technische Entscheidungen
- **Template-System**: Bash-basierte Docker Compose Generierung
- **Konfigurationstrennung**: `deploy-config.yml` (statisch) vs `.env` (sensitiv)
- **Multi-Stage Builds**: Separate Optimierung für Development und Production
- **Backup-System**: Automatische Backups mit Rollback-Unterstützung
- **SSL-Management**: Let's Encrypt Integration mit automatischer Erneuerung

## 📖 Weiterführende Dokumentation

- [Laravel Docker Best Practices](https://laravel.com/docs/deployment)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Let's Encrypt SSL Setup](https://letsencrypt.org/getting-started/)
- [Nginx Configuration Guide](https://nginx.org/en/docs/)
- [CLAUDE.md](./CLAUDE.md) - Detaillierte Entwicklungsdokumentation

## 🤝 Contribution

Dieses Setup ist darauf ausgelegt, einfach erweiterbar und anpassbar zu sein. Verbesserungen und Anpassungen sind willkommen!

## 📝 Lizenz

MIT License - Verwende es frei für deine Projekte.

---

**🚀 Viel Erfolg mit deinem Laravel-Docker-Setup!**