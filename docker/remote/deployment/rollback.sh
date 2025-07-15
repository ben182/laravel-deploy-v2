#!/bin/bash

# 🔄 Laravel Docker Rollback Script
# Rollback zu vorherigem Backup

set -e

# Farben und Emojis
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

ROLLBACK="🔄"
BACKUP="💾"
CHECK="✅"
WARNING="⚠️"
ERROR="❌"
INFO="💡"
DOCKER="🐳"
DATABASE="🗄️"
CLOCK="⏰"

# Configuration
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
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_DIR/rollback.log"
}

list_backups() {
    print_header "${BACKUP} Verfügbare Backups"
    
    if [ ! -d "$BACKUP_DIR" ]; then
        print_error "${ERROR}" "Backup Verzeichnis nicht gefunden: $BACKUP_DIR"
        exit 1
    fi
    
    BACKUPS=($(ls -1 "$BACKUP_DIR" | grep "backup_" | sort -r))
    
    if [ ${#BACKUPS[@]} -eq 0 ]; then
        print_error "${ERROR}" "Keine Backups gefunden!"
        exit 1
    fi
    
    echo -e "${BLUE}Verfügbare Backups:${NC}"
    for i in "${!BACKUPS[@]}"; do
        BACKUP_DATE=$(echo "${BACKUPS[$i]}" | sed 's/backup_//' | sed 's/_/ /')
        echo -e "  ${GREEN}$((i+1))${NC}. ${BACKUPS[$i]} (${BACKUP_DATE})"
    done
    
    return 0
}

select_backup() {
    list_backups
    
    echo ""
    read -p "Wähle Backup (1-${#BACKUPS[@]}): " choice
    
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#BACKUPS[@]}" ]; then
        SELECTED_BACKUP="${BACKUPS[$((choice-1))]}"
        SELECTED_BACKUP_PATH="$BACKUP_DIR/$SELECTED_BACKUP"
        print_status "${CHECK}" "Backup ausgewählt: $SELECTED_BACKUP"
        log_message "Backup selected: $SELECTED_BACKUP"
    else
        print_error "${ERROR}" "Ungültige Auswahl!"
        exit 1
    fi
}

confirm_rollback() {
    print_header "${WARNING} Rollback Bestätigung"
    
    echo -e "${YELLOW}${WARNING} WARNUNG: Diese Aktion wird:${NC}"
    echo -e "  - Aktuelle Anwendung stoppen"
    echo -e "  - Datenbank auf Backup-Stand zurücksetzen"
    echo -e "  - Storage-Dateien zurücksetzen"
    echo -e "  - Code auf Backup-Stand zurücksetzen"
    echo ""
    echo -e "${YELLOW}Ausgewähltes Backup: ${SELECTED_BACKUP}${NC}"
    echo ""
    
    read -p "Rollback durchführen? (yes/no): " confirm
    
    if [ "$confirm" != "yes" ]; then
        print_info "${INFO}" "Rollback abgebrochen"
        exit 0
    fi
    
    log_message "Rollback confirmed for: $SELECTED_BACKUP"
}

create_pre_rollback_backup() {
    print_header "${BACKUP} Pre-Rollback Backup"
    
    CURRENT_BACKUP_PATH="$BACKUP_DIR/pre_rollback_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$CURRENT_BACKUP_PATH"
    
    # Aktuelle Services stoppen
    if [ -f "$COMPOSE_FILE" ]; then
        print_info "${INFO}" "Stoppe aktuelle Services..."
        docker-compose -f "$COMPOSE_FILE" down
    fi
    
    # Aktueller Zustand als Backup
    print_info "${INFO}" "Erstelle Pre-Rollback Backup..."
    
    # Projekt-Info laden
    PROJECT_NAME=$(grep -E "^  name:" deploy-config.yml | cut -d'"' -f2)
    
    # Datenbank Backup
    if docker volume inspect "${PROJECT_NAME}_mysql_data_prod" &> /dev/null; then
        docker run --rm \
            -v "${PROJECT_NAME}_mysql_data_prod:/var/lib/mysql:ro" \
            -v "$CURRENT_BACKUP_PATH:/backup" \
            mysql:8.0 \
            bash -c "cd /var/lib/mysql && tar czf /backup/mysql_backup.tar.gz ."
    fi
    
    # Storage Backup
    if docker volume inspect "${PROJECT_NAME}_storage_data_prod" &> /dev/null; then
        docker run --rm \
            -v "${PROJECT_NAME}_storage_data_prod:/var/www/html/storage:ro" \
            -v "$CURRENT_BACKUP_PATH:/backup" \
            alpine:latest \
            bash -c "cd /var/www/html && tar czf /backup/storage_backup.tar.gz storage/"
    fi
    
    # Code Backup
    if [ -d "/var/www/laravel" ]; then
        tar czf "$CURRENT_BACKUP_PATH/code_backup.tar.gz" -C "/var/www/laravel" .
    fi
    
    print_status "${CHECK}" "Pre-Rollback Backup erstellt: $CURRENT_BACKUP_PATH"
    log_message "Pre-rollback backup created: $CURRENT_BACKUP_PATH"
}

restore_database() {
    print_header "${DATABASE} Datenbank Rollback"
    
    if [ -f "$SELECTED_BACKUP_PATH/mysql_backup.tar.gz" ]; then
        print_info "${INFO}" "Stelle Datenbank wieder her..."
        
        # Projekt-Info laden
        PROJECT_NAME=$(grep -E "^  name:" deploy-config.yml | cut -d'"' -f2)
        
        # MySQL Volume löschen und neu erstellen
        docker volume rm "${PROJECT_NAME}_mysql_data_prod" 2>/dev/null || true
        docker volume create "${PROJECT_NAME}_mysql_data_prod"
        
        # Datenbank aus Backup wiederherstellen
        docker run --rm \
            -v "$SELECTED_BACKUP_PATH:/backup:ro" \
            -v "${PROJECT_NAME}_mysql_data_prod:/var/lib/mysql" \
            alpine:latest \
            bash -c "cd /var/lib/mysql && tar xzf /backup/mysql_backup.tar.gz"
        
        print_status "${CHECK}" "Datenbank wiederhergestellt"
        log_message "Database restored from backup"
    else
        print_warning "${WARNING}" "Kein Datenbank-Backup gefunden"
    fi
}

restore_storage() {
    print_header "${BACKUP} Storage Rollback"
    
    if [ -f "$SELECTED_BACKUP_PATH/storage_backup.tar.gz" ]; then
        print_info "${INFO}" "Stelle Storage wieder her..."
        
        # Projekt-Info laden
        PROJECT_NAME=$(grep -E "^  name:" deploy-config.yml | cut -d'"' -f2)
        
        # Storage Volume löschen und neu erstellen
        docker volume rm "${PROJECT_NAME}_storage_data_prod" 2>/dev/null || true
        docker volume create "${PROJECT_NAME}_storage_data_prod"
        
        # Storage aus Backup wiederherstellen
        docker run --rm \
            -v "$SELECTED_BACKUP_PATH:/backup:ro" \
            -v "${PROJECT_NAME}_storage_data_prod:/var/www/html/storage" \
            alpine:latest \
            bash -c "cd /var/www/html && tar xzf /backup/storage_backup.tar.gz"
        
        print_status "${CHECK}" "Storage wiederhergestellt"
        log_message "Storage restored from backup"
    else
        print_warning "${WARNING}" "Kein Storage-Backup gefunden"
    fi
}

restore_code() {
    print_header "${BACKUP} Code Rollback"
    
    if [ -f "$SELECTED_BACKUP_PATH/code_backup.tar.gz" ]; then
        print_info "${INFO}" "Stelle Code wieder her..."
        
        # Deployment Verzeichnis leeren
        rm -rf /var/www/laravel/*
        rm -rf /var/www/laravel/.[!.]*
        
        # Code aus Backup wiederherstellen
        tar xzf "$SELECTED_BACKUP_PATH/code_backup.tar.gz" -C /var/www/laravel
        
        print_status "${CHECK}" "Code wiederhergestellt"
        log_message "Code restored from backup"
    else
        print_warning "${WARNING}" "Kein Code-Backup gefunden"
    fi
}

restart_services() {
    print_header "${DOCKER} Services starten"
    
    cd /var/www/laravel
    
    # Services starten
    print_info "${INFO}" "Starte Services..."
    docker-compose -f "$COMPOSE_FILE" up -d
    
    # Warten auf Services
    print_info "${INFO}" "Warte auf Services..."
    sleep 30
    
    # Health Check
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
    
    log_message "Services restarted successfully"
}

verify_rollback() {
    print_header "${CHECK} Rollback Verification"
    
    cd /var/www/laravel
    
    # HTTP Check
    if curl -f -s "http://localhost/health" > /dev/null; then
        print_status "${CHECK}" "HTTP Health Check erfolgreich"
    else
        print_error "${ERROR}" "HTTP Health Check fehlgeschlagen!"
        exit 1
    fi
    
    # Service Status
    if docker-compose -f "$COMPOSE_FILE" ps | grep -q "Up"; then
        print_status "${CHECK}" "Alle Services laufen"
    else
        print_error "${ERROR}" "Nicht alle Services laufen!"
        docker-compose -f "$COMPOSE_FILE" ps
        exit 1
    fi
    
    log_message "Rollback verification completed successfully"
}

show_rollback_info() {
    print_header "${CHECK} Rollback abgeschlossen!"
    
    # Info
    echo -e "${GREEN}${CHECK} Rollback erfolgreich zu: ${SELECTED_BACKUP}${NC}"
    echo -e "${GREEN}${BACKUP} Pre-Rollback Backup erstellt für Notfall-Wiederherstellung${NC}"
    
    # Service Status
    echo -e "\n${GREEN}${DOCKER} Container Status:${NC}"
    cd /var/www/laravel
    docker-compose -f "$COMPOSE_FILE" ps
    
    # Nützliche Befehle
    echo -e "\n${BLUE}Nützliche Befehle:${NC}"
    echo -e "  Logs: ${GREEN}docker-compose -f $COMPOSE_FILE logs -f${NC}"
    echo -e "  Status: ${GREEN}docker-compose -f $COMPOSE_FILE ps${NC}"
    echo -e "  Backups: ${GREEN}ls -la $BACKUP_DIR${NC}"
    
    log_message "Rollback completed successfully to: $SELECTED_BACKUP"
}

main() {
    print_header "${ROLLBACK} Laravel Docker Rollback"
    
    # User prüfen
    if [ "$(whoami)" != "docker-user" ]; then
        print_error "${ERROR}" "Script muss als 'docker-user' ausgeführt werden!"
        exit 1
    fi
    
    # Log Verzeichnis erstellen
    mkdir -p "$LOG_DIR"
    
    # Rollback workflow
    select_backup
    confirm_rollback
    create_pre_rollback_backup
    restore_database
    restore_storage
    restore_code
    restart_services
    verify_rollback
    show_rollback_info
    
    print_info "${INFO}" "Rollback erfolgreich abgeschlossen!"
}

# Fehlerbehandlung
trap 'print_error "${ERROR}" "Rollback fehlgeschlagen! Siehe Logs in $LOG_DIR/rollback.log"' ERR

# Script ausführen
main "$@"