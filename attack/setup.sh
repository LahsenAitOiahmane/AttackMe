#!/bin/bash

# ==============================================================================
# Script d'Installation des Outils pour la Machine Attaquante (Kali)
# ==============================================================================

# --- Configuration des couleurs ---
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

# --- Gestion des erreurs et utilitaires ---
handle_error() {
    local exit_code=$?
    print_error "L'installation a échoué à la ligne $1. La commande '$2' a retourné le code $exit_code."
    print_warning "Vérifiez votre connexion Internet et que les dépôts Kali sont corrects (exécutez 'sudo apt update')."
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
        return 0
    fi
    if [ -n "$pkg" ]; then
        ensure_package "$pkg"
        command -v "$cmd" >/dev/null 2>&1
    else
        return 1
    fi
}

ensure_wordlists() {
    local gz="/usr/share/wordlists/rockyou.txt.gz"
    local txt="/usr/share/wordlists/rockyou.txt"
    if [ -f "$txt" ]; then
        print_info "Le wordlist rockyou.txt est déjà disponible."
        return
    fi
    if [ -f "$gz" ]; then
        print_info "Décompression du wordlist rockyou.txt.gz..."
        sudo gunzip -k "$gz"
        return
    fi
    print_warning "Le wordlist rockyou.txt est introuvable. Installation du paquet 'wordlists'."
    ensure_package wordlists
    if [ -f "$gz" ]; then
        print_info "Décompression du wordlist rockyou.txt.gz..."
        sudo gunzip -k "$gz"
    fi
}

trap 'handle_error $LINENO "$BASH_COMMAND"' ERR

# --- Début du script ---
print_info "Début de l'installation des outils d'attaque..."

if [ "$EUID" -ne 0 ]; then
    print_warning "Certaines opérations nécessitent les privilèges root. Le script utilisera sudo lorsque nécessaire."
fi

# Mise à jour de la liste des paquets
run_cmd "Mise à jour des dépôts APT..." sudo apt-get update

# Installation des outils de base
print_info "Vérification et installation des outils de scan, d'exploitation et de post-exploitation..."
BASE_PACKAGES=(
    nmap
    hydra
    gobuster
    dirb
    sqlmap
    curl
    wget
    smbclient
    snmp
    atftp
    telnet
    netcat-openbsd
    nfs-common
    rsync
    redis-tools
    mariadb-client
    mysql-client
    seclists
)

for pkg in "${BASE_PACKAGES[@]}"; do
    ensure_package "$pkg"
done

ensure_wordlists

# Vérification de l'installation de Metasploit (généralement pré-installé sur Kali)
if ! ensure_command msfconsole metasploit-framework; then
    print_warning "Metasploit Framework (msfconsole) est absent. Téléchargement via le script officiel..."
    tmp_script=$(mktemp)
    run_cmd "Téléchargement du script d'installation Metasploit..." curl -fsSL https://raw.githubusercontent.com/rapid7/metasploit-omnibus/master/config/templates/metasploit-framework-wrappers/msfupdate.erb -o "$tmp_script"
    run_cmd "Installation de Metasploit..." sudo bash "$tmp_script"
    rm -f "$tmp_script"
else
    print_success "Metasploit Framework est déjà installé."
fi

print_success "Tous les outils nécessaires ont été installés avec succès."
print_info "Vous pouvez maintenant lancer le script d'attaque : ./attack_simulator.sh <IP_VICTIME>"
exit 0