#!/bin/bash

# ==============================================================================
# Script 3: Démarrage et Vérification des Services
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

# --- Gestion des erreurs et fonctions utilitaires ---
handle_error() {
    local exit_code=$?
    print_error "Le script a échoué à la ligne $1. Commande '$2' (code $exit_code)."
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

service_exists() {
    local service="$1"
    systemctl list-unit-files --type=service "$service.service" >/dev/null 2>&1
}

restart_service_if_exists() {
    local service="$1"
    if service_exists "$service"; then
        run_cmd "Redémarrage du service '$service'..." sudo systemctl restart "$service"
    else
        print_info "Service '$service' introuvable, saut du redémarrage."
    fi
}

enable_service_if_exists() {
    local service="$1"
    if service_exists "$service"; then
        run_cmd "Activation du service '$service'..." sudo systemctl enable "$service"
    else
        print_info "Service '$service' introuvable, activation ignorée."
    fi
}

# --- Fonction de vérification de service ---
check_service() {
    local service_name=$1
    if ! service_exists "$service_name"; then
        print_warning "Le service '$service_name' n'est pas installé sur cette machine."
        return 0
    fi
    if systemctl is-active --quiet "$service_name"; then
        print_success "$service_name est en cours d'exécution."
        return 0
    else
        print_error "$service_name n'est PAS en cours d'exécution."
        print_warning "Solution : Essayez 'sudo systemctl restart $service_name' et vérifiez les logs avec 'journalctl -u $service_name'."
        return 1
    fi
}

trap 'handle_error $LINENO "$BASH_COMMAND"' ERR

# --- Début du script ---
print_info "Démarrage et vérification de tous les services..."

# Désactiver le pare-feu pour s'assurer qu'il ne bloque rien
if service_exists ufw; then
    run_cmd "Désactivation du pare-feu UFW..." sudo systemctl stop ufw
    run_cmd "Désactivation du démarrage automatique de l'UFW..." sudo systemctl disable ufw
else
    print_warning "UFW n'est pas installé, étape ignorée."
fi

# Démarrer et vérifier les services système
print_info "Démarrage des services système (SSH, Apache, MariaDB, vsftpd, Samba, etc.)..."
SYSTEM_SERVICES=(ssh sshd apache2 mariadb vsftpd smbd nmbd inetutils-inetd atftpd snmpd nfs-kernel-server nfs-server rsync redis-server)
for svc in "${SYSTEM_SERVICES[@]}"; do
    restart_service_if_exists "$svc"
    enable_service_if_exists "$svc"
done

# Vérification des services système
check_service "ssh"
check_service "sshd"
check_service "apache2"
check_service "mariadb"
check_service "vsftpd"
check_service "smbd"
check_service "nmbd"
check_service "inetutils-inetd"
check_service "atftpd"
check_service "snmpd"
check_service "nfs-kernel-server"
check_service "nfs-server"
check_service "rsync"
check_service "redis-server"

# Démarrage et vérification de Docker
print_info "Démarrage de Docker..."
ensure_docker_service="docker"
if service_exists "$ensure_docker_service"; then
    run_cmd "Activation et démarrage de Docker..." sudo systemctl enable --now "$ensure_docker_service"
else
    print_warning "Le service Docker n'est pas disponible. Vérifiez l'installation."
fi
check_service "docker"

# Lancement des conteneurs Docker
print_info "Lancement des conteneurs Docker (Juice Shop, Mutillidae)..."
# Arrêter les conteneurs s'ils existent déjà pour éviter les conflits
sudo docker stop juice mutillidae 2>/dev/null || true
sudo docker rm juice mutillidae 2>/dev/null || true

sudo docker run -d --name juice -p 3000:3000 bkimminich/juice-shop
sudo docker run -d --name mutillidae -p 8081:80 citizenstig/nowasp

# Vérification des conteneurs
print_info "Vérification des conteneurs Docker..."
if [ "$(sudo docker inspect -f '{{.State.Running}}' juice)" == "true" ]; then
    print_success "Le conteneur 'juice' est en cours d'exécution sur le port 3000."
else
    print_error "Le conteneur 'juice' n'a pas pu démarrer."
fi

if [ "$(sudo docker inspect -f '{{.State.Running}}' mutillidae)" == "true" ]; then
    print_success "Le conteneur 'mutillidae' est en cours d'exécution sur le port 8081."
else
    print_error "Le conteneur 'mutillidae' n'a pas pu démarrer."
fi

# Résumé final
echo "-----------------------------------------------------"
print_success "Configuration de la machine victime terminée !"
echo "-----------------------------------------------------"
print_info "Résumé des services et points d'accès :"
echo -e "  - SSH (Port 22)       : ${YELLOW}Utilisateurs 'testuser'/'Password123' et 'admin'/'admin'${NC}"
echo -e "  - FTP (Port 21)       : ${YELLOW}Accès anonyme (upload)${NC}"
echo -e "  - Telnet (Port 23)    : ${YELLOW}Accès root sans chiffrement via inetd${NC}"
echo -e "  - TFTP (Port 69/UDP)  : ${YELLOW}Accès anonyme lecture/écriture${NC}"
echo -e "  - Web (Port 80)       : ${YELLOW}DVWA, phpMyAdmin${NC}"
echo -e "  - Samba (Ports 139/445): ${YELLOW}Partage public anonyme${NC}"
echo -e "  - MariaDB (Port 3306) : ${YELLOW}Utilisateurs 'test'/'test' et 'readwrite'/'readwrite'${NC}"
echo -e "  - SNMP (Port 161/UDP) : ${YELLOW}Communauté 'public' exposée${NC}"
echo -e "  - NFS (Port 2049)     : ${YELLOW}Export root no_root_squash${NC}"
echo -e "  - Rsync (Port 873)    : ${YELLOW}Module public en écriture${NC}"
echo -e "  - Redis (Port 6379)   : ${YELLOW}Aucun mot de passe, accessible depuis l'extérieur${NC}"
echo -e "  - Juice Shop (Port 3000) : ${YELLOW}Application web vulnérable${NC}"
echo -e "  - Mutillidae (Port 8081) : ${YELLOW}Application web vulnérable${NC}"
echo "-----------------------------------------------------"
print_info "N'oubliez pas de trouver l'IP de cette machine avec 'ip a' pour commencer vos tests !"

exit 0