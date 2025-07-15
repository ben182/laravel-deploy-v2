#!/bin/bash

# 🚀 Laravel Docker Production Deployment Script
# Automatisiertes Deployment für Production Server

set -e

# Farben und Emojis
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

ROCKET="🚀"
GEAR="⚙️"
CHECK="✅"
WARNING="⚠️"
ERROR="❌"
INFO="💡"
DOCKER="🐳"
DATABASE="🗄️"
CACHE="🔄"
PACKAGE="📦"
BACKUP="💾"
LOCK="🔒"
NETWORK="🌐"
CLOCK="⏰"

# Deployment Configuration
DEPLOYMENT_DIR="/var/www/laravel"
BACKUP_DIR="/var/backups/laravel"
LOG_DIR="/var/log/laravel-deploy"
COMPOSE_FILE="docker-compose.prod.yml"

print_header() {
    echo -e "\n${BLUE}============================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}============================================${NC}\n"
}

print_status() {
    echo -e "${GREEN}$1${NC} $2"
}

print_warning() {
    echo -e "${YELLOW}$1${NC} $2"
}

print_error() {
    echo -e "${RED}$1${NC} $2"
}

print_info() {
    echo -e "${BLUE}$1${NC} $2"
}

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_DIR/deploy.log"
}

check_requirements() {
    print_header "${GEAR} Requirements prüfen"
    
    # Docker prüfen
    if ! command -v docker &> /dev/null; then
        print_error "${ERROR}" "Docker ist nicht installiert!"
        exit 1
    fi
    
    # Docker Compose prüfen
    if ! docker compose version &> /dev/null; then
        print_error "${ERROR}" "Docker Compose ist nicht installiert!"
        exit 1
    fi
    
    # User prüfen
    if [ "$(whoami)" != "docker-user" ]; then
        print_error "${ERROR}" "Script muss als 'docker-user' ausgeführt werden!"
        exit 1
    fi
    
    # Verzeichnisse erstellen
    mkdir -p "$LOG_DIR" "$BACKUP_DIR"
    
    print_status "${CHECK}" "Requirements erfüllt"
    log_message "Requirements check passed"
}

load_config() {
    print_header "${GEAR} Konfiguration laden"
    
    # deploy-config.yml prüfen
    if [ ! -f "deploy-config.yml" ]; then
        print_error "${ERROR}" "deploy-config.yml nicht gefunden!"
        exit 1
    fi
    
    # .env prüfen
    if [ ! -f ".env" ]; then
        print_error "${ERROR}" ".env Datei nicht gefunden!"
        print_info "${INFO}" "Erstelle .env aus .env.example und konfiguriere für Production"
        exit 1
    fi
    
    # Projekt-Info aus Config laden
    PROJECT_NAME=$(grep -E "^  name:" deploy-config.yml | cut -d'"' -f2)
    DOMAIN=$(grep -E "^  domain:" deploy-config.yml | cut -d'"' -f2)
    
    print_status "${CHECK}" "Projekt: $PROJECT_NAME"
    print_status "${CHECK}" "Domain: $DOMAIN"
    
    log_message "Configuration loaded: $PROJECT_NAME on $DOMAIN"
}

backup_current() {
    print_header "${BACKUP} Backup erstellen"
    
    BACKUP_TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    BACKUP_PATH="$BACKUP_DIR/backup_$BACKUP_TIMESTAMP"
    
    # Backup Verzeichnis erstellen
    mkdir -p "$BACKUP_PATH"
    
    # Aktuelle Anwendung stoppen
    if [ -f "$COMPOSE_FILE" ]; then
        print_info "${INFO}" "Stoppe aktuelle Services..."
        docker-compose -f "$COMPOSE_FILE" down
    fi
    
    # Datenbank Backup
    if docker volume inspect "${PROJECT_NAME}_mysql_data_prod" &> /dev/null; then
        print_info "${INFO}" "Erstelle Datenbank Backup..."
        docker run --rm \
            -v "${PROJECT_NAME}_mysql_data_prod:/var/lib/mysql:ro" \
            -v "$BACKUP_PATH:/backup" \
            mysql:8.0 \
            bash -c "cd /var/lib/mysql && tar czf /backup/mysql_backup.tar.gz ."
        print_status "${CHECK}" "Datenbank Backup erstellt"
    fi
    
    # Storage Backup
    if docker volume inspect "${PROJECT_NAME}_storage_data_prod" &> /dev/null; then
        print_info "${INFO}" "Erstelle Storage Backup..."
        docker run --rm \
            -v "${PROJECT_NAME}_storage_data_prod:/var/www/html/storage:ro" \
            -v "$BACKUP_PATH:/backup" \
            alpine:latest \
            bash -c "cd /var/www/html && tar czf /backup/storage_backup.tar.gz storage/"
        print_status "${CHECK}" "Storage Backup erstellt"
    fi
    
    # Code Backup (falls vorhanden)
    if [ -d "$DEPLOYMENT_DIR" ]; then
        print_info "${INFO}" "Erstelle Code Backup..."
        tar czf "$BACKUP_PATH/code_backup.tar.gz" -C "$DEPLOYMENT_DIR" .
        print_status "${CHECK}" "Code Backup erstellt"
    fi
    
    print_status "${CHECK}" "Backup erstellt: $BACKUP_PATH"
    log_message "Backup created: $BACKUP_PATH"
}

deploy_code() {
    print_header "${PACKAGE} Code Deployment"
    
    # Deployment Verzeichnis erstellen
    mkdir -p "$DEPLOYMENT_DIR"
    cd "$DEPLOYMENT_DIR"
    
    # Git Repository klonen/updaten
    if [ ! -d ".git" ]; then
        print_info "${INFO}" "Klone Git Repository..."
        git clone . .
    else
        print_info "${INFO}" "Aktualisiere Git Repository..."
        git fetch origin
        git reset --hard origin/main
    fi
    
    # Dependencies installieren
    print_info "${INFO}" "Installiere Dependencies..."
    docker run --rm \
        -v "$(pwd):/app" \
        -w /app \
        composer:latest \
        composer install --no-dev --optimize-autoloader --no-interaction
    
    print_status "${CHECK}" "Code deployment abgeschlossen"
    log_message "Code deployed successfully"
}

generate_production_config() {
    print_header "${GEAR} Production Konfiguration"
    
    # Docker Compose für Production generieren
    if [ -f "docker/local/scripts/generate-compose.sh" ]; then
        print_info "${INFO}" "Generiere Production Docker Compose..."
        ./docker/local/scripts/generate-compose.sh production
        print_status "${CHECK}" "Production Konfiguration generiert"
    else
        print_error "${ERROR}" "Compose Generator nicht gefunden!"
        exit 1
    fi
    
    # Laravel optimieren
    print_info "${INFO}" "Optimiere Laravel..."
    docker run --rm \
        -v "$(pwd):/app" \
        -w /app \
        php:8.3-cli \
        php artisan config:cache
    
    docker run --rm \
        -v "$(pwd):/app" \
        -w /app \
        php:8.3-cli \
        php artisan route:cache
    
    docker run --rm \
        -v "$(pwd):/app" \
        -w /app \
        php:8.3-cli \
        php artisan view:cache
    
    print_status "${CHECK}" "Laravel optimiert"
    log_message "Production configuration generated"
}

start_services() {
    print_header "${DOCKER} Services starten"
    
    # Docker Images bauen
    print_info "${INFO}" "Baue Docker Images..."
    docker-compose -f "$COMPOSE_FILE" build --no-cache
    
    # Services starten
    print_info "${INFO}" "Starte Services..."
    docker-compose -f "$COMPOSE_FILE" up -d
    
    # Warten auf Services
    print_info "${INFO}" "Warte auf Services..."
    sleep 30
    
    # Health Check
    print_info "${INFO}" "Prüfe Service Health..."
    max_attempts=30
    attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if docker-compose -f "$COMPOSE_FILE" ps | grep -q "Up"; then
            print_status "${CHECK}" "Services gestartet"
            break
        fi
        
        attempt=$((attempt + 1))
        sleep 10
        
        if [ $attempt -eq $max_attempts ]; then
            print_error "${ERROR}" "Services konnten nicht gestartet werden!"
            docker-compose -f "$COMPOSE_FILE" logs
            exit 1
        fi
    done
    
    log_message "Services started successfully"
}

run_migrations() {
    print_header "${DATABASE} Datenbank Migration"
    
    # Warten auf Datenbank
    print_info "${INFO}" "Warte auf MySQL..."
    docker-compose -f "$COMPOSE_FILE" exec -T mysql \
        bash -c 'while ! mysqladmin ping -h"localhost" --silent; do sleep 1; done'
    
    # Migrationen ausführen
    print_info "${INFO}" "Führe Migrationen aus..."
    docker-compose -f "$COMPOSE_FILE" exec -T app \
        php artisan migrate --force
    
    print_status "${CHECK}" "Migrationen abgeschlossen"
    log_message "Database migrations completed"
}

setup_ssl() {
    print_header "${LOCK} SSL Setup"
    
    # SSL Zertifikat prüfen/erstellen
    if [ ! -f "/etc/ssl/certs/${DOMAIN}.crt" ]; then
        print_info "${INFO}" "Erstelle SSL Zertifikat für $DOMAIN..."
        
        # Let's Encrypt Zertifikat erstellen
        certbot certonly \
            --standalone \
            --non-interactive \
            --agree-tos \
            --email "admin@${DOMAIN}" \
            -d "$DOMAIN"
        
        # Zertifikat in Docker Volume kopieren
        docker run --rm \
            -v "/etc/letsencrypt:/letsencrypt:ro" \
            -v "${PROJECT_NAME}_ssl_certs_prod:/ssl-certs" \
            -v "${PROJECT_NAME}_ssl_private_prod:/ssl-private" \
            alpine:latest \
            sh -c "
                cp /letsencrypt/live/${DOMAIN}/fullchain.pem /ssl-certs/${DOMAIN}.crt
                cp /letsencrypt/live/${DOMAIN}/privkey.pem /ssl-private/${DOMAIN}.key
            "
        
        print_status "${CHECK}" "SSL Zertifikat erstellt"
    else
        print_status "${CHECK}" "SSL Zertifikat existiert bereits"
    fi
    
    # SSL Konfiguration für Nginx
    docker run --rm \
        -v "$(pwd):/app" \
        -v "${PROJECT_NAME}_ssl_certs_prod:/ssl-certs" \
        alpine:latest \
        sh -c "
            sed 's/{{ DOMAIN_NAME }}/${DOMAIN}/g; s/{{ CERT_NAME }}/${DOMAIN}/g' \
                /app/docker/shared/nginx/ssl.conf > /ssl-certs/nginx-ssl.conf
        "
    
    log_message "SSL setup completed for $DOMAIN"
}

cleanup_old_images() {
    print_header "${CACHE} Cleanup"
    
    # Alte Images löschen
    print_info "${INFO}" "Lösche alte Docker Images..."
    docker image prune -f
    
    # Alte Backups löschen (älter als 30 Tage)
    print_info "${INFO}" "Lösche alte Backups..."
    find "$BACKUP_DIR" -type d -name "backup_*" -mtime +30 -exec rm -rf {} \;
    
    print_status "${CHECK}" "Cleanup abgeschlossen"
    log_message "Cleanup completed"
}

verify_deployment() {
    print_header "${CHECK} Deployment Verification"
    
    # HTTP Check
    if curl -f -s "http://localhost/health" > /dev/null; then
        print_status "${CHECK}" "HTTP Health Check erfolgreich"
    else
        print_error "${ERROR}" "HTTP Health Check fehlgeschlagen!"
        exit 1
    fi
    
    # HTTPS Check (falls SSL aktiviert)
    if [ -f "/etc/ssl/certs/${DOMAIN}.crt" ]; then
        if curl -f -s "https://${DOMAIN}/health" > /dev/null; then
            print_status "${CHECK}" "HTTPS Health Check erfolgreich"
        else
            print_warning "${WARNING}" "HTTPS Health Check fehlgeschlagen"
        fi
    fi
    
    # Service Status
    if docker-compose -f "$COMPOSE_FILE" ps | grep -q "Up"; then
        print_status "${CHECK}" "Alle Services laufen"
    else
        print_error "${ERROR}" "Nicht alle Services laufen!"
        docker-compose -f "$COMPOSE_FILE" ps
        exit 1
    fi
    
    log_message "Deployment verification completed successfully"
}

show_deployment_info() {
    print_header "${ROCKET} Deployment abgeschlossen!"
    
    # Service URLs
    echo -e "${GREEN}${NETWORK} Application URLs:${NC}"
    echo -e "  HTTP:  http://${DOMAIN}"
    if [ -f "/etc/ssl/certs/${DOMAIN}.crt" ]; then
        echo -e "  HTTPS: https://${DOMAIN}"
    fi
    echo -e "  Health: http://${DOMAIN}/health"
    
    # Container Status
    echo -e "\n${GREEN}${DOCKER} Container Status:${NC}"
    docker-compose -f "$COMPOSE_FILE" ps
    
    # Nützliche Befehle
    echo -e "\n${BLUE}Nützliche Befehle:${NC}"
    echo -e "  Logs: ${GREEN}docker-compose -f $COMPOSE_FILE logs -f${NC}"
    echo -e "  Status: ${GREEN}docker-compose -f $COMPOSE_FILE ps${NC}"
    echo -e "  Restart: ${GREEN}docker-compose -f $COMPOSE_FILE restart${NC}"
    echo -e "  Artisan: ${GREEN}docker-compose -f $COMPOSE_FILE exec app php artisan${NC}"
    
    # Backup Info
    echo -e "\n${BLUE}Backup Information:${NC}"
    echo -e "  Backup Dir: ${GREEN}$BACKUP_DIR${NC}"
    echo -e "  Logs: ${GREEN}$LOG_DIR${NC}"
    
    log_message "Deployment completed successfully"
}

main() {
    print_header "${ROCKET} Laravel Docker Production Deployment"
    
    # Deployment workflow
    check_requirements
    load_config
    backup_current
    deploy_code
    generate_production_config
    start_services
    run_migrations
    setup_ssl
    cleanup_old_images
    verify_deployment
    show_deployment_info
    
    print_info "${INFO}" "Deployment erfolgreich abgeschlossen!"
}

# Fehlerbehandlung
trap 'print_error "${ERROR}" "Deployment fehlgeschlagen! Siehe Logs in $LOG_DIR/deploy.log"' ERR

# Script ausführen
main "$@"