#!/bin/bash

# 🚀 Laravel Docker Development Helper
# Nützliche Befehle für die Entwicklung

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
CLEAN="🧹"
REFRESH="🔄"

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

show_help() {
    print_header "${ROCKET} Laravel Docker Development Helper"
    echo "Verwendung: $0 [BEFEHL]"
    echo ""
    echo "Verfügbare Befehle:"
    echo ""
    echo "  ${DOCKER} Container Management:"
    echo "    up          - Services starten"
    echo "    down        - Services stoppen"
    echo "    restart     - Services neustarten"
    echo "    rebuild     - Images neu bauen und starten"
    echo "    logs        - Logs anzeigen"
    echo "    status      - Container Status anzeigen"
    echo ""
    echo "  ${ROCKET} Laravel Commands:"
    echo "    artisan     - Laravel Artisan Befehle"
    echo "    migrate     - Datenbank migrieren"
    echo "    seed        - Datenbank mit Testdaten füllen"
    echo "    fresh       - Datenbank neu erstellen"
    echo "    optimize    - Laravel optimieren"
    echo ""
    echo "  ${PACKAGE} Dependencies:"
    echo "    composer    - Composer Befehle"
    echo "    npm         - NPM Befehle"
    echo "    install     - Alle Dependencies installieren"
    echo ""
    echo "  ${CLEAN} Maintenance:"
    echo "    clear       - Cache löschen"
    echo "    clean       - Alles aufräumen"
    echo "    reset       - Komplett zurücksetzen"
    echo ""
    echo "  ${INFO} Info:"
    echo "    urls        - Service URLs anzeigen"
    echo "    help        - Diese Hilfe anzeigen"
    echo ""
    echo "Beispiele:"
    echo "  $0 up                    # Services starten"
    echo "  $0 artisan migrate       # Datenbank migrieren"
    echo "  $0 composer install     # Composer Dependencies installieren"
    echo "  $0 npm run dev          # NPM Development Build"
}

ensure_compose_exists() {
    if [ ! -f "docker-compose.yml" ]; then
        print_error "${ERROR}" "docker-compose.yml nicht gefunden!"
        print_info "${INFO}" "Führe zuerst das Setup aus: ./docker/local/scripts/setup.sh"
        exit 1
    fi
}

container_up() {
    print_header "${DOCKER} Services starten"
    ensure_compose_exists
    docker-compose up -d
    print_status "${CHECK}" "Services gestartet"
    show_urls
}

container_down() {
    print_header "${DOCKER} Services stoppen"
    ensure_compose_exists
    docker-compose down
    print_status "${CHECK}" "Services gestoppt"
}

container_restart() {
    print_header "${DOCKER} Services neustarten"
    ensure_compose_exists
    docker-compose restart
    print_status "${CHECK}" "Services neugestartet"
}

container_rebuild() {
    print_header "${DOCKER} Images neu bauen"
    ensure_compose_exists
    docker-compose down
    docker-compose build --no-cache
    docker-compose up -d
    print_status "${CHECK}" "Images neu gebaut und gestartet"
}

show_logs() {
    print_header "${DOCKER} Container Logs"
    ensure_compose_exists
    if [ -n "$2" ]; then
        docker-compose logs -f "$2"
    else
        docker-compose logs -f
    fi
}

show_status() {
    print_header "${DOCKER} Container Status"
    ensure_compose_exists
    docker-compose ps
}

run_artisan() {
    print_header "${ROCKET} Laravel Artisan"
    ensure_compose_exists
    
    if [ -n "$2" ]; then
        # Artisan Befehl mit Parametern
        shift
        docker-compose exec app php artisan "$@"
    else
        # Artisan Liste anzeigen
        docker-compose exec app php artisan list
    fi
}

run_migrate() {
    print_header "${DATABASE} Datenbank Migration"
    ensure_compose_exists
    docker-compose exec app php artisan migrate
    print_status "${CHECK}" "Datenbank migriert"
}

run_seed() {
    print_header "${DATABASE} Datenbank Seeding"
    ensure_compose_exists
    docker-compose exec app php artisan db:seed
    print_status "${CHECK}" "Testdaten eingefügt"
}

run_fresh() {
    print_header "${DATABASE} Datenbank neu erstellen"
    ensure_compose_exists
    print_warning "${WARNING}" "Alle Daten werden gelöscht!"
    read -p "Fortfahren? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        docker-compose exec app php artisan migrate:fresh --seed
        print_status "${CHECK}" "Datenbank neu erstellt"
    fi
}

run_optimize() {
    print_header "${ROCKET} Laravel optimieren"
    ensure_compose_exists
    docker-compose exec app php artisan config:cache
    docker-compose exec app php artisan route:cache
    docker-compose exec app php artisan view:cache
    print_status "${CHECK}" "Laravel optimiert"
}

run_composer() {
    print_header "${PACKAGE} Composer"
    ensure_compose_exists
    
    if [ -n "$2" ]; then
        shift
        docker-compose exec app composer "$@"
    else
        docker-compose exec app composer install
    fi
}

run_npm() {
    print_header "${PACKAGE} NPM"
    ensure_compose_exists
    
    if [ -n "$2" ]; then
        shift
        docker-compose exec app npm "$@"
    else
        docker-compose exec app npm install
    fi
}

install_dependencies() {
    print_header "${PACKAGE} Dependencies installieren"
    ensure_compose_exists
    
    print_info "${INFO}" "Installiere Composer Dependencies..."
    docker-compose exec app composer install
    
    print_info "${INFO}" "Installiere NPM Dependencies..."
    docker-compose exec app npm install
    
    print_status "${CHECK}" "Alle Dependencies installiert"
}

clear_cache() {
    print_header "${CLEAN} Cache löschen"
    ensure_compose_exists
    
    docker-compose exec app php artisan cache:clear
    docker-compose exec app php artisan config:clear
    docker-compose exec app php artisan route:clear
    docker-compose exec app php artisan view:clear
    
    print_status "${CHECK}" "Cache gelöscht"
}

clean_all() {
    print_header "${CLEAN} Alles aufräumen"
    ensure_compose_exists
    
    print_info "${INFO}" "Lösche Cache..."
    clear_cache
    
    print_info "${INFO}" "Lösche Logs..."
    docker-compose exec app find storage/logs -name "*.log" -delete
    
    print_info "${INFO}" "Lösche temporäre Dateien..."
    docker-compose exec app find storage/framework/cache -name "*" -type f -delete
    docker-compose exec app find storage/framework/sessions -name "*" -type f -delete
    docker-compose exec app find storage/framework/views -name "*" -type f -delete
    
    print_status "${CHECK}" "Aufräumen abgeschlossen"
}

reset_all() {
    print_header "${REFRESH} Komplett zurücksetzen"
    
    print_warning "${WARNING}" "Alle Container, Volumes und Daten werden gelöscht!"
    read -p "Fortfahren? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if [ -f "docker-compose.yml" ]; then
            docker-compose down -v
        fi
        
        # Alle Container mit Projekt-Prefix löschen
        PROJECT_NAME=$(grep PROJECT_NAME .env.development 2>/dev/null | cut -d'=' -f2 || echo "laravel")
        docker container prune -f
        docker volume prune -f
        docker image prune -f
        
        print_status "${CHECK}" "Reset abgeschlossen"
        print_info "${INFO}" "Führe Setup erneut aus: ./docker/local/scripts/setup.sh"
    fi
}

show_urls() {
    print_header "${INFO} Service URLs"
    
    if [ -f ".env" ]; then
        HTTP_PORT=$(grep HTTP_PORT .env | cut -d'=' -f2)
        MYSQL_PORT=$(grep MYSQL_PORT .env | cut -d'=' -f2)
        PHPMYADMIN_PORT=$(grep PHPMYADMIN_PORT .env | cut -d'=' -f2)
        MAILHOG_PORT=$(grep MAILHOG_PORT .env | cut -d'=' -f2)
        REDIS_PORT=$(grep REDIS_PORT .env | cut -d'=' -f2)
        
        echo -e "${GREEN}${ROCKET} Laravel Application:${NC} http://localhost:${HTTP_PORT:-8100}"
        echo -e "${GREEN}${DATABASE} PhpMyAdmin:${NC} http://localhost:${PHPMYADMIN_PORT:-8180}"
        echo -e "${GREEN}📧 MailHog:${NC} http://localhost:${MAILHOG_PORT:-8125}"
        echo -e "${GREEN}${DATABASE} MySQL Port:${NC} ${MYSQL_PORT:-8106}"
        echo -e "${GREEN}${CACHE} Redis Port:${NC} ${REDIS_PORT:-8179}"
    else
        print_error "${ERROR}" ".env Datei nicht gefunden!"
    fi
}

main() {
    # In Projekt-Root wechseln
    cd "$(dirname "$0")/../../.."
    
    case "${1:-help}" in
        "up")
            container_up
            ;;
        "down")
            container_down
            ;;
        "restart")
            container_restart
            ;;
        "rebuild")
            container_rebuild
            ;;
        "logs")
            show_logs "$@"
            ;;
        "status")
            show_status
            ;;
        "artisan")
            run_artisan "$@"
            ;;
        "migrate")
            run_migrate
            ;;
        "seed")
            run_seed
            ;;
        "fresh")
            run_fresh
            ;;
        "optimize")
            run_optimize
            ;;
        "composer")
            run_composer "$@"
            ;;
        "npm")
            run_npm "$@"
            ;;
        "install")
            install_dependencies
            ;;
        "clear")
            clear_cache
            ;;
        "clean")
            clean_all
            ;;
        "reset")
            reset_all
            ;;
        "urls")
            show_urls
            ;;
        "help"|"--help"|"-h")
            show_help
            ;;
        *)
            print_error "${ERROR}" "Unbekannter Befehl: $1"
            show_help
            exit 1
            ;;
    esac
}

# Script ausführen
main "$@"