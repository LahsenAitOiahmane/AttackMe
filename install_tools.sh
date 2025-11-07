#!/bin/bash

# ==============================================================================
# Script 1: Installation des Outils et Services pour la Machine Victime
# ==============================================================================

# --- Configuration des couleurs pour la sortie ---
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export NC='\033[0m' # No Color

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

# --- Fonctions utilitaires ---
# La fonction sera appelée si une commande échoue
handle_error() {
    local exit_code=$?
    print_error "Le script a échoué à la ligne $1. La commande '$2' a retourné le code $exit_code."
    print_warning "Solution possible : Vérifiez votre connexion Internet ou les dépôts APT. Essayez de 'sudo apt update'."
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

ensure_package() {
    local pkg="$1"
    if dpkg -s "$pkg" >/dev/null 2>&1; then
        print_info "Le paquet '$pkg' est déjà installé."
        return 0
    fi
    run_cmd "Installation du paquet '$pkg'..." sudo apt-get install -y "$pkg"
}

ensure_command() {
    local cmd="$1"
    local pkg="$2"
    if command -v "$cmd" >/dev/null 2>&1; then
        print_info "La commande '$cmd' est déjà disponible."
        return 0
    fi
    if [ -n "$pkg" ]; then
        ensure_package "$pkg"
    else
        print_warning "La commande '$cmd' est introuvable et aucun paquet n'a été spécifié."
        return 1
    fi
}

trap 'handle_error $LINENO "$BASH_COMMAND"' ERR

# --- Début du script ---
print_info "Début de l'installation des outils et services..."

if [ "$EUID" -ne 0 ]; then
    print_warning "Certaines opérations nécessitent les privilèges root. Le script va utiliser sudo lorsque nécessaire."
fi

# Mise à jour de la liste des paquets
run_cmd "Mise à jour des dépôts APT..." sudo apt-get update

# Installation de la pile LAMP, SSH, FTP, Samba, Git, etc.
print_info "Vérification et installation des paquets nécessaires (LAMP, services vulnérables, outils)..."
BASE_PACKAGES=(
    apache2
    php
    php-mysqli
    libapache2-mod-php
    mariadb-server
    vsftpd
    samba
    git
    unzip
    inetutils-telnetd
    atftpd
    snmpd
    nfs-kernel-server
    rsync
    redis-server
    inetutils-inetd
)

for pkg in "${BASE_PACKAGES[@]}"; do
    ensure_package "$pkg"
done

# Installation de Docker
ensure_package docker.io

# Installation de phpMyAdmin
print_info "Installation de phpMyAdmin..."
# Pré-configuration pour phpMyAdmin pour éviter les prompts interactifs
sudo debconf-set-selections <<< "phpmyadmin phpmyadmin/dbconfig-install boolean true"
sudo debconf-set-selections <<< "phpmyadmin phpmyadmin/app-password-confirm password "
sudo debconf-set-selections <<< "phpmyadmin phpmyadmin/mysql/admin-pass password "
sudo debconf-set-selections <<< "phpmyadmin phpmyadmin/mysql/app-pass password "
ensure_package phpmyadmin

print_success "Tous les outils et services ont été installés avec succès."
exit 0