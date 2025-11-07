#!/bin/bash

# ==============================================================================
# Script 2: Configuration des Services Vulnérables
# ==============================================================================

# --- Configuration des couleurs ---
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export NC='\033[0m'

# --- Fonctions pour l'affichage ---
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# --- Gestion des erreurs et utilitaires ---
handle_error() {
    local exit_code=$?
    print_error "Échec de la configuration à la ligne $1. Commande: '$2' (code $exit_code)"
    print_warning "Vérifiez que le script 1 a été exécuté sans erreur."
    exit $exit_code
}

run_cmd() {
    local description="$1"
    shift
    local cmd=("$@")
    local caller_line=${BASH_LINENO[0]:-0}
    print_info "$description"
    if ! "${cmd[@]}"; then
        handle_error "$caller_line" "${cmd[*]}"
    fi
}

create_user_if_missing() {
    local username="$1"
    local password="$2"
    if id "$username" >/dev/null 2>&1; then
        print_warning "L'utilisateur '$username' existe déjà, mot de passe réinitialisé."
    else
        run_cmd "Création de l'utilisateur '$username'..." sudo useradd -m -s /bin/bash "$username"
    fi
    echo "$username:$password" | sudo chpasswd
}

service_exists() {
    local service="$1"
    systemctl list-unit-files --type=service "$service.service" >/dev/null 2>&1
}

restart_service_if_exists() {
    local service="$1"
    if service_exists "$service"; then
        run_cmd "Redémarrage du service '$service'..." sudo systemctl restart "$service"
    else
        print_info "Service '$service' introuvable, étape ignorée."
    fi
}

enable_service_if_exists() {
    local service="$1"
    if service_exists "$service"; then
        run_cmd "Activation du service '$service' au démarrage..." sudo systemctl enable "$service"
    else
        print_info "Service '$service' introuvable, activation ignorée."
    fi
}

backup_file_once() {
    local file="$1"
    if [ -f "$file" ] && [ ! -f "$file.bak" ]; then
        run_cmd "Sauvegarde du fichier '$file'..." sudo cp "$file" "$file.bak"
    fi
}

append_if_missing() {
    local file="$1"
    local content="$2"
    if ! sudo grep -Fxq "$content" "$file" 2>/dev/null; then
        echo "$content" | sudo tee -a "$file" >/dev/null
    fi
}

trap 'handle_error $LINENO "$BASH_COMMAND"' ERR

# --- Début du script ---
print_info "Début de la configuration des services vulnérables..."

if [ "$EUID" -ne 0 ]; then
    print_warning "Certaines commandes nécessitent des privilèges élevés. Assurez-vous que l'utilisateur courant peut exécuter sudo sans mot de passe."
fi

# 1. Configuration SSH
print_info "Configuration de SSH (autoriser root, créer utilisateurs faibles)..."
create_user_if_missing "testuser" "Password123"
create_user_if_missing "admin" "admin"
backup_file_once /etc/ssh/sshd_config
sudo sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
sudo sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
enable_service_if_exists ssh
restart_service_if_exists ssh
restart_service_if_exists sshd
print_success "SSH configuré."

# 2. Configuration vsftpd
print_info "Configuration de vsftpd (accès anonyme en écriture)..."
cat <<'EOF' | sudo tee /etc/vsftpd.conf
listen=YES
anonymous_enable=YES
anon_upload_enable=YES
anon_mkdir_write_enable=YES
write_enable=YES
local_enable=YES
chroot_local_user=YES
pasv_min_port=40000
pasv_max_port=40100
EOF
sudo mkdir -p /srv/ftp/upload
sudo chown ftp:ftp /srv/ftp/upload
enable_service_if_exists vsftpd
restart_service_if_exists vsftpd
print_success "vsftpd configuré."

# 3. Configuration MariaDB
print_info "Configuration de MariaDB (accès root sans mot de passe, création d'utilisateurs)..."
enable_service_if_exists mariadb
run_cmd "Démarrage de MariaDB..." sudo systemctl start mariadb
sudo mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY ''; FLUSH PRIVILEGES;"
sudo mysql -e "CREATE USER 'test'@'%' IDENTIFIED BY 'test'; GRANT ALL ON *.* TO 'test'@'%'; FLUSH PRIVILEGES;"
sudo mysql -e "CREATE USER IF NOT EXISTS 'readwrite'@'%' IDENTIFIED BY 'readwrite'; GRANT ALL ON *.* TO 'readwrite'@'%' WITH GRANT OPTION; FLUSH PRIVILEGES;"
print_success "MariaDB configuré."

# 4. Configuration Apache et Applications Web
print_info "Configuration d'Apache, DVWA et phpMyAdmin..."
# Lien pour phpMyAdmin
if [ ! -L /var/www/html/phpmyadmin ]; then
    sudo ln -s /usr/share/phpmyadmin /var/www/html/phpmyadmin
fi
# Configuration DVWA
cd /var/www/html
if [ ! -d dvwa ]; then
    sudo git clone https://github.com/digininja/DVWA.git dvwa
fi
sudo chown -R www-data:www-data dvwa
if [ ! -f dvwa/config/config.inc.php ]; then
    sudo cp dvwa/config/config.inc.php.dist dvwa/config/config.inc.php
fi
sudo sed -i "s/'p@ssw0rd'/''/" dvwa/config/config.inc.php
sudo mysql -e "CREATE DATABASE dvwa CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci; CREATE USER IF NOT EXISTS 'dvwa'@'localhost' IDENTIFIED BY 'dvwa'; GRANT ALL ON dvwa.* TO 'dvwa'@'localhost'; FLUSH PRIVILEGES;"
sudo chown -R www-data:www-data /var/www/html/dvwa
enable_service_if_exists apache2
restart_service_if_exists apache2
print_success "Apache et applications web configurées."

# 5. Configuration Samba
print_info "Configuration de Samba (partage public anonyme)..."
backup_file_once /etc/samba/smb.conf
cat <<'EOF' | sudo tee /etc/samba/smb.conf
[global]
   workgroup = WORKGROUP
   server string = Vulnerable SMB

[public]
   path = /srv/samba/public
   browsable = yes
   guest ok = yes
   read only = no
   create mask = 0777
EOF
sudo mkdir -p /srv/samba/public
sudo chmod -R 0777 /srv/samba/public
enable_service_if_exists smbd
enable_service_if_exists nmbd
restart_service_if_exists smbd
restart_service_if_exists nmbd
print_success "Samba configuré."

# 6. Configuration Telnet (accès root sans chiffrement)
print_info "Configuration du service Telnet vulnérable..."
if [ -f /etc/inetd.conf ]; then
    backup_file_once /etc/inetd.conf
    telnet_bin=$(command -v in.telnetd 2>/dev/null || command -v telnetd 2>/dev/null || echo /usr/sbin/in.telnetd)
    telnet_entry="telnet   stream  tcp     nowait  root    $telnet_bin  $(basename "$telnet_bin")"
    append_if_missing /etc/inetd.conf "$telnet_entry"
    enable_service_if_exists inetutils-inetd
    restart_service_if_exists inetutils-inetd
    print_success "Telnet configuré."
else
    print_warning "Impossible de trouver /etc/inetd.conf. Le service Telnet n'a pas été configuré."
fi

# 7. Configuration TFTP (accès anonyme en écriture)
print_info "Configuration du service TFTP vulnérable..."
backup_file_once /etc/default/atftpd
sudo tee /etc/default/atftpd >/dev/null <<'EOF'
USE_INETD=false
OPTIONS="--daemon --user nobody --group nogroup --maxthread 100 /srv/tftp"
EOF
sudo mkdir -p /srv/tftp
sudo chmod -R 0777 /srv/tftp
enable_service_if_exists atftpd
restart_service_if_exists atftpd
print_success "TFTP configuré."

# 8. Configuration SNMP (communauté publique exposée)
print_info "Configuration du service SNMP vulnérable..."
backup_file_once /etc/snmp/snmpd.conf
sudo tee /etc/snmp/snmpd.conf >/dev/null <<'EOF'
rocommunity public 0.0.0.0/0
sysLocation    "Victim Lab"
sysContact     "admin@victim.local"
EOF
enable_service_if_exists snmpd
restart_service_if_exists snmpd
print_success "SNMP configuré."

# 9. Configuration NFS (partage root sans restriction)
print_info "Configuration du service NFS vulnérable..."
sudo mkdir -p /srv/nfs/public
sudo chmod -R 0777 /srv/nfs/public
backup_file_once /etc/exports
append_if_missing /etc/exports "/srv/nfs/public *(rw,sync,no_root_squash,no_subtree_check)"
run_cmd "Application de la configuration NFS..." sudo exportfs -ra
enable_service_if_exists nfs-kernel-server
enable_service_if_exists nfs-server
restart_service_if_exists nfs-kernel-server
restart_service_if_exists nfs-server
print_success "NFS configuré."

# 10. Configuration Rsync (module anonyme en écriture)
print_info "Configuration du service Rsync vulnérable..."
backup_file_once /etc/rsyncd.conf
sudo tee /etc/rsyncd.conf >/dev/null <<'EOF'
uid = nobody
gid = nogroup
use chroot = no
read only = no
[public]
    path = /srv/rsync
    comment = Public rsync module
    auth users =
    secrets file =
EOF
sudo mkdir -p /srv/rsync
sudo chmod -R 0777 /srv/rsync
enable_service_if_exists rsync
restart_service_if_exists rsync
print_success "Rsync configuré."

# 11. Configuration Redis (exposé sans mot de passe)
print_info "Configuration du service Redis vulnérable..."
backup_file_once /etc/redis/redis.conf
sudo sed -i "s/^#\?bind .*/bind 0.0.0.0/" /etc/redis/redis.conf
sudo sed -i "s/^#\?protected-mode .*/protected-mode no/" /etc/redis/redis.conf
enable_service_if_exists redis-server
restart_service_if_exists redis-server
print_success "Redis configuré."

print_success "Tous les services ont été configurés avec succès."
exit 0