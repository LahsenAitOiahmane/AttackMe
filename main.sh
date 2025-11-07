#!/bin/bash

# ==============================================================================
# Script Principal : Gestionnaire de Machine Victime et Attaquante
# ==============================================================================

# --- Configuration des couleurs ---
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export CYAN='\033[0;36m'
export NC='\033[0m'

# --- Fonctions pour l'affichage ---
print_header() {
    echo -e "\n${CYAN}========================================${NC}"
    echo -e "${CYAN} $1 ${NC}"
    echo -e "${CYAN}========================================${NC}\n"
}

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
check_script_exists() {
    local script="$1"
    if [ ! -f "$script" ]; then
        print_error "Le script '$script' est introuvable."
        return 1
    fi
    if [ ! -x "$script" ]; then
        print_warning "Le script '$script' n'est pas exécutable. Tentative de correction..."
        chmod +x "$script" || {
            print_error "Impossible de rendre '$script' exécutable."
            return 1
        }
    fi
    return 0
}

run_script() {
    local script="$1"
    local description="$2"
    shift 2
    local args=("$@")
    
    if ! check_script_exists "$script"; then
        return 1
    fi
    
    print_info "Exécution: $description"
    print_warning "Script: $script ${args[*]}"
    echo ""
    
    if bash "$script" "${args[@]}"; then
        print_success "$description terminé avec succès."
        return 0
    else
        local exit_code=$?
        print_error "$description a échoué avec le code $exit_code."
        return $exit_code
    fi
}

prompt_yes_no() {
    local prompt="$1"
    local default="${2:-n}"
    local response
    
    while true; do
        if [ "$default" = "y" ]; then
            echo -ne "${YELLOW}$prompt [Y/n]: ${NC}"
        else
            echo -ne "${YELLOW}$prompt [y/N]: ${NC}"
        fi
        read -r response
        response="${response:-$default}"
        case "$response" in
            [Yy]|[Yy][Ee][Ss]) return 0 ;;
            [Nn]|[Nn][Oo]) return 1 ;;
            *) print_warning "Réponse invalide. Utilisez 'y' ou 'n'." ;;
        esac
    done
}

prompt_ip() {
    local prompt="$1"
    local ip
    
    while true; do
        echo -ne "${YELLOW}$prompt: ${NC}"
        read -r ip
        if [ -z "$ip" ]; then
            print_warning "L'adresse IP ne peut pas être vide."
            continue
        fi
        # Validation basique de l'adresse IP
        if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]] || [[ $ip =~ ^[a-zA-Z0-9.-]+$ ]]; then
            echo "$ip"
            return 0
        else
            print_warning "Format d'adresse IP invalide. Réessayez."
        fi
    done
}

# --- Début du script ---
clear
print_header "GESTIONNAIRE DE MACHINE VICTIME ET ATTAQUANTE"

# Déterminer le répertoire du script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR" || {
    print_error "Impossible de changer vers le répertoire du script."
    exit 1
}

# Menu principal
echo -e "${CYAN}Choisissez le mode d'opération :${NC}"
echo -e "  ${GREEN}1${NC}) Machine Victime (configuration des services vulnérables)"
echo -e "  ${GREEN}2${NC}) Machine Attaquante (simulation d'attaque)"
echo ""
echo -ne "${YELLOW}Votre choix [1/2]: ${NC}"
read -r mode_choice

case "$mode_choice" in
    1)
        # ======================================================================
        # MODE VICTIME
        # ======================================================================
        print_header "MODE VICTIME - CONFIGURATION DES SERVICES VULNÉRABLES"
        
        print_warning "ATTENTION : Ce script va configurer des services vulnérables sur cette machine."
        print_warning "N'utilisez PAS cette configuration sur un système de production !"
        echo ""
        
        if ! prompt_yes_no "Voulez-vous continuer ?" "n"; then
            print_info "Opération annulée par l'utilisateur."
            exit 0
        fi
        
        # Vérification des privilèges
        if [ "$EUID" -ne 0 ]; then
            print_warning "Certaines opérations nécessitent les privilèges root."
            if ! prompt_yes_no "Voulez-vous continuer avec sudo ?" "y"; then
                print_info "Opération annulée."
                exit 0
            fi
        fi
        
        # Étape 1 : Installation des outils
        print_header "ÉTAPE 1/3 : INSTALLATION DES OUTILS"
        if ! run_script "./install_tools.sh" "Installation des outils et services"; then
            print_error "L'installation des outils a échoué. Arrêt du processus."
            exit 1
        fi
        
        echo ""
        if ! prompt_yes_no "Passer à la configuration des services ?" "y"; then
            print_info "Configuration des services annulée."
            exit 0
        fi
        
        # Étape 2 : Configuration des services
        print_header "ÉTAPE 2/3 : CONFIGURATION DES SERVICES VULNÉRABLES"
        if ! run_script "./configure_services.sh" "Configuration des services vulnérables"; then
            print_error "La configuration des services a échoué. Arrêt du processus."
            exit 1
        fi
        
        echo ""
        if ! prompt_yes_no "Passer au démarrage et à la vérification des services ?" "y"; then
            print_info "Démarrage des services annulé."
            exit 0
        fi
        
        # Étape 3 : Démarrage et vérification
        print_header "ÉTAPE 3/3 : DÉMARRAGE ET VÉRIFICATION DES SERVICES"
        if ! run_script "./run_and_verify.sh" "Démarrage et vérification des services"; then
            print_error "Le démarrage des services a échoué."
            exit 1
        fi
        
        print_header "CONFIGURATION VICTIME TERMINÉE"
        print_success "Tous les services vulnérables ont été configurés et démarrés."
        print_info "Notez l'adresse IP de cette machine avec 'ip a' pour les tests d'attaque."
        ;;
        
    2)
        # ======================================================================
        # MODE ATTAQUANT
        # ======================================================================
        print_header "MODE ATTAQUANT - SIMULATION D'ATTAQUE"
        
        # Demander l'adresse IP de la victime
        echo ""
        VICTIM_IP=$(prompt_ip "Entrez l'adresse IP de la machine victime")
        
        print_info "Machine victime ciblée : $VICTIM_IP"
        echo ""
        
        # Vérifier si les outils sont installés
        if ! command -v nmap &>/dev/null || ! command -v hydra &>/dev/null; then
            print_warning "Certains outils d'attaque semblent manquants."
            if prompt_yes_no "Voulez-vous installer/mettre à jour les outils d'attaque ?" "y"; then
                print_header "INSTALLATION DES OUTILS D'ATTAQUE"
                if ! run_script "./attack/setup.sh" "Installation des outils d'attaque"; then
                    print_error "L'installation des outils a échoué."
                    if ! prompt_yes_no "Continuer quand même avec l'attaque ?" "n"; then
                        exit 1
                    fi
                fi
            fi
        else
            print_success "Les outils d'attaque semblent être installés."
            if prompt_yes_no "Voulez-vous réinstaller/mettre à jour les outils d'attaque ?" "n"; then
                print_header "INSTALLATION DES OUTILS D'ATTAQUE"
                run_script "./attack/setup.sh" "Installation des outils d'attaque" || true
            fi
        fi
        
        echo ""
        print_warning "Prêt à lancer la simulation d'attaque contre $VICTIM_IP"
        print_warning "Cette opération peut prendre du temps selon la configuration réseau."
        echo ""
        
        if ! prompt_yes_no "Lancer la simulation d'attaque maintenant ?" "y"; then
            print_info "Simulation d'attaque annulée."
            exit 0
        fi
        
        # Lancer la simulation d'attaque
        print_header "LANCEMENT DE LA SIMULATION D'ATTAQUE"
        if ! run_script "./attack/simulator.sh" "Simulation d'attaque contre $VICTIM_IP" "$VICTIM_IP"; then
            print_error "La simulation d'attaque a rencontré des erreurs."
            print_info "Vérifiez les fichiers de résultats dans le dossier 'attack_results/' pour plus de détails."
            exit 1
        fi
        
        print_header "SIMULATION D'ATTAQUE TERMINÉE"
        print_success "La simulation d'attaque est terminée."
        print_info "Consultez les fichiers de résultats dans 'attack_results/' pour analyser les résultats."
        ;;
        
    *)
        print_error "Choix invalide. Utilisez '1' pour Victime ou '2' pour Attaquant."
        exit 1
        ;;
esac

exit 0

