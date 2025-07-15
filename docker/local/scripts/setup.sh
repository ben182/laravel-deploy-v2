#!/bin/bash

# 🚀 Laravel Docker Setup Script
# Lokale Entwicklungsumgebung einrichten

set -e

# Farben und Emojis für bessere UX
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Emojis
ROCKET="🚀"
GEAR="⚙️"
CHECK="✅"
WARNING="⚠️"
ERROR="❌"
INFO="💡"
DOCKER="🐳"
DATABASE="🗄️"
CACHE="🔄"
ENVELOPE="📧"
PACKAGE="📦"

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

check_requirements() {
    print_header "${GEAR} Prüfe System-Anforderungen"
    
    # Docker prüfen
    if ! command -v docker &> /dev/null; then
        print_error "${ERROR}" "Docker ist nicht installiert!"
        print_info "${INFO}" "Installiere Docker von: https://docker.com/get-started"
        exit 1
    fi
    print_status "${CHECK}" "Docker ist installiert"
    
    # Docker Compose prüfen
    if ! command -v docker-compose &> /dev/null; then
        print_error "${ERROR}" "Docker Compose ist nicht installiert!"
        print_info "${INFO}" "Installiere Docker Compose von: https://docs.docker.com/compose/install/"
        exit 1
    fi
    print_status "${CHECK}" "Docker Compose ist installiert"
    
    # Bash prüfen (für Generator)
    if ! command -v bash &> /dev/null; then
        print_error "${ERROR}" "Bash ist nicht installiert!"
        exit 1
    fi
    print_status "${CHECK}" "Bash ist verfügbar"
    
    # Docker läuft prüfen
    if ! docker info &> /dev/null; then
        print_error "${ERROR}" "Docker läuft nicht!"
        print_info "${INFO}" "Starte Docker Desktop oder Docker Service"
        exit 1
    fi
    print_status "${CHECK}" "Docker läuft"
}

setup_env() {
    print_header "${GEAR} Umgebungskonfiguration"
    
    # .env prüfen
    if [ ! -f ".env" ]; then
        if [ -f ".env.example" ]; then
            print_info "${INFO}" "Kopiere .env.example zu .env..."
            cp .env.example .env
            print_status "${CHECK}" ".env Datei erstellt"
            print_warning "${WARNING}" "Bitte .env Datei anpassen, besonders:"
            echo "  - APP_KEY generieren"
            echo "  - Datenbank-Credentials setzen"
            echo "  - Ports für Multi-Projekt-Setup anpassen"
            echo ""
            read -p "Möchtest du die .env Datei jetzt bearbeiten? (y/n): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                ${EDITOR:-nano} .env
            fi
        else
            print_error "${ERROR}" "Keine .env.example Datei gefunden!"
            exit 1
        fi
    else
        print_status "${CHECK}" ".env Datei existiert bereits"
    fi
    
    # APP_KEY generieren falls leer
    if ! grep -q "APP_KEY=base64:" .env; then
        print_info "${INFO}" "Generiere APP_KEY..."
        # Fallback für APP_KEY Generierung
        APP_KEY=$(openssl rand -base64 32)
        sed -i.bak "s/APP_KEY=.*/APP_KEY=base64:$APP_KEY/" .env
        print_status "${CHECK}" "APP_KEY generiert"
    fi
}

check_generator() {
    print_header "${PACKAGE} Generator prüfen"
    
    # Generator Script prüfen
    if [ -f "docker/local/scripts/generate-compose.sh" ]; then
        print_status "${CHECK}" "Compose Generator verfügbar"
        # Script ausführbar machen
        chmod +x docker/local/scripts/generate-compose.sh
    else
        print_error "${ERROR}" "Generator Script nicht gefunden!"
        exit 1
    fi
}

generate_compose() {
    print_header "${DOCKER} Docker Compose Generierung"
    
    # Generator ausführen
    if [ -f "docker/local/scripts/generate-compose.sh" ]; then
        print_info "${INFO}" "Generiere Docker Compose Konfiguration..."
        ./docker/local/scripts/generate-compose.sh
        print_status "${CHECK}" "Docker Compose Dateien generiert"
    else
        print_error "${ERROR}" "Generator nicht gefunden!"
        exit 1
    fi
}

setup_directories() {
    print_header "${GEAR} Verzeichnisse einrichten"
    
    # Wichtige Verzeichnisse erstellen
    directories=(
        "docker/local/mysql"
        "docker/remote/mysql"
        "docker/remote/backup"
        "storage/app"
        "storage/framework/cache"
        "storage/framework/sessions"
        "storage/framework/views"
        "storage/logs"
        "bootstrap/cache"
    )
    
    for dir in "${directories[@]}"; do
        if [ ! -d "$dir" ]; then
            mkdir -p "$dir"
            print_status "${CHECK}" "Verzeichnis erstellt: $dir"
        fi
    done
    
    # Berechtigungen setzen
    chmod -R 755 storage bootstrap/cache
    print_status "${CHECK}" "Berechtigungen gesetzt"
}

start_services() {
    print_header "${DOCKER} Services starten"
    
    # Docker Compose starten
    print_info "${INFO}" "Starte Docker Container..."
    docker-compose up -d
    
    # Warten auf Services
    print_info "${INFO}" "Warte auf Services..."
    sleep 10
    
    # Gesundheitsprüfung
    if docker-compose ps | grep -q "Up"; then
        print_status "${CHECK}" "Docker Services gestartet"
    else
        print_error "${ERROR}" "Fehler beim Starten der Services!"
        docker-compose logs
        exit 1
    fi
}

setup_laravel() {
    print_header "${ROCKET} Laravel Setup"
    
    # Composer Dependencies installieren
    print_info "${INFO}" "Installiere Composer Dependencies..."
    docker-compose exec app composer install
    print_status "${CHECK}" "Composer Dependencies installiert"
    
    # Laravel optimieren
    print_info "${INFO}" "Optimiere Laravel..."
    docker-compose exec app php artisan config:cache
    docker-compose exec app php artisan route:cache
    docker-compose exec app php artisan view:cache
    print_status "${CHECK}" "Laravel optimiert"
    
    # Datenbank migrieren
    print_info "${INFO}" "Migriere Datenbank..."
    docker-compose exec app php artisan migrate --force
    print_status "${CHECK}" "Datenbank migriert"
    
    # Storage Link erstellen
    print_info "${INFO}" "Erstelle Storage Link..."
    docker-compose exec app php artisan storage:link
    print_status "${CHECK}" "Storage Link erstellt"
}

show_status() {
    print_header "${CHECK} Setup abgeschlossen!"
    
    # Service URLs anzeigen
    HTTP_PORT=$(grep HTTP_PORT .env | cut -d'=' -f2)
    MYSQL_PORT=$(grep MYSQL_PORT .env | cut -d'=' -f2)
    PHPMYADMIN_PORT=$(grep PHPMYADMIN_PORT .env | cut -d'=' -f2)
    MAILHOG_PORT=$(grep MAILHOG_PORT .env | cut -d'=' -f2)
    
    echo -e "${GREEN}${ROCKET} Laravel Application:${NC} http://localhost:${HTTP_PORT:-8100}"
    echo -e "${GREEN}${DATABASE} PhpMyAdmin:${NC} http://localhost:${PHPMYADMIN_PORT:-8180}"
    echo -e "${GREEN}${ENVELOPE} MailHog:${NC} http://localhost:${MAILHOG_PORT:-8125}"
    echo -e "${GREEN}${DATABASE} MySQL Port:${NC} ${MYSQL_PORT:-8106}"
    echo -e "${GREEN}${CACHE} Redis Port:${NC} $(grep REDIS_PORT .env | cut -d'=' -f2)"
    
    echo -e "\n${BLUE}Nützliche Befehle:${NC}"
    echo -e "  ${DOCKER} Container Status: ${GREEN}docker-compose ps${NC}"
    echo -e "  ${DOCKER} Logs anzeigen: ${GREEN}docker-compose logs -f${NC}"
    echo -e "  ${DOCKER} Services stoppen: ${GREEN}docker-compose down${NC}"
    echo -e "  ${DOCKER} Services neustarten: ${GREEN}docker-compose restart${NC}"
    echo -e "  ${ROCKET} Laravel Artisan: ${GREEN}docker-compose exec app php artisan${NC}"
    echo -e "  ${PACKAGE} Composer: ${GREEN}docker-compose exec app composer${NC}"
    echo -e "  ${PACKAGE} NPM: ${GREEN}docker-compose exec app npm${NC}"
}

main() {
    print_header "${ROCKET} Laravel Docker Setup"
    
    # In Projekt-Root wechseln
    cd "$(dirname "$0")/../../.."
    
    # Setup Steps
    check_requirements
    setup_env
    check_generator
    generate_compose
    setup_directories
    start_services
    setup_laravel
    show_status
    
    print_info "${INFO}" "Setup abgeschlossen! Viel Spaß mit Laravel + Docker!"
}

# Script ausführen
main "$@"