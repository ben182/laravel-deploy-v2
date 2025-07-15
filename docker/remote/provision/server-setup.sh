#!/bin/bash

# 🚀 Laravel Docker Server Provisioning Script
# Automatisierte Server-Einrichtung für Production

set -e

# Farben und Emojis
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SERVER="🖥️"
ROCKET="🚀"
GEAR="⚙️"
CHECK="✅"
WARNING="⚠️"
ERROR="❌"
INFO="💡"
DOCKER="🐳"
SHIELD="🛡️"
FIRE="🔥"
PACKAGE="📦"
NETWORK="🌐"
CLOCK="⏰"
LOCK="🔒"

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

check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "${ERROR}" "Dieses Script muss als root ausgeführt werden!"
        print_info "${INFO}" "Führe es mit 'sudo' aus oder wechsle zu root"
        exit 1
    fi
}

detect_os() {
    print_header "${SERVER} Betriebssystem erkennen"
    
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        VERSION=$VERSION_ID
    else
        print_error "${ERROR}" "Kann Betriebssystem nicht erkennen!"
        exit 1
    fi
    
    print_status "${CHECK}" "Betriebssystem: $OS $VERSION"
    
    case $OS in
        "Ubuntu")
            PACKAGE_MANAGER="apt"
            ;;
        "CentOS Linux"|"Red Hat Enterprise Linux")
            PACKAGE_MANAGER="yum"
            ;;
        "Debian GNU/Linux")
            PACKAGE_MANAGER="apt"
            ;;
        *)
            print_error "${ERROR}" "Nicht unterstütztes Betriebssystem: $OS"
            exit 1
            ;;
    esac
}

update_system() {
    print_header "${PACKAGE} System aktualisieren"
    
    case $PACKAGE_MANAGER in
        "apt")
            apt update && apt upgrade -y
            ;;
        "yum")
            yum update -y
            ;;
    esac
    
    print_status "${CHECK}" "System aktualisiert"
}

install_essentials() {
    print_header "${PACKAGE} Essentials installieren"
    
    PACKAGES="curl wget git vim nano htop unzip software-properties-common"
    
    case $PACKAGE_MANAGER in
        "apt")
            apt install -y $PACKAGES
            ;;
        "yum")
            yum install -y $PACKAGES
            ;;
    esac
    
    print_status "${CHECK}" "Essentials installiert"
}

setup_firewall() {
    print_header "${FIRE} Firewall konfigurieren"
    
    case $PACKAGE_MANAGER in
        "apt")
            # UFW installieren und konfigurieren
            apt install -y ufw
            ufw --force reset
            ufw default deny incoming
            ufw default allow outgoing
            ufw allow ssh
            ufw allow http
            ufw allow https
            ufw --force enable
            ;;
        "yum")
            # Firewalld konfigurieren
            systemctl enable firewalld
            systemctl start firewalld
            firewall-cmd --permanent --add-service=ssh
            firewall-cmd --permanent --add-service=http
            firewall-cmd --permanent --add-service=https
            firewall-cmd --reload
            ;;
    esac
    
    print_status "${CHECK}" "Firewall konfiguriert"
}

secure_ssh() {
    print_header "${SHIELD} SSH härten"
    
    # SSH Konfiguration backup
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
    
    # SSH Sicherheitseinstellungen
    cat > /etc/ssh/sshd_config.d/99-security.conf << 'EOF'
# SSH Security Configuration
Protocol 2
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
AuthorizedKeysFile %h/.ssh/authorized_keys
PermitEmptyPasswords no
ChallengeResponseAuthentication no
UsePAM yes
X11Forwarding no
PrintMotd no
TCPKeepAlive yes
ClientAliveInterval 300
ClientAliveCountMax 2
MaxAuthTries 3
MaxSessions 10
LoginGraceTime 30
EOF
    
    # SSH Service neustarten
    systemctl restart sshd
    
    print_status "${CHECK}" "SSH gehärtet"
}

install_docker() {
    print_header "${DOCKER} Docker installieren"
    
    case $PACKAGE_MANAGER in
        "apt")
            # Docker GPG Key hinzufügen
            curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
            
            # Docker Repository hinzufügen
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
            
            # Docker installieren
            apt update
            apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
            ;;
        "yum")
            # Docker Repository hinzufügen
            yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
            
            # Docker installieren
            yum install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
            ;;
    esac
    
    # Docker Service starten
    systemctl enable docker
    systemctl start docker
    
    # Docker Compose installieren (falls nicht als Plugin verfügbar)
    if ! docker compose version &>/dev/null; then
        curl -L "https://github.com/docker/compose/releases/download/v2.20.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
    fi
    
    print_status "${CHECK}" "Docker installiert"
}

setup_docker_user() {
    print_header "${DOCKER} Docker User einrichten"
    
    # Docker User erstellen
    if ! id "docker-user" &>/dev/null; then
        useradd -m -s /bin/bash docker-user
        usermod -aG docker docker-user
        print_status "${CHECK}" "Docker User erstellt"
    else
        print_status "${CHECK}" "Docker User existiert bereits"
    fi
    
    # SSH Key Setup für Docker User
    mkdir -p /home/docker-user/.ssh
    chmod 700 /home/docker-user/.ssh
    
    if [ -f /root/.ssh/authorized_keys ]; then
        cp /root/.ssh/authorized_keys /home/docker-user/.ssh/
        chown -R docker-user:docker-user /home/docker-user/.ssh
        chmod 600 /home/docker-user/.ssh/authorized_keys
        print_status "${CHECK}" "SSH Keys für Docker User konfiguriert"
    fi
}

install_monitoring() {
    print_header "${CLOCK} Monitoring installieren"
    
    case $PACKAGE_MANAGER in
        "apt")
            apt install -y htop iotop netstat-ss-utils
            ;;
        "yum")
            yum install -y htop iotop net-tools
            ;;
    esac
    
    print_status "${CHECK}" "Monitoring Tools installiert"
}

setup_log_rotation() {
    print_header "${CLOCK} Log Rotation konfigurieren"
    
    # Docker Log Rotation
    cat > /etc/docker/daemon.json << 'EOF'
{
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "100m",
        "max-file": "3"
    }
}
EOF
    
    systemctl restart docker
    
    print_status "${CHECK}" "Log Rotation konfiguriert"
}

optimize_system() {
    print_header "${GEAR} System optimieren"
    
    # Kernel Parameter optimieren
    cat > /etc/sysctl.d/99-docker.conf << 'EOF'
# Docker Performance Optimizations
net.core.somaxconn = 1024
net.core.netdev_max_backlog = 5000
net.core.rmem_default = 262144
net.core.rmem_max = 16777216
net.core.wmem_default = 262144
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_keepalive_time = 120
net.ipv4.tcp_max_syn_backlog = 4096
vm.max_map_count = 262144
EOF
    
    sysctl -p /etc/sysctl.d/99-docker.conf
    
    # Limits konfigurieren
    cat > /etc/security/limits.d/99-docker.conf << 'EOF'
# Docker Limits
docker-user soft nofile 65536
docker-user hard nofile 65536
docker-user soft nproc 32768
docker-user hard nproc 32768
EOF
    
    print_status "${CHECK}" "System optimiert"
}

setup_backup_dirs() {
    print_header "${LOCK} Backup Verzeichnisse"
    
    # Backup Verzeichnisse erstellen
    mkdir -p /var/backups/laravel
    mkdir -p /var/backups/mysql
    mkdir -p /var/backups/ssl
    
    chown -R docker-user:docker-user /var/backups
    chmod 750 /var/backups
    
    print_status "${CHECK}" "Backup Verzeichnisse erstellt"
}

install_ssl_tools() {
    print_header "${LOCK} SSL Tools installieren"
    
    case $PACKAGE_MANAGER in
        "apt")
            apt install -y certbot python3-certbot-nginx
            ;;
        "yum")
            yum install -y certbot python3-certbot-nginx
            ;;
    esac
    
    print_status "${CHECK}" "SSL Tools installiert"
}

show_next_steps() {
    print_header "${ROCKET} Server Setup abgeschlossen!"
    
    echo -e "${GREEN}${CHECK} Server ist bereit für Laravel Docker Deployment${NC}"
    echo ""
    echo -e "${BLUE}Nächste Schritte:${NC}"
    echo -e "  ${INFO} 1. Projekt auf Server deployen"
    echo -e "  ${INFO} 2. SSL-Zertifikat einrichten"
    echo -e "  ${INFO} 3. Domain konfigurieren"
    echo -e "  ${INFO} 4. Monitoring einrichten"
    echo ""
    echo -e "${BLUE}Wichtige Informationen:${NC}"
    echo -e "  ${SERVER} SSH User: docker-user"
    echo -e "  ${DOCKER} Docker: $(docker --version)"
    echo -e "  ${DOCKER} Docker Compose: $(docker compose version --short)"
    echo -e "  ${FIRE} Firewall: aktiv (SSH, HTTP, HTTPS)"
    echo -e "  ${CLOCK} Log Rotation: konfiguriert"
    echo ""
    echo -e "${YELLOW}${WARNING} Wichtig:${NC}"
    echo -e "  - Verwende nur den 'docker-user' für Deployments"
    echo -e "  - Root-Login ist deaktiviert"
    echo -e "  - Passwort-Authentication ist deaktiviert"
    echo -e "  - Nur SSH-Key Authentication ist erlaubt"
}

main() {
    print_header "${SERVER} Laravel Docker Server Setup"
    
    # Root-Check
    check_root
    
    # Setup Steps
    detect_os
    update_system
    install_essentials
    setup_firewall
    secure_ssh
    install_docker
    setup_docker_user
    install_monitoring
    setup_log_rotation
    optimize_system
    setup_backup_dirs
    install_ssl_tools
    
    # Abschluss
    show_next_steps
    
    print_info "${INFO}" "Server Setup abgeschlossen! Bereit für Laravel Deployment."
}

# Script ausführen
main "$@"