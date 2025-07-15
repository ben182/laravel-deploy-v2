# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 📋 Projekt-Dokumentation

### Übersicht
Dieses Projekt ist ein vollständiges Laravel Docker Setup mit sauberer Konfigurationstrennung und Multi-Projekt-Support für Production-Umgebungen.

### Entwicklungsansatz
Nach jedem Prompt wird hier das Vorgehen dokumentiert und auch in der README.md aktualisiert, um eine vollständige Nachverfolgung des Entwicklungsprozesses zu gewährleisten.

### Aktuelle Implementierung

#### 1. Konfigurationsstrategie
- **Statische Daten**: `deploy-config.yml` (eingecheckt) - Projektname, Versionen, Features
- **Sensitive Daten**: `.env` (NICHT eingecheckt) - Passwörter, API-Keys, Ports
- **Template-System**: Bash-basierte Generierung von Docker Compose Files

#### 2. Multi-Projekt-Support
- Eindeutige Container-Namen basierend auf Projektnamen
- Separate Ports für verschiedene Projekte
- Isolierte Docker Volumes pro Projekt

#### 3. Production-Optimierungen
- **OPcache**: Aktiviert für PHP Performance
- **Redis**: Cache, Sessions, Queues
- **Nginx**: Security Headers, SSL, Gzip
- **Multi-Stage Builds**: Separate Dev/Prod Images

#### 4. Emoji-basierte UX
- Alle Skripte verwenden Emojis für bessere Benutzererfahrung
- Farbige Ausgaben für verschiedene Statusmeldungen
- Fortschrittsanzeigen in allen Workflows

#### 5. Automatisierung
- **Setup**: `./docker/local/scripts/setup.sh`
- **Development**: `./docker/local/scripts/dev.sh`
- **Deployment**: `./docker/remote/deployment/deploy.sh`
- **Rollback**: `./docker/remote/deployment/rollback.sh`
- **SSL**: `./docker/remote/ssl/ssl-setup.sh`

#### 6. Sicherheit
- SSH-Härtung mit Key-only Authentication
- Firewall-Konfiguration
- SSL/TLS mit Let's Encrypt
- Security Headers in Nginx
- Separate Docker User für Deployments

#### 7. Monitoring & Backup
- Automatische Backups vor Deployments
- Rollback-System mit Backup-Auswahl
- Log-Rotation für Docker Container
- Health Checks für alle Services

### Wichtige Hinweise
- Alle Skripte sind mit Emoji-UX gestaltet
- Konfigurationstrennung ist strikt eingehalten
- Multi-Projekt-Support durch eindeutige Namensgebung
- Production-Ready mit Optimierungen
- Vollständige Automatisierung von Setup bis Deployment