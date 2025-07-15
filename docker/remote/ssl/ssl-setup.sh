#!/bin/bash

# 🔒 Laravel Docker SSL Management
# Automatische SSL-Zertifikat Erstellung und Erneuerung

set -e

# Farben und Emojis
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

LOCK="🔒"
ROCKET="🚀"
GEAR="⚙️"
CHECK="✅"
WARNING="⚠️"
ERROR="❌"
INFO="💡"
DOCKER="🐳"
NETWORK="🌐"
CLOCK="⏰"
SHIELD="🛡️"

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
    print_header "${LOCK} SSL Management Commands"
    echo "Verwendung: $0 [COMMAND] [DOMAIN]"
    echo ""
    echo "Commands:"
    echo "  create [domain]     - Erstelle SSL-Zertifikat für Domain"
    echo "  renew [domain]      - Erneuere SSL-Zertifikat"
    echo "  renew-all           - Erneuere alle Zertifikate"
    echo "  status [domain]     - Zeige Zertifikat-Status"
    echo "  list                - Liste alle Zertifikate"
    echo "  remove [domain]     - Entferne Zertifikat"
    echo "  auto-renew          - Richte automatische Erneuerung ein"
    echo "  help                - Zeige diese Hilfe"
    echo ""
    echo "Beispiele:"
    echo "  $0 create example.com"
    echo "  $0 renew example.com"
    echo "  $0 status example.com"
    echo "  $0 renew-all"
}

check_requirements() {
    print_header "${GEAR} Requirements prüfen"
    
    # Root-Check
    if [ "$EUID" -ne 0 ]; then
        print_error "${ERROR}" "Script muss als root ausgeführt werden!"
        exit 1
    fi
    
    # Certbot prüfen
    if ! command -v certbot &> /dev/null; then
        print_error "${ERROR}" "Certbot ist nicht installiert!"
        print_info "${INFO}" "Installiere Certbot mit: apt install certbot python3-certbot-nginx"
        exit 1
    fi
    
    # Docker prüfen
    if ! command -v docker &> /dev/null; then
        print_error "${ERROR}" "Docker ist nicht installiert!"
        exit 1
    fi
    
    print_status "${CHECK}" "Requirements erfüllt"
}

load_project_config() {
    print_header "${GEAR} Projekt-Konfiguration laden"
    
    if [ -f "/var/www/laravel/deploy-config.yml" ]; then
        cd /var/www/laravel
        PROJECT_NAME=$(grep -E "^  name:" deploy-config.yml | cut -d'"' -f2)
        DEFAULT_DOMAIN=$(grep -E "^  domain:" deploy-config.yml | cut -d'"' -f2)
        SSL_EMAIL=$(grep -E "^  ssl_email:" deploy-config.yml | cut -d'"' -f2)
        
        print_status "${CHECK}" "Projekt: $PROJECT_NAME"
        print_status "${CHECK}" "Domain: $DEFAULT_DOMAIN"
        print_status "${CHECK}" "SSL Email: $SSL_EMAIL"
    else
        print_warning "${WARNING}" "Keine Projekt-Konfiguration gefunden, verwende Defaults"
        PROJECT_NAME="laravel"
        DEFAULT_DOMAIN=""
        SSL_EMAIL="admin@example.com"
    fi
}

create_ssl_certificate() {
    local domain=${1:-$DEFAULT_DOMAIN}
    
    if [ -z "$domain" ]; then
        print_error "${ERROR}" "Domain ist erforderlich!"
        echo "Verwendung: $0 create <domain>"
        exit 1
    fi
    
    print_header "${LOCK} SSL-Zertifikat erstellen für $domain"
    
    # Prüfe ob Zertifikat bereits existiert
    if [ -d "/etc/letsencrypt/live/$domain" ]; then
        print_warning "${WARNING}" "Zertifikat für $domain existiert bereits!"
        read -p "Überschreiben? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "${INFO}" "Abgebrochen"
            exit 0
        fi
    fi
    
    # Temporärer Webserver für Challenge
    print_info "${INFO}" "Starte temporären Webserver für Challenge..."
    docker run -d --name ssl-challenge \
        -p 80:80 \
        -v /tmp/ssl-challenge:/usr/share/nginx/html \
        nginx:alpine
    
    # Let's Encrypt Zertifikat erstellen
    print_info "${INFO}" "Erstelle Let's Encrypt Zertifikat..."
    certbot certonly \
        --webroot \
        --webroot-path=/tmp/ssl-challenge \
        --non-interactive \
        --agree-tos \
        --email "$SSL_EMAIL" \
        -d "$domain"
    
    # Cleanup
    docker stop ssl-challenge && docker rm ssl-challenge
    rm -rf /tmp/ssl-challenge
    
    # Zertifikat in Docker Volumes kopieren
    print_info "${INFO}" "Kopiere Zertifikat in Docker Volumes..."
    
    # SSL Volumes erstellen falls nicht vorhanden
    docker volume create "${PROJECT_NAME}_ssl_certs_prod" 2>/dev/null || true
    docker volume create "${PROJECT_NAME}_ssl_private_prod" 2>/dev/null || true
    
    # Zertifikat kopieren
    docker run --rm \
        -v "/etc/letsencrypt:/letsencrypt:ro" \
        -v "${PROJECT_NAME}_ssl_certs_prod:/ssl-certs" \
        -v "${PROJECT_NAME}_ssl_private_prod:/ssl-private" \
        alpine:latest \
        sh -c "
            cp /letsencrypt/live/$domain/fullchain.pem /ssl-certs/$domain.crt
            cp /letsencrypt/live/$domain/privkey.pem /ssl-private/$domain.key
            chmod 644 /ssl-certs/$domain.crt
            chmod 600 /ssl-private/$domain.key
        "
    
    print_status "${CHECK}" "SSL-Zertifikat für $domain erstellt"
    
    # Nginx-Konfiguration aktualisieren
    update_nginx_config "$domain"
    
    # Container neustarten
    restart_containers
}

renew_ssl_certificate() {
    local domain=${1:-$DEFAULT_DOMAIN}
    
    if [ -z "$domain" ]; then
        print_error "${ERROR}" "Domain ist erforderlich!"
        echo "Verwendung: $0 renew <domain>"
        exit 1
    fi
    
    print_header "${LOCK} SSL-Zertifikat erneuern für $domain"
    
    # Prüfe ob Zertifikat existiert
    if [ ! -d "/etc/letsencrypt/live/$domain" ]; then
        print_error "${ERROR}" "Zertifikat für $domain nicht gefunden!"
        exit 1
    fi
    
    # Zertifikat erneuern
    print_info "${INFO}" "Erneuere Zertifikat..."
    certbot renew --cert-name "$domain"
    
    # Zertifikat in Docker Volumes aktualisieren
    print_info "${INFO}" "Aktualisiere Zertifikat in Docker Volumes..."
    docker run --rm \
        -v "/etc/letsencrypt:/letsencrypt:ro" \
        -v "${PROJECT_NAME}_ssl_certs_prod:/ssl-certs" \
        -v "${PROJECT_NAME}_ssl_private_prod:/ssl-private" \
        alpine:latest \
        sh -c "
            cp /letsencrypt/live/$domain/fullchain.pem /ssl-certs/$domain.crt
            cp /letsencrypt/live/$domain/privkey.pem /ssl-private/$domain.key
            chmod 644 /ssl-certs/$domain.crt
            chmod 600 /ssl-private/$domain.key
        "
    
    print_status "${CHECK}" "SSL-Zertifikat für $domain erneuert"
    
    # Container neustarten
    restart_containers
}

renew_all_certificates() {
    print_header "${LOCK} Alle SSL-Zertifikate erneuern"
    
    # Alle Zertifikate erneuern
    print_info "${INFO}" "Erneuere alle Zertifikate..."
    certbot renew
    
    # Alle Zertifikate in Docker Volumes aktualisieren
    print_info "${INFO}" "Aktualisiere alle Zertifikate in Docker Volumes..."
    
    for cert_dir in /etc/letsencrypt/live/*/; do
        if [ -d "$cert_dir" ]; then
            domain=$(basename "$cert_dir")
            
            # Skip README
            if [ "$domain" = "README" ]; then
                continue
            fi
            
            print_info "${INFO}" "Aktualisiere Zertifikat für $domain..."
            docker run --rm \
                -v "/etc/letsencrypt:/letsencrypt:ro" \
                -v "${PROJECT_NAME}_ssl_certs_prod:/ssl-certs" \
                -v "${PROJECT_NAME}_ssl_private_prod:/ssl-private" \
                alpine:latest \
                sh -c "
                    cp /letsencrypt/live/$domain/fullchain.pem /ssl-certs/$domain.crt
                    cp /letsencrypt/live/$domain/privkey.pem /ssl-private/$domain.key
                    chmod 644 /ssl-certs/$domain.crt
                    chmod 600 /ssl-private/$domain.key
                "
        fi
    done
    
    print_status "${CHECK}" "Alle SSL-Zertifikate erneuert"
    
    # Container neustarten
    restart_containers
}

show_certificate_status() {
    local domain=${1:-$DEFAULT_DOMAIN}
    
    if [ -z "$domain" ]; then
        print_error "${ERROR}" "Domain ist erforderlich!"
        echo "Verwendung: $0 status <domain>"
        exit 1
    fi
    
    print_header "${LOCK} SSL-Zertifikat Status für $domain"
    
    if [ ! -d "/etc/letsencrypt/live/$domain" ]; then
        print_error "${ERROR}" "Zertifikat für $domain nicht gefunden!"
        exit 1
    fi
    
    # Zertifikat-Info anzeigen
    print_info "${INFO}" "Zertifikat-Informationen:"
    certbot certificates -d "$domain"
    
    # Ablaufdatum prüfen
    expiry_date=$(openssl x509 -in "/etc/letsencrypt/live/$domain/cert.pem" -noout -dates | grep "notAfter" | cut -d'=' -f2)
    print_info "${INFO}" "Läuft ab: $expiry_date"
    
    # Verbleibende Tage
    expiry_epoch=$(date -d "$expiry_date" +%s)
    current_epoch=$(date +%s)
    days_remaining=$(( (expiry_epoch - current_epoch) / 86400 ))
    
    if [ $days_remaining -le 30 ]; then
        print_warning "${WARNING}" "Zertifikat läuft in $days_remaining Tagen ab!"
    else
        print_status "${CHECK}" "Zertifikat läuft in $days_remaining Tagen ab"
    fi
}

list_certificates() {
    print_header "${LOCK} Alle SSL-Zertifikate"
    
    if [ ! -d "/etc/letsencrypt/live" ]; then
        print_info "${INFO}" "Keine Zertifikate gefunden"
        return
    fi
    
    print_info "${INFO}" "Installierte Zertifikate:"
    certbot certificates
}

remove_certificate() {
    local domain=${1:-$DEFAULT_DOMAIN}
    
    if [ -z "$domain" ]; then
        print_error "${ERROR}" "Domain ist erforderlich!"
        echo "Verwendung: $0 remove <domain>"
        exit 1
    fi
    
    print_header "${LOCK} SSL-Zertifikat entfernen für $domain"
    
    print_warning "${WARNING}" "Zertifikat für $domain wird entfernt!"
    read -p "Fortfahren? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "${INFO}" "Abgebrochen"
        exit 0
    fi
    
    # Zertifikat entfernen
    certbot delete --cert-name "$domain"
    
    # Aus Docker Volumes entfernen
    docker run --rm \
        -v "${PROJECT_NAME}_ssl_certs_prod:/ssl-certs" \
        -v "${PROJECT_NAME}_ssl_private_prod:/ssl-private" \
        alpine:latest \
        sh -c "
            rm -f /ssl-certs/$domain.crt
            rm -f /ssl-private/$domain.key
        "
    
    print_status "${CHECK}" "SSL-Zertifikat für $domain entfernt"
}

setup_auto_renewal() {
    print_header "${CLOCK} Automatische Erneuerung einrichten"
    
    # Cron-Job für automatische Erneuerung
    CRON_COMMAND="0 2 * * * /usr/bin/certbot renew --quiet && /usr/bin/docker restart \$(docker ps -q --filter \"name=${PROJECT_NAME}_app_prod\")"
    
    # Prüfe ob Cron-Job bereits existiert
    if crontab -l 2>/dev/null | grep -q "certbot renew"; then
        print_warning "${WARNING}" "Automatische Erneuerung bereits eingerichtet"
    else
        # Cron-Job hinzufügen
        (crontab -l 2>/dev/null; echo "$CRON_COMMAND") | crontab -
        print_status "${CHECK}" "Automatische Erneuerung eingerichtet"
    fi
    
    # Renewals-Hook erstellen
    mkdir -p /etc/letsencrypt/renewal-hooks/post
    cat > /etc/letsencrypt/renewal-hooks/post/docker-restart.sh << 'EOF'
#!/bin/bash
# Docker Container nach SSL-Erneuerung neustarten
PROJECT_NAME=$(grep -E "^  name:" /var/www/laravel/deploy-config.yml | cut -d'"' -f2)
if [ -n "$PROJECT_NAME" ]; then
    docker restart "${PROJECT_NAME}_app_prod" 2>/dev/null || true
fi
EOF
    
    chmod +x /etc/letsencrypt/renewal-hooks/post/docker-restart.sh
    
    print_status "${CHECK}" "Renewal-Hook erstellt"
    print_info "${INFO}" "Automatische Erneuerung läuft täglich um 02:00 Uhr"
}

update_nginx_config() {
    local domain=$1
    
    print_info "${INFO}" "Aktualisiere Nginx-Konfiguration für $domain..."
    
    # SSL-Konfiguration für Nginx generieren
    if [ -f "/var/www/laravel/docker/shared/nginx/ssl.conf" ]; then
        docker run --rm \
            -v "/var/www/laravel:/app:ro" \
            -v "${PROJECT_NAME}_ssl_certs_prod:/ssl-certs" \
            alpine:latest \
            sh -c "
                sed 's/{{ DOMAIN_NAME }}/$domain/g; s/{{ CERT_NAME }}/$domain/g' \
                    /app/docker/shared/nginx/ssl.conf > /ssl-certs/nginx-ssl.conf
            "
        
        print_status "${CHECK}" "Nginx-Konfiguration aktualisiert"
    fi
}

restart_containers() {
    print_header "${DOCKER} Container neustarten"
    
    if [ -f "/var/www/laravel/docker-compose.prod.yml" ]; then
        cd /var/www/laravel
        
        print_info "${INFO}" "Starte Container neu..."
        docker-compose -f docker-compose.prod.yml restart
        
        print_status "${CHECK}" "Container neugestartet"
    else
        print_warning "${WARNING}" "Keine Docker Compose Konfiguration gefunden"
    fi
}

main() {
    case "${1:-help}" in
        "create")
            check_requirements
            load_project_config
            create_ssl_certificate "$2"
            ;;
        "renew")
            check_requirements
            load_project_config
            renew_ssl_certificate "$2"
            ;;
        "renew-all")
            check_requirements
            load_project_config
            renew_all_certificates
            ;;
        "status")
            check_requirements
            load_project_config
            show_certificate_status "$2"
            ;;
        "list")
            check_requirements
            list_certificates
            ;;
        "remove")
            check_requirements
            load_project_config
            remove_certificate "$2"
            ;;
        "auto-renew")
            check_requirements
            load_project_config
            setup_auto_renewal
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