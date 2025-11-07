# Penetration Testing Lab - Automated Setup & Attack Simulator

## Table of Contents
1. [Introduction](#introduction)
2. [Architecture Overview](#architecture-overview)
3. [Services & Vulnerabilities](#services--vulnerabilities)
4. [Installation & Usage](#installation--usage)
5. [Attack Simulation Process](#attack-simulation-process)
6. [Detailed Service Explanations](#detailed-service-explanations)
7. [Security Warning](#security-warning)

---

## Introduction

This project provides an **automated penetration testing lab** that sets up a vulnerable victim machine and an attacker machine for security testing and learning purposes. The lab includes multiple intentionally vulnerable services that simulate real-world security misconfigurations.

### What This Lab Provides

- **Victim Machine Setup**: Automatically configures a Linux system with 11+ vulnerable services
- **Attacker Machine Tools**: Installs and configures penetration testing tools on Kali Linux
- **Automated Attack Simulation**: Runs comprehensive attacks against all configured vulnerabilities
- **Educational Purpose**: Learn about common security misconfigurations and exploitation techniques

### **IMPORTANT SECURITY WARNING**

**NEVER use this configuration on production systems or any system connected to the internet without proper isolation!** These scripts intentionally create security vulnerabilities for educational purposes only.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    VICTIM MACHINE                            │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ SSH (22)     │  │ FTP (21)     │  │ Telnet (23)  │      │
│  │ Weak creds   │  │ Anonymous    │  │ No encryption│      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ Samba (445)  │  │ MariaDB(3306)│  │ SNMP (161)   │      │
│  │ Public share │  │ No password  │  │ Public comm  │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ NFS (2049)   │  │ Rsync (873)  │  │ Redis (6379) │      │
│  │ No root sq   │  │ Anonymous    │  │ No auth      │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ Web (80)     │  │ TFTP (69)     │  │ Docker Apps  │      │
│  │ DVWA/PMA     │  │ Anonymous    │  │ Juice Shop   │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
└─────────────────────────────────────────────────────────────┘
                            ↕ Network
┌─────────────────────────────────────────────────────────────┐
│                  ATTACKER MACHINE (Kali)                     │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ Nmap         │  │ Hydra        │  │ Gobuster     │      │
│  │ Reconnaissance│  │ Brute-force  │  │ Web fuzzing  │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ SQLMap       │  │ Metasploit   │  │ SMB/Rsync    │      │
│  │ SQL injection│  │ Exploitation │  │ Enum tools   │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
└─────────────────────────────────────────────────────────────┘
```

---

## 🔧 Services & Vulnerabilities

### 1. **SSH (Port 22)**
- **Service**: Secure Shell - Remote access protocol
- **Vulnerability**: 
  - Root login enabled (`PermitRootLogin yes`)
  - Password authentication enabled
  - Weak credentials: `admin/admin` and `testuser/Password123`
- **Why It's Vulnerable**: 
  - Root login allows direct administrative access
  - Weak passwords are easily brute-forced
  - No key-based authentication enforced
- **Attack Vector**: Brute-force password attacks using Hydra

### 2. **FTP - vsftpd (Port 21)**
- **Service**: File Transfer Protocol - File sharing service
- **Vulnerability**:
  - Anonymous access enabled with write permissions
  - `anon_upload_enable=YES` and `anon_mkdir_write_enable=YES`
- **Why It's Vulnerable**:
  - Anyone can upload files without authentication
  - Can be used to upload malicious scripts or backdoors
  - No access control on uploaded files
- **Attack Vector**: Anonymous login and file upload

### 3. **Telnet (Port 23)**
- **Service**: Unencrypted remote terminal access
- **Vulnerability**:
  - No encryption (traffic sent in plaintext)
  - Root access possible
  - No authentication required
- **Why It's Vulnerable**:
  - All credentials and commands are visible in network traffic
  - Susceptible to man-in-the-middle attacks
  - Obsolete and insecure protocol
- **Attack Vector**: Banner grabbing, credential interception

### 4. **TFTP (Port 69/UDP)**
- **Service**: Trivial File Transfer Protocol - Simple file transfer
- **Vulnerability**:
  - No authentication mechanism
  - Write access enabled for anonymous users
- **Why It's Vulnerable**:
  - Designed without security features
  - Can be used to upload malicious files
  - Often used for network boot, exposing sensitive files
- **Attack Vector**: Anonymous file upload/download

### 5. **Samba/SMB (Ports 139/445)**
- **Service**: Server Message Block - File and printer sharing
- **Vulnerability**:
  - Public share with guest access (`guest ok = yes`)
  - Write permissions enabled (`read only = no`)
  - Permissive file permissions (0777)
- **Why It's Vulnerable**:
  - Anyone can access and modify files
  - Can be used for lateral movement in networks
  - Often contains sensitive data
- **Attack Vector**: Anonymous share enumeration and file access

### 6. **MariaDB/MySQL (Port 3306)**
- **Service**: Database server
- **Vulnerability**:
  - Root user with empty password
  - Remote access enabled for users `test/test` and `readwrite/readwrite`
  - Full privileges granted to remote users
- **Why It's Vulnerable**:
  - Complete database compromise possible
  - Can lead to data exfiltration or modification
  - Often contains sensitive application data
- **Attack Vector**: Direct database connection, SQL injection

### 7. **SNMP (Port 161/UDP)**
- **Service**: Simple Network Management Protocol - Network monitoring
- **Vulnerability**:
  - Default community string `public` exposed
  - Accessible from any IP (0.0.0.0/0)
  - No authentication required
- **Why It's Vulnerable**:
  - Reveals system information, network topology
  - Can expose running processes, network interfaces
  - Often used for reconnaissance
- **Attack Vector**: SNMP walk to enumerate system information

### 8. **NFS (Port 2049)**
- **Service**: Network File System - Network file sharing
- **Vulnerability**:
  - Export configured with `no_root_squash`
  - World-writable permissions
  - No authentication required
- **Why It's Vulnerable**:
  - `no_root_squash` allows root access from remote
  - Can be mounted and used to gain root privileges
  - Critical privilege escalation vector
- **Attack Vector**: Mount export and create SUID binaries

### 9. **Rsync (Port 873)**
- **Service**: Remote synchronization tool
- **Vulnerability**:
  - Anonymous module with write access
  - No authentication configured
  - `read only = no`
- **Why It's Vulnerable**:
  - Can be used to exfiltrate or modify files
  - Often contains backups or sensitive data
  - No access logging
- **Attack Vector**: Module enumeration and file synchronization

### 10. **Redis (Port 6379)**
- **Service**: In-memory data structure store
- **Vulnerability**:
  - No password authentication
  - Bound to all interfaces (0.0.0.0)
  - Protected mode disabled
- **Why It's Vulnerable**:
  - Can be used to store/retrieve arbitrary data
  - Can lead to remote code execution via Lua scripts
  - Often contains cached sensitive data
- **Attack Vector**: Direct connection and data manipulation

### 11. **Apache Web Server (Port 80)**
- **Service**: HTTP web server
- **Vulnerabilities**:
  - **DVWA (Damn Vulnerable Web Application)**: Intentionally vulnerable web app
  - **phpMyAdmin**: Database management interface
  - Default/weak configurations
- **Why It's Vulnerable**:
  - DVWA contains multiple web vulnerabilities (SQL injection, XSS, etc.)
  - phpMyAdmin can be exploited if misconfigured
  - Web applications are common attack vectors
- **Attack Vector**: Web fuzzing, SQL injection, XSS

### 12. **Docker Applications**
- **Services**:
  - **Juice Shop (Port 3000)**: Modern vulnerable web application
  - **Mutillidae (Port 8081)**: OWASP vulnerable web application
- **Vulnerability**: Intentionally vulnerable applications for training
- **Why It's Vulnerable**: Designed to teach web application security
- **Attack Vector**: Various web application attacks

---

## Installation & Usage

### Prerequisites

**Victim Machine:**
- Ubuntu/Debian-based Linux distribution
- Root or sudo access
- Internet connection

**Attacker Machine:**
- Kali Linux (recommended) or Debian-based system
- Root or sudo access
- Internet connection

### Quick Start

1. **Clone or download this repository:**
   ```bash
   cd /path/to/0xsh
   chmod +x main.sh
   ```

2. **Run the main script:**
   ```bash
   ./main.sh
   ```

3. **Choose your mode:**
   - **Option 1**: Victim Machine Setup
   - **Option 2**: Attacker Machine Setup

### Victim Machine Setup

When you select option 1, the script will:

1. **Install Tools** (`install_tools.sh`):
   - Installs Apache, PHP, MariaDB
   - Installs vulnerable services (vsftpd, Samba, Telnet, etc.)
   - Installs Docker and vulnerable web applications
   - Installs phpMyAdmin

2. **Configure Services** (`configure_services.sh`):
   - Configures each service with intentional vulnerabilities
   - Creates weak user accounts
   - Sets up vulnerable configurations
   - Backs up original configurations

3. **Start & Verify** (`run_and_verify.sh`):
   - Starts all services
   - Enables services to start on boot
   - Verifies services are running
   - Displays summary of all exposed services

**Example Output:**
```
[SUCCESS] SSH configuré.
[SUCCESS] vsftpd configuré.
[SUCCESS] MariaDB configuré.
...
[SUCCESS] Tous les services ont été configurés avec succès.
```

### Attacker Machine Setup

When you select option 2, the script will:

1. **Prompt for Victim IP:**
   ```
   Entrez l'adresse IP de la machine victime: 192.168.1.100
   ```

2. **Check/Install Tools** (`attack/setup.sh`):
   - Installs Nmap, Hydra, Gobuster, SQLMap
   - Installs SMB, SNMP, NFS, Redis clients
   - Installs Metasploit Framework
   - Sets up wordlists (rockyou.txt)

3. **Launch Attack Simulation** (`attack/simulator.sh`):
   - Runs comprehensive attacks against all services
   - Saves results in `attack_results/` directory
   - Generates summary report

---

## Attack Simulation Process

The attack simulator (`attack/simulator.sh`) performs a complete penetration test in 15 steps:

### Step 1: Reconnaissance (Nmap)
- **Tool**: `nmap -sS -sV -p- -T4`
- **Purpose**: Discovers all open ports and service versions
- **Output**: `nmap_full_scan.txt`
- **What it finds**: All exposed services and their versions

### Step 2: SSH Brute-Force
- **Tool**: `hydra -l admin -P rockyou.txt ssh://TARGET`
- **Purpose**: Attempts to crack SSH password for 'admin' user
- **Output**: `hydra_ssh_output.txt`
- **Success**: Finds credentials `admin:admin`

### Step 3: FTP Anonymous Access
- **Tool**: `curl --user anonymous:anonymous ftp://TARGET/`
- **Purpose**: Tests anonymous FTP access and file upload
- **Output**: `ftp_listing.txt`
- **Success**: Lists files and uploads test file

### Step 4: SMB Enumeration
- **Tool**: `smbclient -L //TARGET/ -N`
- **Purpose**: Enumerates SMB shares and accesses public share
- **Output**: `smb_shares.txt`, `smb_public_listing.txt`
- **Success**: Lists and accesses public share

### Step 5: Telnet Banner Grabbing
- **Tool**: `telnet TARGET 23`
- **Purpose**: Retrieves service banner and tests connectivity
- **Output**: `telnet_banner.txt`
- **Success**: Captures banner information

### Step 6: TFTP File Upload
- **Tool**: `atftp --trace TARGET -p -l file -r filename`
- **Purpose**: Tests anonymous TFTP file upload
- **Output**: `tftp_result.txt`
- **Success**: Uploads file without authentication

### Step 7: SNMP Enumeration
- **Tool**: `snmpwalk -v2c -c public TARGET`
- **Purpose**: Enumerates system information via SNMP
- **Output**: `snmp_public.txt`
- **Success**: Retrieves system details

### Step 8: NFS Export Enumeration
- **Tool**: `showmount -e TARGET` and `mount`
- **Purpose**: Lists NFS exports and attempts to mount
- **Output**: `nfs_exports.txt`, `nfs_listing.txt`
- **Success**: Mounts and lists NFS share

### Step 9: Rsync Module Enumeration
- **Tool**: `rsync rsync://TARGET/` and `rsync -av`
- **Purpose**: Lists available modules and syncs public module
- **Output**: `rsync_modules.txt`
- **Success**: Downloads files from rsync module

### Step 10: Redis Connection
- **Tool**: `redis-cli -h TARGET INFO`
- **Purpose**: Tests unauthenticated Redis access
- **Output**: `redis_info.txt`
- **Success**: Retrieves Redis server information

### Step 11: MariaDB Authentication
- **Tool**: `mysql -h TARGET -u root --password=''`
- **Purpose**: Tests database access with weak credentials
- **Output**: `mariadb_test.txt`
- **Success**: Connects with root (empty) and test/test

### Step 12: Web Fuzzing
- **Tool**: `gobuster dir -u http://TARGET -w wordlist`
- **Purpose**: Discovers hidden web directories and files
- **Output**: `gobuster_output.txt`
- **Success**: Finds /dvwa, /phpmyadmin, etc.

### Step 13: SQL Injection (DVWA)
- **Tool**: `sqlmap -u http://TARGET/dvwa/login.php --data="..." --dbs`
- **Purpose**: Tests and exploits SQL injection vulnerabilities
- **Output**: `sqlmap_dvwa.txt`, `sqlmap/` directory
- **Success**: Extracts database information

### Step 14: Metasploit Exploitation
- **Tool**: `msfconsole` with vsftpd backdoor exploit
- **Purpose**: Attempts to exploit known vulnerabilities
- **Output**: `msf_vsftpd.txt`
- **Success**: Gains shell access (if vulnerable version)

### Step 15: Web Application Verification
- **Tool**: `curl http://TARGET:3000` and `curl http://TARGET:8081`
- **Purpose**: Verifies Docker applications are accessible
- **Output**: `juice_shop_homepage.html`, `mutillidae_homepage.html`
- **Success**: Confirms applications are running

### Final Report
The script generates a summary report showing:
- Successful attacks
- Warnings (partial success)
- Errors (failed attacks)
- Skipped (missing tools)

---

## Detailed Service Explanations

### SSH (Secure Shell) - Port 22

**What is SSH?**
SSH is a cryptographic network protocol for secure remote login and command execution. It's the standard way to manage Linux servers remotely.

**Normal Configuration:**
- Root login disabled
- Key-based authentication only
- Strong passwords or no password auth
- Limited login attempts

**Vulnerable Configuration:**
```bash
PermitRootLogin yes          # Allows root to login directly
PasswordAuthentication yes   # Allows password login (weaker than keys)
Users: admin/admin, testuser/Password123  # Weak passwords
```

**Attack Process:**
1. Attacker uses Hydra to brute-force passwords
2. Tries common passwords from rockyou.txt wordlist
3. Successfully logs in with `admin:admin`
4. Gains shell access to the system

**Real-World Impact:**
- Complete system compromise
- Can install backdoors, exfiltrate data
- Use as pivot point for lateral movement

---

### FTP (vsftpd) - Port 21

**What is FTP?**
File Transfer Protocol for transferring files between client and server.

**Normal Configuration:**
- Anonymous access disabled or read-only
- Authenticated users only
- Upload restrictions
- Logging enabled

**Vulnerable Configuration:**
```bash
anonymous_enable=YES
anon_upload_enable=YES        # Anonymous users can upload
anon_mkdir_write_enable=YES   # Anonymous users can create directories
write_enable=YES
```

**Attack Process:**
1. Attacker connects as `anonymous:anonymous`
2. Lists directory contents
3. Uploads malicious file (e.g., backdoor script)
4. Can potentially execute uploaded files if web server serves FTP directory

**Real-World Impact:**
- Malware distribution
- Data exfiltration
- Website defacement
- Backdoor installation

---

### Telnet - Port 23

**What is Telnet?**
Unencrypted remote terminal protocol (obsolete, replaced by SSH).

**Why It's Dangerous:**
- All traffic in plaintext
- Credentials visible in network captures
- No encryption or authentication

**Attack Process:**
1. Attacker connects to port 23
2. Captures banner information
3. If credentials are used, they're visible in network traffic
4. Can intercept all commands and responses

**Real-World Impact:**
- Credential theft via network sniffing
- Man-in-the-middle attacks
- Complete session hijacking

---

### TFTP (Trivial FTP) - Port 69/UDP

**What is TFTP?**
Simplified FTP protocol without authentication, used for network booting.

**Vulnerable Configuration:**
- No authentication mechanism
- Write access enabled
- Accessible from any network

**Attack Process:**
1. Attacker uses `atftp` to connect
2. Uploads file without any credentials
3. Can download configuration files
4. Can upload malicious files

**Real-World Impact:**
- Configuration file theft
- Malicious file upload
- Network boot manipulation

---

### Samba/SMB - Ports 139/445

**What is SMB?**
Protocol for file and printer sharing, primarily used in Windows networks.

**Vulnerable Configuration:**
```ini
[public]
   path = /srv/samba/public
   guest ok = yes          # No authentication required
   read only = no          # Write access enabled
   create mask = 0777      # Full permissions
```

**Attack Process:**
1. Attacker enumerates shares: `smbclient -L //TARGET/ -N`
2. Accesses public share without credentials
3. Lists and downloads files
4. Uploads files to the share

**Real-World Impact:**
- Sensitive data exposure
- Malware distribution
- Lateral movement in networks
- Data exfiltration

---

### MariaDB/MySQL - Port 3306

**What is MariaDB?**
Open-source relational database management system.

**Vulnerable Configuration:**
```sql
ALTER USER 'root'@'localhost' IDENTIFIED BY '';  -- Empty password
CREATE USER 'test'@'%' IDENTIFIED BY 'test';     -- Weak password, remote access
GRANT ALL ON *.* TO 'test'@'%';                  -- Full privileges
```

**Attack Process:**
1. Attacker connects: `mysql -h TARGET -u root --password=''`
2. Or uses: `mysql -h TARGET -u test -ptest`
3. Lists all databases: `SHOW DATABASES;`
4. Extracts sensitive data
5. Can modify or delete data

**Real-World Impact:**
- Complete database compromise
- Data theft (PII, credentials, etc.)
- Data manipulation or destruction
- SQL injection exploitation

---

### SNMP - Port 161/UDP

**What is SNMP?**
Simple Network Management Protocol for monitoring network devices.

**Vulnerable Configuration:**
```
rocommunity public 0.0.0.0/0  # Public community, accessible from anywhere
```

**Attack Process:**
1. Attacker uses `snmpwalk` with community "public"
2. Enumerates system information (OS, processes, network interfaces)
3. Discovers network topology
4. Identifies potential attack vectors

**Real-World Impact:**
- Information disclosure
- Network reconnaissance
- System fingerprinting
- Attack surface identification

---

### NFS - Port 2049

**What is NFS?**
Network File System for sharing files across networks.

**Vulnerable Configuration:**
```
/srv/nfs/public *(rw,sync,no_root_squash,no_subtree_check)
```
- `no_root_squash`: Remote root user keeps root privileges
- `rw`: Read-write access
- `*`: Accessible from any host

**Attack Process:**
1. Attacker lists exports: `showmount -e TARGET`
2. Mounts the export: `mount -t nfs TARGET:/srv/nfs/public /mnt`
3. Creates SUID binary as root
4. Executes binary to gain root privileges

**Real-World Impact:**
- Privilege escalation to root
- Complete system compromise
- Backdoor installation
- Data exfiltration

---

### Rsync - Port 873

**What is Rsync?**
Remote file synchronization tool, often used for backups.

**Vulnerable Configuration:**
```
[public]
    path = /srv/rsync
    read only = no          # Write access
    auth users =            # No authentication
    secrets file =           # No password file
```

**Attack Process:**
1. Attacker lists modules: `rsync rsync://TARGET/`
2. Syncs public module: `rsync -av rsync://TARGET/public/ ./`
3. Downloads all files from the module
4. Can upload files if write access is enabled

**Real-World Impact:**
- Backup file theft
- Sensitive data exposure
- Configuration file access
- Data exfiltration

---

### Redis - Port 6379

**What is Redis?**
In-memory data structure store, used as database, cache, and message broker.

**Vulnerable Configuration:**
```
bind 0.0.0.0              # Accessible from any IP
protected-mode no          # No protection enabled
# requirepass              # No password set
```

**Attack Process:**
1. Attacker connects: `redis-cli -h TARGET`
2. Executes commands: `INFO`, `KEYS *`, `GET key`
3. Can modify data, flush database
4. Can achieve RCE via Lua scripts in some versions

**Real-World Impact:**
- Data theft (cached credentials, sessions)
- Data manipulation
- Remote code execution (in some versions)
- Denial of service

---

### Apache Web Server - Port 80

**What is Apache?**
Most popular web server software.

**Vulnerable Applications:**

#### DVWA (Damn Vulnerable Web Application)
- Intentionally vulnerable PHP application
- Contains: SQL injection, XSS, CSRF, file upload vulnerabilities
- **Attack**: SQL injection via login form, XSS in user input

#### phpMyAdmin
- Web-based MySQL administration tool
- **Attack**: If misconfigured, can allow database access

**Attack Process:**
1. **Reconnaissance**: `gobuster` finds `/dvwa` and `/phpmyadmin`
2. **SQL Injection**: `sqlmap` exploits DVWA login form
3. **Database Access**: Extracts database structure and data
4. **XSS**: Injects malicious scripts in user input fields

**Real-World Impact:**
- Database compromise
- Session hijacking
- Malware distribution
- Website defacement

---

### Docker Applications

#### Juice Shop (Port 3000)
- Modern vulnerable web application (Node.js)
- Contains OWASP Top 10 vulnerabilities
- **Purpose**: Learn modern web app security

#### Mutillidae (Port 8081)
- OWASP vulnerable web application (PHP)
- Contains various web vulnerabilities
- **Purpose**: Practice web penetration testing

---

## Security Warning

### **CRITICAL WARNINGS**

1. **NEVER deploy on production systems**
2. **NEVER expose to the internet without proper isolation**
3. **Use only in isolated lab environments**
4. **These configurations are intentionally insecure**
5. **Always use in virtual machines or isolated networks**

### Recommended Lab Setup

```
┌─────────────────────────────────────────┐
│     Isolated Network (NAT/VLAN)         │
│  ┌──────────────┐    ┌──────────────┐  │
│  │ Victim VM    │    │ Attacker VM  │  │
│  │ 192.168.1.10 │◄───┤ 192.168.1.20 │  │
│  └──────────────┘    └──────────────┘  │
│         │                    │          │
│         └────────────────────┘          │
│              (No Internet)                │
└─────────────────────────────────────────┘
```

---

## File Structure

```
0xsh/
├── main.sh                    # Main management script
├── install_tools.sh           # Victim: Install all packages
├── configure_services.sh      # Victim: Configure vulnerabilities
├── run_and_verify.sh          # Victim: Start and verify services
├── attack/
│   ├── setup.sh              # Attacker: Install tools
│   └── simulator.sh          # Attacker: Run attack simulation
└── README.md                  # This file
```

---

## Troubleshooting

### Victim Machine Issues

**Services not starting:**
```bash
sudo systemctl status <service-name>
sudo journalctl -u <service-name>
```

**Permission errors:**
```bash
sudo chmod +x *.sh
sudo ./main.sh
```

**Port conflicts:**
```bash
sudo netstat -tulpn | grep <port>
sudo systemctl stop <conflicting-service>
```

### Attacker Machine Issues

**Tools not found:**
```bash
sudo apt update
sudo apt install <tool-name>
```

**Wordlist missing:**
```bash
sudo apt install wordlists seclists
sudo gunzip /usr/share/wordlists/rockyou.txt.gz
```

**Metasploit not working:**
```bash
sudo systemctl start postgresql
sudo msfdb init
```

---

## Learning Resources

- **OWASP Top 10**: https://owasp.org/www-project-top-ten/
- **Nmap Documentation**: https://nmap.org/book/
- **Metasploit Unleashed**: https://www.offensive-security.com/metasploit-unleashed/
- **DVWA**: https://github.com/digininja/DVWA
- **Juice Shop**: https://owasp.org/www-project-juice-shop/

---

## License

This project is for educational purposes only. Use responsibly and only in authorized environments.

---

## Contributing

Feel free to submit issues, fork the repository, and create pull requests for any improvements.

---

## Support

For questions or issues, please open an issue on the repository.

---

**Remember: With great power comes great responsibility. Use these tools ethically and legally!** 🛡️

