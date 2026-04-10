#!/bin/bash
#==============================================================================
# KALI LINUX TOOLS INSTALLER FOR UBUNTU 24.04
#==============================================================================
# Installs ALL Kali Linux tools organized by category
# on an Ubuntu 24.04 LTS system, using alternative methods when
# packages are not available in the official Ubuntu repositories.
#
# USAGE:
#   chmod +x install-kali-tools.sh
#   sudo ./install-kali-tools.sh
#
# REQUIREMENTS:
#   - Ubuntu 24.04 LTS (Noble Numbat) with internet access
#   - Run as root (sudo)
#   - Minimum 20GB of free disk space
#   - Stable internet connection
#
# INSTALLED CATEGORIES:
#   Information Gathering, Vulnerability Analysis, Web App Analysis,
#   Database Assessment, Password Attacks, Wireless Attacks,
#   Reverse Engineering, Exploitation, Sniffing & Spoofing,
#   Post Exploitation, Forensics, Reporting, Social Engineering,
#   System Services, C2 Frameworks, Wordlists, SDR/RFID, and more.
#
# OUTPUT:
#   Full log:      ~/kali-tools-install.log
#   Errors:        ~/kali-tools-failed.log
#==============================================================================

set +e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Verify root before anything
if [ "$EUID" -ne 0 ]; then
    echo "Run as root: sudo ./install-kali-tools.sh"
    exit 1
fi

# Detect real user (not root)
REAL_USER="${SUDO_USER:-$(logname 2>/dev/null || echo $USER)}"
REAL_HOME="/home/$REAL_USER"

LOG_FILE="$REAL_HOME/kali-tools-install.log"
FAILED_FILE="$REAL_HOME/kali-tools-failed.log"

log() { echo -e "${GREEN}[+]${NC} $1" | tee -a "$LOG_FILE"; }
warn() { echo -e "${YELLOW}[!]${NC} $1" | tee -a "$LOG_FILE"; }
error() { echo -e "${RED}[-]${NC} $1" | tee -a "$LOG_FILE" "$FAILED_FILE"; }
section() { echo -e "\n${CYAN}=== $1 ===${NC}" | tee -a "$LOG_FILE"; }

export GIT_TERMINAL_PROMPT=0
export GIT_ASKPASS=/bin/true

echo "" > "$LOG_FILE"
echo "" > "$FAILED_FILE"

log "Installation started: $(date)"
log "System: $(lsb_release -ds) - Kernel: $(uname -r)"

#==============================================================================
section "PREREQUISITE CHECKS"
#==============================================================================

# Check internet connectivity
log "Checking internet connectivity..."
if ! ping -c 2 -W 5 8.8.8.8 &>/dev/null && ! ping -c 2 -W 5 1.1.1.1 &>/dev/null; then
    error "No internet connectivity. Aborting."
    exit 1
fi
log "Connectivity OK"

# Check disk space (warn if < 20GB free)
FREE_SPACE_KB=$(df --output=avail "$REAL_HOME" | tail -1 | tr -d ' ')
FREE_SPACE_GB=$((FREE_SPACE_KB / 1024 / 1024))
if [ "$FREE_SPACE_GB" -lt 20 ]; then
    warn "Free disk space: ${FREE_SPACE_GB}GB - at least 20GB free recommended"
fi
log "Free disk space: ${FREE_SPACE_GB}GB"

# Check/generate SSH key for git operations
if [ ! -f "$REAL_HOME/.ssh/id_ed25519" ] && [ ! -f "$REAL_HOME/.ssh/id_rsa" ]; then
    log "No SSH key found, generating a new one..."
    sudo -u "$REAL_USER" mkdir -p "$REAL_HOME/.ssh"
    sudo -u "$REAL_USER" ssh-keygen -t ed25519 -f "$REAL_HOME/.ssh/id_ed25519" -N "" -q
    log "SSH key generated at $REAL_HOME/.ssh/id_ed25519"
fi

#==============================================================================
section "STEP 0: SYSTEM PREPARATION"
#==============================================================================

export DEBIAN_FRONTEND=noninteractive

apt-get update -y > /dev/null 2>&1
{ apt-get install -y software-properties-common apt-transport-https \
    curl wget git unzip p7zip-full build-essential gcc g++ make cmake \
    python3 python3-pip python3-venv python3-dev \
    ruby ruby-dev rubygems \
    golang-go \
    default-jdk default-jre \
    php php-cli \
    nodejs npm \
    perl \
    nasm \
    clang llvm \
    gcc-mingw-w64 \
    dotnet-sdk-8.0 \
    subversion \
    pipx \
    libssl-dev libffi-dev libxml2-dev libxslt1-dev zlib1g-dev libcurl4-openssl-dev \
    libpcap-dev libpq-dev libsqlite3-dev libgmp-dev \
    autoconf automake libtool pkg-config \
    tmux screen jq tree net-tools \
    vim nano \
    pv xclip xdotool \
    imagemagick ghostscript graphviz \
    gparted gdisk \
    htop lsof sysstat smartmontools \
    dos2unix figlet \
    unrar zip squashfs-tools \
    iproute2 ethtool vlan \
    iptables nftables \
    easy-rsa opensc \
    ftp telnet rdesktop \
    minicom \
    axel; } > /dev/null 2>&1

# Ensure python3-venv is installed before creating venv
log "Checking python3-venv..."
apt-get install -y python3.12-venv python3-venv > /dev/null 2>&1 || true

# Create venv for Python tools
VENV="$REAL_HOME/pentest-venv"
if [ ! -d "$VENV" ] || [ ! -f "$VENV/bin/pip" ]; then
    rm -rf "$VENV" 2>/dev/null
    log "Creating virtual environment at $VENV..."
    sudo -u "$REAL_USER" python3 -m venv "$VENV"
    if [ ! -f "$VENV/bin/pip" ]; then
        error "Could not create Python virtual environment. Install python3.12-venv manually."
        exit 1
    fi
fi

# Verify pip exists before proceeding
PIP="$VENV/bin/pip"
if [ ! -f "$PIP" ]; then
    error "pip not found at $VENV/bin/pip. The venv may be corrupted."
    exit 1
fi
$PIP install --quiet --no-warn-script-location --upgrade pip setuptools wheel > /dev/null 2>&1

# Configure GOPATH
export GOPATH="$REAL_HOME/go"
export PATH="$PATH:$GOPATH/bin:/usr/local/go/bin"
mkdir -p "$GOPATH/bin"

# Directory for git tools
TOOLS_DIR="$REAL_HOME/tools"
mkdir -p "$TOOLS_DIR"
chown "$REAL_USER:$REAL_USER" "$TOOLS_DIR"

# Directory for wordlists
WORDLISTS_DIR="$REAL_HOME/wordlists"
mkdir -p "$WORDLISTS_DIR"

#==============================================================================
section "STEP 1: INFORMATION GATHERING"
#==============================================================================

log "Installing reconnaissance tools (apt)..."
{ apt-get install -y \
    nmap masscan arp-scan fping hping3 arping p0f \
    dnsrecon dnsenum dnsmap dnsutils dnstracer whois \
    nbtscan smbclient samba-common-bin \
    snmp onesixtyone braa \
    traceroute tcptraceroute \
    whatweb wafw00f sslscan \
    dmitry netmask \
    libimage-exiftool-perl \
    ldap-utils \
    fierce \
    netdiscover \
    ike-scan \
    bind9-dnsutils; } \
    > /dev/null 2>&1 || warn "Some info gathering packages not available"

log "Installing reconnaissance tools (pip)..."
{ $PIP install --quiet --no-warn-script-location \
    shodan censys theharvester \
    dnsrecon sublist3r \
    sslyze \
    knockpy \
    wafw00f \
    sherlock-project; } \
    > /dev/null 2>&1 || { warn "Some info gathering pip packages failed"; echo "pip-info-gathering" >> "$FAILED_FILE"; }

log "Installing Go reconnaissance tools..."
sudo -u "$REAL_USER" bash -c "export GIT_TERMINAL_PROMPT=0; export GOPATH=$GOPATH; export PATH=\$PATH:$GOPATH/bin; \
    go install github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest > /dev/null 2>&1; \
    go install github.com/projectdiscovery/httpx/cmd/httpx@latest > /dev/null 2>&1; \
    go install github.com/projectdiscovery/naabu/v2/cmd/naabu@latest > /dev/null 2>&1; \
    go install github.com/projectdiscovery/dnsx/cmd/dnsx@latest > /dev/null 2>&1; \
    go install github.com/projectdiscovery/tlsx/cmd/tlsx@latest > /dev/null 2>&1; \
    go install github.com/projectdiscovery/asnmap/cmd/asnmap@latest > /dev/null 2>&1; \
    go install github.com/projectdiscovery/mapcidr/cmd/mapcidr@latest > /dev/null 2>&1; \
    go install github.com/projectdiscovery/cdncheck/cmd/cdncheck@latest > /dev/null 2>&1; \
    go install github.com/projectdiscovery/alterx/cmd/alterx@latest > /dev/null 2>&1; \
    go install github.com/projectdiscovery/uncover/cmd/uncover@latest > /dev/null 2>&1; \
    go install github.com/projectdiscovery/cloudlist/cmd/cloudlist@latest > /dev/null 2>&1; \
    go install github.com/owasp-amass/amass/v4/...@master > /dev/null 2>&1; \
    go install github.com/tomnomnom/assetfinder@latest > /dev/null 2>&1; \
    " || warn "Some Go recon tools failed"

#==============================================================================
section "STEP 2: VULNERABILITY ANALYSIS"
#==============================================================================

log "Installing vulnerability scanners..."
{ apt-get install -y \
    nikto lynis \
    afl++ \
    yersinia \
    sipvicious; } \
    > /dev/null 2>&1 || warn "Some vuln analysis packages not available"

{ $PIP install --quiet --no-warn-script-location \
    wfuzz \
    boofuzz \
    vulners; } \
    > /dev/null 2>&1 || true

log "Installing OpenVAS/GVM..."
apt-get install -y gvm > /dev/null 2>&1 || warn "GVM/OpenVAS not available in repos, use Docker: docker run -d -p 443:443 greenbone/community-edition"

log "Installing nuclei..."
sudo -u "$REAL_USER" bash -c "export GIT_TERMINAL_PROMPT=0; export GOPATH=$GOPATH; export PATH=\$PATH:$GOPATH/bin; \
    go install github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest > /dev/null 2>&1" || warn "nuclei failed"

#==============================================================================
section "STEP 3: WEB APPLICATION ANALYSIS"
#==============================================================================

log "Installing web tools (apt)..."
{ apt-get install -y \
    sqlmap nikto \
    dirb gobuster \
    wapiti \
    whatweb \
    cadaver \
    proxychains4 \
    mitmproxy \
    cutycapt \
    parsero \
    urlscan \
    swaks; } > /dev/null 2>&1 || true

log "Installing sendemail..."
# Kali-only (not in Ubuntu repos): smtp-user-enum
apt-get install -y sendemail > /dev/null 2>&1 || warn "sendemail not available in repo"

log "Installing web tools (pip)..."
{ $PIP install --quiet --no-warn-script-location \
    sqlmap \
    dirsearch \
    arjun \
    mitmproxy; } \
    > /dev/null 2>&1 || { warn "Some web pip packages failed"; echo "pip-web" >> "$FAILED_FILE"; }

log "Installing web tools (Go)..."
sudo -u "$REAL_USER" bash -c "export GIT_TERMINAL_PROMPT=0; export GOPATH=$GOPATH; export PATH=\$PATH:$GOPATH/bin; \
    go install github.com/ffuf/ffuf/v2@latest > /dev/null 2>&1; \
    go install github.com/OJ/gobuster/v3@latest > /dev/null 2>&1; \
    go install github.com/projectdiscovery/katana/cmd/katana@latest > /dev/null 2>&1; \
    go install github.com/tomnomnom/httprobe@latest > /dev/null 2>&1; \
    go install github.com/hakluke/hakrawler@latest > /dev/null 2>&1; \
    go install github.com/lc/gau/v2/cmd/gau@latest > /dev/null 2>&1; \
    go install github.com/tomnomnom/waybackurls@latest > /dev/null 2>&1; \
    go install github.com/jaeles-project/gospider@latest > /dev/null 2>&1; \
    go install github.com/hahwul/dalfox/v2@latest > /dev/null 2>&1; \
    " || warn "Some Go web tools failed"

log "Installing WPScan..."
gem install wpscan > /dev/null 2>&1 || warn "wpscan gem failed"

log "Cloning web tools from GitHub..."
cd "$TOOLS_DIR"
[ ! -d "XSStrike" ] && { sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/s0md3v/XSStrike.git > /dev/null 2>&1 || warn "XSStrike clone failed"; }
[ ! -d "Photon" ] && { sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/s0md3v/Photon.git > /dev/null 2>&1 || warn "Photon clone failed"; }
[ ! -d "FinalRecon" ] && { sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/thewhiteh4t/FinalRecon.git > /dev/null 2>&1 || warn "FinalRecon clone failed"; }
[ ! -d "NoSQLMap" ] && { sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/codingo/NoSQLMap.git > /dev/null 2>&1 || warn "NoSQLMap clone failed"; }
[ ! -d "CMSmap" ] && { sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/Dionach/CMSmap.git > /dev/null 2>&1 || warn "CMSmap clone failed"; }

#==============================================================================
section "STEP 4: DATABASE ASSESSMENT"
#==============================================================================

log "Installing database tools..."
{ apt-get install -y \
    sqlmap \
    mdbtools \
    redis-tools \
    postgresql-client; } \
    > /dev/null 2>&1 || warn "Some DB packages not available"

{ $PIP install --quiet --no-warn-script-location \
    mongoaudit pgcli mycli; } \
    > /dev/null 2>&1 || { warn "Some DB pip packages failed"; echo "pip-database" >> "$FAILED_FILE"; }

#==============================================================================
section "STEP 5: PASSWORD ATTACKS"
#==============================================================================

log "Installing password cracking tools..."
{ apt-get install -y \
    john hashcat \
    hydra medusa ncrack \
    ophcrack ophcrack-cli \
    patator \
    fcrackzip pdfcrack rarcrack \
    crunch \
    cewl \
    samdump2 \
    chntpw \
    hashid \
    maskprocessor statsprocessor; } \
    > /dev/null 2>&1 || warn "Some password packages not available"

{ $PIP install --quiet --no-warn-script-location \
    hashid \
    pypykatz \
    lsassy; } \
    > /dev/null 2>&1 || { warn "Some password pip packages failed"; echo "pip-password" >> "$FAILED_FILE"; }

log "Installing evil-winrm and haiti..."
gem install evil-winrm > /dev/null 2>&1 || warn "evil-winrm gem failed"
gem install haiti-hash > /dev/null 2>&1 || warn "haiti gem failed"

log "Installing kerbrute..."
sudo -u "$REAL_USER" bash -c "export GIT_TERMINAL_PROMPT=0; export GOPATH=$GOPATH; \
    go install github.com/ropnop/kerbrute@latest > /dev/null 2>&1" || warn "kerbrute failed"

#==============================================================================
section "STEP 6: WIRELESS ATTACKS"
#==============================================================================

log "Installing wireless tools..."
{ apt-get install -y \
    aircrack-ng \
    wifite \
    reaver bully \
    pixiewps \
    cowpatty \
    mdk4 \
    macchanger \
    bluez \
    ubertooth \
    gnuradio gqrx-sdr \
    hackrf rtl-sdr \
    multimon-ng \
    iw wavemon wireless-regdb wireless-tools \
    hcxtools hcxdumptool; } \
    > /dev/null 2>&1 || warn "Some wireless packages not available"

log "Cloning advanced wireless tools..."
cd "$TOOLS_DIR"
[ ! -d "fluxion" ] && { sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/FluxionNetwork/fluxion.git > /dev/null 2>&1 || warn "fluxion clone failed"; }
[ ! -d "wifite2" ] && { sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/derv82/wifite2.git > /dev/null 2>&1 || warn "wifite2 clone failed"; }
[ ! -d "airgeddon" ] && { sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/v1s1t0r1sh3r3/airgeddon.git > /dev/null 2>&1 || warn "airgeddon clone failed"; }
[ ! -d "eaphammer" ] && { sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/s0lst1c3/eaphammer.git > /dev/null 2>&1 || warn "eaphammer clone failed"; }

#==============================================================================
section "STEP 7: REVERSE ENGINEERING"
#==============================================================================

log "Installing reverse engineering tools..."
{ apt-get install -y \
    radare2 \
    gdb gdb-doc \
    edb-debugger \
    ltrace strace \
    valgrind \
    binwalk \
    foremost \
    upx-ucl \
    patchelf \
    checksec \
    yara python3-yara \
    apktool smali \
    binutils \
    hexedit \
    nasm \
    python3-pefile python3-capstone \
    flashrom; } \
    > /dev/null 2>&1 || warn "Some RE packages not available"

{ $PIP install --quiet --no-warn-script-location \
    ropper \
    ROPgadget \
    angr \
    capstone \
    keystone-engine \
    unicorn \
    pefile \
    r2pipe \
    pyelftools \
    binwalk \
    frida-tools \
    objection \
    androguard \
    volatility3; } \
    > /dev/null 2>&1 || { warn "Some RE pip packages failed"; echo "pip-reverse-engineering" >> "$FAILED_FILE"; }

gem install one_gadget > /dev/null 2>&1 || warn "one_gadget gem failed"

log "Cloning GEF and pwndbg for GDB..."
cd "$TOOLS_DIR"
[ ! -d "gef" ] && { sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/hugsy/gef.git > /dev/null 2>&1 || warn "gef clone failed"; }
[ ! -d "pwndbg" ] && { sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/pwndbg/pwndbg.git > /dev/null 2>&1 || warn "pwndbg clone failed"; }
[ ! -d "peda" ] && { sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/longld/peda.git > /dev/null 2>&1 || warn "peda clone failed"; }

log "Installing Ghidra..."
if ! command -v ghidra &>/dev/null && [ ! -d "$TOOLS_DIR/ghidra" ]; then
    GHIDRA_URL=$(curl -s https://api.github.com/repos/NationalSecurityAgency/ghidra/releases/latest | grep "browser_download_url.*ghidra.*zip" | head -1 | cut -d '"' -f 4)
    if [ -n "$GHIDRA_URL" ]; then
        wget -q "$GHIDRA_URL" -O /tmp/ghidra.zip
        unzip -q /tmp/ghidra.zip -d "$TOOLS_DIR/"
        mv "$TOOLS_DIR"/ghidra_* "$TOOLS_DIR/ghidra" 2>/dev/null || true
        rm -f /tmp/ghidra.zip
        log "Ghidra installed at $TOOLS_DIR/ghidra"
    else
        warn "Could not get Ghidra URL"
    fi
fi

#==============================================================================
section "STEP 8: EXPLOITATION TOOLS"
#==============================================================================

log "Installing exploitation tools (apt)..."
# Kali-only (not in Ubuntu repos): exploitdb, commix
log "NOTE: exploitdb and commix are Kali-exclusive packages"

log "Installing exploitation tools (pip)..."
{ $PIP install --quiet --no-warn-script-location \
    pwntools \
    impacket \
    certipy-ad \
    coercer \
    bloodyad \
    ldapdomaindump \
    dploot \
    pwncat-cs \
    routersploit; } \
    > /dev/null 2>&1 || { warn "Some exploitation pip packages failed"; echo "pip-exploitation" >> "$FAILED_FILE"; }

log "Installing exploitation tools (Go)..."
sudo -u "$REAL_USER" bash -c "export GIT_TERMINAL_PROMPT=0; export GOPATH=$GOPATH; export PATH=\$PATH:$GOPATH/bin; \
    go install github.com/jpillora/chisel@latest > /dev/null 2>&1; \
    " || warn "chisel failed"

log "Cloning exploitation frameworks..."
cd "$TOOLS_DIR"
[ ! -d "Responder" ] && { sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/lgandx/Responder.git > /dev/null 2>&1 || warn "Responder clone failed"; }
[ ! -d "Veil" ] && { sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/Veil-Framework/Veil.git > /dev/null 2>&1 || warn "Veil clone failed"; }
[ ! -d "PEASS-ng" ] && { sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/peass-ng/PEASS-ng.git > /dev/null 2>&1 || warn "PEASS-ng clone failed"; }
[ ! -d "linux-exploit-suggester" ] && { sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/mzet-/linux-exploit-suggester.git > /dev/null 2>&1 || warn "linux-exploit-suggester clone failed"; }
[ ! -d "linux-smart-enumeration" ] && { sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/diego-treitos/linux-smart-enumeration.git > /dev/null 2>&1 || warn "linux-smart-enumeration clone failed"; }
[ ! -d "LinEnum" ] && { sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/rebootuser/LinEnum.git > /dev/null 2>&1 || warn "LinEnum clone failed"; }

log "Downloading Burp Suite Community..."
if [ ! -f "$TOOLS_DIR/burpsuite_community.jar" ]; then
    BURP_URL="https://portswigger-cdn.net/burp/releases/download?product=community&type=Jar"
    wget -q "$BURP_URL" -O "$TOOLS_DIR/burpsuite_community.jar" 2>&1 || warn "Burp Suite download failed - download manually from portswigger.net"
    chown "$REAL_USER:$REAL_USER" "$TOOLS_DIR/burpsuite_community.jar" 2>/dev/null || true
fi

log "Cloning msfpc..."
cd "$TOOLS_DIR"
[ ! -d "msfpc" ] && { sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/g0tmi1k/msfpc.git > /dev/null 2>&1 || warn "msfpc clone failed"; }

log "Installing Metasploit Framework..."
if ! command -v msfconsole &>/dev/null; then
    curl -s https://raw.githubusercontent.com/rapid7/metasploit-omnibus/master/config/templates/metasploit-framework-wrappers/msfupdate.erb > /tmp/msfinstall
    chmod 755 /tmp/msfinstall
    /tmp/msfinstall > /dev/null 2>&1
    rm -f /tmp/msfinstall
    log "Metasploit installed"
else
    log "Metasploit is already installed"
fi

#==============================================================================
section "STEP 9: SNIFFING & SPOOFING"
#==============================================================================

log "Installing sniffing/spoofing tools..."
{ apt-get install -y \
    wireshark tshark \
    ettercap-text-only \
    bettercap \
    dsniff \
    ngrep \
    tcpflow tcpreplay tcpick \
    netsniff-ng \
    sslsplit \
    macchanger \
    driftnet \
    python3-scapy \
    netsed; } \
    > /dev/null 2>&1 || warn "Some sniffing packages not available"

# Allow wireshark without root
usermod -aG wireshark "$REAL_USER" 2>/dev/null || true

#==============================================================================
section "STEP 10: POST EXPLOITATION"
#==============================================================================

log "Installing post-exploitation tools (apt)..."
{ apt-get install -y \
    weevely \
    socat ncat netcat-traditional \
    sshuttle \
    dns2tcp \
    iodine \
    ptunnel \
    stunnel4 \
    httptunnel udptunnel \
    proxychains4 \
    redsocks \
    sslh \
    miredo \
    proxytunnel \
    openvpn \
    strongswan-charon \
    vpnc \
    openconnect \
    smbmap; } \
    > /dev/null 2>&1 || warn "Some post-exploitation packages not available"

log "Installing PowerShell..."
if ! command -v pwsh &>/dev/null; then
    wget -q "https://packages.microsoft.com/config/ubuntu/24.04/packages-microsoft-prod.deb" -O /tmp/ms-prod.deb
    dpkg -i /tmp/ms-prod.deb > /dev/null 2>&1
    apt-get update -y > /dev/null 2>&1
    apt-get install -y powershell > /dev/null 2>&1 || warn "PowerShell could not be installed"
    rm -f /tmp/ms-prod.deb
fi

log "Cloning post-exploitation tools..."
cd "$TOOLS_DIR"
[ ! -d "PowerSploit" ] && { sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/PowerShellMafia/PowerSploit.git > /dev/null 2>&1 || warn "PowerSploit clone failed"; }
[ ! -d "Empire" ] && { sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/BC-SECURITY/Empire.git > /dev/null 2>&1 || warn "Empire clone failed"; }
[ ! -d "nishang" ] && { sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/samratashok/nishang.git > /dev/null 2>&1 || warn "nishang clone failed"; }
[ ! -d "Villain" ] && { sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/t3l3machus/Villain.git > /dev/null 2>&1 || warn "Villain clone failed"; }

#==============================================================================
section "STEP 11: FORENSICS"
#==============================================================================

log "Installing forensic tools..."
{ apt-get install -y \
    autopsy sleuthkit \
    foremost scalpel \
    testdisk \
    extundelete \
    dcfldd dc3dd \
    guymager \
    ewf-tools \
    afflib-tools \
    magicrescue \
    clamav \
    ssdeep hashdeep \
    xxd ghex \
    chaosreader \
    tcpxtract \
    steghide stegsnow \
    outguess \
    exiv2 \
    sqlitebrowser; } \
    > /dev/null 2>&1 || warn "Some forensic packages not available"

{ $PIP install --quiet --no-warn-script-location \
    oletools \
    pdfid \
    stegoveritas; } \
    > /dev/null 2>&1 || { warn "Some forensic pip packages failed"; echo "pip-forensics" >> "$FAILED_FILE"; }
# volatility3 already installed in STEP 7

gem install zsteg > /dev/null 2>&1 || warn "zsteg gem failed"

log "Installing mobile forensics tools..."
{ apt-get install -y \
    adb apktool; } \
    > /dev/null 2>&1 || true

#==============================================================================
section "STEP 12: REPORTING TOOLS"
#==============================================================================

log "Installing reporting tools..."
{ apt-get install -y \
    cherrytree \
    cutycapt \
    recordmydesktop \
    weasyprint \
    texlive texlive-latex-extra; } \
    > /dev/null 2>&1 || warn "Some reporting packages not available"

{ $PIP install --quiet --no-warn-script-location \
    faradaysec mkdocs; } \
    > /dev/null 2>&1 || { warn "Some reporting pip packages failed"; echo "pip-reporting" >> "$FAILED_FILE"; }

#==============================================================================
section "STEP 13: SOCIAL ENGINEERING"
#==============================================================================

log "Cloning Social Engineering Toolkit (SET)..."
cd "$TOOLS_DIR"
if [ ! -d "social-engineer-toolkit" ]; then
    sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/trustedsec/social-engineer-toolkit.git > /dev/null 2>&1
    cd social-engineer-toolkit
    $PIP install --quiet --no-warn-script-location -r requirements.txt > /dev/null 2>&1 || warn "SET requirements failed"
fi

log "Cloning other social engineering tools..."
cd "$TOOLS_DIR"
[ ! -d "gophish" ] && { sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/gophish/gophish.git > /dev/null 2>&1 || warn "gophish clone failed"; }
[ ! -d "zphisher" ] && { sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/htr-tech/zphisher.git > /dev/null 2>&1 || warn "zphisher clone failed"; }
[ ! -d "evilginx2" ] && { sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/kgretzky/evilginx2.git > /dev/null 2>&1 || warn "evilginx2 clone failed"; }

# swaks already installed in STEP 3

#==============================================================================
section "STEP 14: SYSTEM SERVICES & INFRASTRUCTURE"
#==============================================================================

log "Installing base services..."
{ apt-get install -y \
    docker.io docker-compose \
    tor \
    wireguard \
    dnsmasq \
    pure-ftpd \
    atftpd tftp-hpa \
    apache2 nginx \
    openssh-server \
    mariadb-server \
    postgresql \
    redis-server \
    samba \
    snmpd \
    nfs-common \
    rpcbind \
    inetsim \
    mosquitto \
    freerdp3-x11 \
    tightvncserver xtightvncviewer; } \
    > /dev/null 2>&1 || true

# Do not leave SSH or other services exposed by default
systemctl disable --now openssh-server 2>/dev/null || true
systemctl disable --now apache2 2>/dev/null || true
systemctl disable --now nginx 2>/dev/null || true
systemctl disable --now mariadb 2>/dev/null || true
systemctl disable --now postgresql 2>/dev/null || true
systemctl disable --now redis-server 2>/dev/null || true
systemctl disable --now samba 2>/dev/null || true
systemctl disable --now snmpd 2>/dev/null || true
systemctl disable --now mosquitto 2>/dev/null || true
systemctl disable --now inetsim 2>/dev/null || true
log "Services installed but disabled for security (enable manually when needed)"

# Docker for the user
usermod -aG docker "$REAL_USER" 2>/dev/null || true
systemctl enable --now docker 2>/dev/null || true

#==============================================================================
section "STEP 15: C2 FRAMEWORKS"
#==============================================================================

log "Installing Sliver C2..."
if ! command -v sliver &>/dev/null; then
    curl -s https://sliver.sh/install | bash > /dev/null 2>&1 || warn "Sliver install failed"
fi

log "Cloning other C2 frameworks..."
cd "$TOOLS_DIR"
[ ! -d "Havoc" ] && { sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/HavocFramework/Havoc.git > /dev/null 2>&1 || warn "Havoc clone failed"; }

#==============================================================================
section "STEP 16: PROJECTDISCOVERY TOOLS (COMPLETE)"
#==============================================================================

log "Installing ALL ProjectDiscovery tools..."
sudo -u "$REAL_USER" bash -c "export GIT_TERMINAL_PROMPT=0; export GOPATH=$GOPATH; export PATH=\$PATH:$GOPATH/bin; \
    go install github.com/projectdiscovery/pdtm/cmd/pdtm@latest > /dev/null 2>&1; \
    go install github.com/projectdiscovery/interactsh/cmd/interactsh-client@latest > /dev/null 2>&1; \
    go install github.com/projectdiscovery/proxify/cmd/proxify@latest > /dev/null 2>&1; \
    go install github.com/projectdiscovery/shuffledns/cmd/shuffledns@latest > /dev/null 2>&1; \
    go install github.com/projectdiscovery/notify/cmd/notify@latest > /dev/null 2>&1; \
    go install github.com/projectdiscovery/urlfinder/cmd/urlfinder@latest > /dev/null 2>&1; \
    go install github.com/projectdiscovery/chaos-client/cmd/chaos@latest > /dev/null 2>&1; \
    go install github.com/projectdiscovery/simplehttpserver/cmd/simplehttpserver@latest > /dev/null 2>&1; \
    " || warn "Some PD tools failed"

#==============================================================================
section "STEP 17: WORDLISTS"
#==============================================================================

log "Downloading SecLists..."
chown -R "$REAL_USER:$REAL_USER" "$WORDLISTS_DIR"
if [ ! -d "/usr/share/seclists" ] && [ ! -d "$WORDLISTS_DIR/SecLists" ]; then
    sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/danielmiessler/SecLists.git "$WORDLISTS_DIR/SecLists" > /dev/null 2>&1
    ln -sf "$WORDLISTS_DIR/SecLists" /usr/share/seclists 2>/dev/null || true
fi

log "Downloading RockYou..."
if [ ! -f "$WORDLISTS_DIR/rockyou.txt" ]; then
    wget -q "https://github.com/brannondorsey/naive-hashcat/releases/download/data/rockyou.txt" \
        -O "$WORDLISTS_DIR/rockyou.txt" 2>&1 || warn "rockyou.txt download failed"
fi

log "Downloading PayloadsAllTheThings..."
cd "$TOOLS_DIR"
[ ! -d "PayloadsAllTheThings" ] && { sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/swisskyrepo/PayloadsAllTheThings.git > /dev/null 2>&1 || warn "PayloadsAllTheThings clone failed"; }

#==============================================================================
section "STEP 18: IMPORTANT ADDITIONAL TOOLS"
#==============================================================================

log "Installing IPv6 tools..."
apt-get install -y thc-ipv6 miredo > /dev/null 2>&1 || warn "thc-ipv6 not available"

#==============================================================================
section "STEP 18B: MISSING KALI TOOLS (OFFICIAL)"
#==============================================================================

log "Installing missing kali-tools-information-gathering tools..."
{ apt-get install -y \
    irpas netmask smbmap \
    zenmap ssldump \
    firewalk p0f; } \
    > /dev/null 2>&1 || warn "Some missing info-gathering packages not available"

log "Installing missing kali-tools-vulnerability tools..."
{ apt-get install -y \
    dhcpig \
    slowhttptest t50 siege \
    sipsak; } \
    > /dev/null 2>&1 || warn "Some missing vuln packages not available"

log "Installing missing kali-tools-web tools..."
apt-get install -y httrack > /dev/null 2>&1 || warn "httrack not available"

log "Installing missing kali-tools-exploitation tools..."
# Kali-only (not in Ubuntu repos): armitage, shellnoob
apt-get install -y termineter > /dev/null 2>&1 || warn "termineter not available"

log "Installing missing kali-tools-passwords tools..."
{ apt-get install -y \
    cmospwd \
    sucrack; } \
    > /dev/null 2>&1 || warn "Some missing password packages not available"

log "Installing missing kali-tools-sniffing-spoofing tools..."
{ apt-get install -y \
    darkstat \
    sslsniff; } \
    > /dev/null 2>&1 || warn "Some missing sniffing packages not available"

log "Installing missing kali-tools-post-exploitation tools..."
apt-get install -y sbd > /dev/null 2>&1 || warn "sbd not available"

log "Installing missing kali-tools-forensics tools..."
{ apt-get install -y \
    chkrootkit rkhunter \
    gddrescue \
    ext3grep \
    galleta \
    gpart grokevt \
    mac-robber memdump metacam \
    missidentify myrescue nasty \
    pasco \
    pst-utils \
    readpe recoverdm recoverjpeg \
    reglookup rephrase \
    rifiuti rifiuti2 \
    rsakeyfind \
    safecopy scrounge-ntfs \
    undbx unhide \
    vinetto winregfs \
    xmount \
    forensics-colorize \
    plaso; } \
    > /dev/null 2>&1 || warn "Some missing forensics packages not available"

log "Installing missing kali-tools-reverse-engineering tools..."
# Kali-only (not in Ubuntu repos): jd-gui, bytecode-viewer, javasnoop
log "NOTE: jd-gui, bytecode-viewer, javasnoop are Kali-exclusive packages"

log "Installing missing kali-tools-bluetooth tools..."
# Kali-only (not in Ubuntu repos): blue-hydra, bluelog, blueranger, bluesnarfer, crackle, redfang
log "NOTE: blue-hydra, bluelog, blueranger are Kali-exclusive packages"

log "Installing missing kali-tools-crypto-stego tools..."
{ apt-get install -y \
    aesfix aeskeyfind ccrypt stegosuite; } \
    > /dev/null 2>&1 || warn "Some missing crypto-stego packages not available"

log "Installing missing kali-tools-sdr tools..."
{ apt-get install -y \
    chirp inspectrum \
    gr-osmosdr \
    uhd-host; } \
    > /dev/null 2>&1 || warn "Some missing SDR packages not available"

log "Installing missing kali-tools-rfid tools..."
{ apt-get install -y \
    libnfc-bin mfoc mfcuk; } \
    > /dev/null 2>&1 || warn "Some missing RFID packages not available"

log "Installing missing kali-tools-voip tools..."
# Kali-only (not in Ubuntu repos): enumiax, ohrwurm, protos-sip, rtpbreak, rtpflood, rtpinsertsound, rtpmixsound
log "NOTE: enumiax, ohrwurm, protos-sip, rtpbreak are Kali-exclusive packages"

log "Installing missing kali-tools-protect tools..."
{ apt-get install -y \
    cryptsetup cryptsetup-initramfs \
    fwbuilder; } \
    > /dev/null 2>&1 || warn "Some missing protect packages not available"

log "Installing missing kali-tools-database tools..."
{ apt-get install -y \
    mdbtools sqlitebrowser; } \
    > /dev/null 2>&1 || true

log "Installing missing network and connectivity tools..."
{ apt-get install -y \
    cifs-utils nfs-common rpcbind \
    cabextract dislocker \
    lvm2 parted; } \
    > /dev/null 2>&1 || true

log "Installing missing tools detected in comparison..."
{ apt-get install -y \
    creddump7 \
    tcpdump \
    network-manager \
    nsis \
    bundler; } \
    > /dev/null 2>&1 || warn "Some comparison packages not available"

# mimikatz - download Windows binaries (useful for offline analysis)
MIMIKATZ_DIR="$TOOLS_DIR/mimikatz"
if [ ! -d "$MIMIKATZ_DIR" ]; then
    mkdir -p "$MIMIKATZ_DIR"
    MIMIKATZ_URL=$(curl -s https://api.github.com/repos/gentilkiwi/mimikatz/releases/latest | grep "browser_download_url.*zip" | head -1 | cut -d '"' -f 4)
    if [ -n "$MIMIKATZ_URL" ]; then
        wget -q "$MIMIKATZ_URL" -O /tmp/mimikatz.zip
        unzip -q /tmp/mimikatz.zip -d "$MIMIKATZ_DIR/"
        rm -f /tmp/mimikatz.zip
        chown -R "$REAL_USER:$REAL_USER" "$MIMIKATZ_DIR"
        log "mimikatz downloaded at $MIMIKATZ_DIR"
    fi
fi

#==============================================================================
section "STEP 18C: 158 MISSING TOOLS (OFFICIAL KALI CROSS-VERIFICATION)"
#==============================================================================

log "Installing missing APT tools (batch 1 - reconnaissance/OSINT)..."
{ apt-get install -y \
    altdns arpwatch \
    cntlm \
    dnswalk \
    exifprobe \
    gtkhash \
    horst \
    pnscan; } \
    > /dev/null 2>&1 || warn "Batch 1 - some not available in Ubuntu repos"

log "Installing missing APT tools (batch 2 - exploitation/passwords)..."
{ apt-get install -y \
    cutecom \
    doona \
    mdk3 \
    openocd \
    princeprocessor; } \
    > /dev/null 2>&1 || warn "Batch 2 - some not available in Ubuntu repos"

log "Installing missing APT tools (batch 3 - sniffing/forensics/misc)..."
{ apt-get install -y \
    ext4magic \
    fatcat \
    libhivex-bin \
    rfdump \
    regripper; } \
    > /dev/null 2>&1 || warn "Batch 3 - some not available in Ubuntu repos"

log "Installing missing tools (large pip batch)..."
{ $PIP install --quiet --no-warn-script-location \
    name-that-hash \
    h8mail \
    osrframework \
    pocsuite3 \
    instaloader \
    sploitscan \
    trufflehog \
    s3scanner \
    pacu; } \
    > /dev/null 2>&1 || { warn "Some missing pip packages failed"; echo "pip-missing" >> "$FAILED_FILE"; }

log "Installing missing tools (Go)..."
sudo -u "$REAL_USER" bash -c "export GIT_TERMINAL_PROMPT=0; export GOPATH=$GOPATH; export PATH=\$PATH:$GOPATH/bin; \
    go install github.com/sensepost/godoh@latest > /dev/null 2>&1; \
    go install github.com/rverton/webanalyze/cmd/webanalyze@latest > /dev/null 2>&1; \
    go install github.com/dwisiswant0/crlfuzz/cmd/crlfuzz@latest > /dev/null 2>&1; \
    " || warn "Some missing Go tools failed"

log "Cloning missing tools from GitHub..."
cd "$TOOLS_DIR"
[ ! -d "atomic-operator" ] && sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/swimlane/atomic-operator.git > /dev/null 2>&1 || true
[ ! -d "apple-bleee" ] && sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/hexway/apple_bleee.git "$TOOLS_DIR/apple-bleee" > /dev/null 2>&1 || true
[ ! -d "azurehound" ] && sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/BloodHoundAD/AzureHound.git "$TOOLS_DIR/azurehound" > /dev/null 2>&1 || true
[ ! -d "b374k" ] && sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/b374k/b374k.git > /dev/null 2>&1 || true
[ ! -d "berate-ap" ] && sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/sensepost/berate_ap.git "$TOOLS_DIR/berate-ap" > /dev/null 2>&1 || true
[ ! -d "bopscrk" ] && sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/r3nt0n/bopscrk.git > /dev/null 2>&1 || true
[ ! -d "bruteshark" ] && sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/odedshimon/BruteShark.git "$TOOLS_DIR/bruteshark" > /dev/null 2>&1 || true
[ ! -d "certgraph" ] && sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/lanrat/certgraph.git > /dev/null 2>&1 || true
[ ! -d "cloudbrute" ] && sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/0xsha/CloudBrute.git "$TOOLS_DIR/cloudbrute" > /dev/null 2>&1 || true
[ ! -d "cloud-enum" ] && sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/initstring/cloud_enum.git "$TOOLS_DIR/cloud-enum" > /dev/null 2>&1 || true
[ ! -d "detect-it-easy" ] && sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/horsicq/Detect-It-Easy.git "$TOOLS_DIR/detect-it-easy" > /dev/null 2>&1 || true
[ ! -d "donut-shellcode" ] && sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/TheWover/donut.git "$TOOLS_DIR/donut-shellcode" > /dev/null 2>&1 || true
[ ! -d "dscan" ] && sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/duolaxy/dscan.git > /dev/null 2>&1 || true
[ ! -d "dumpsterdiver" ] && sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/securing/DumpsterDiver.git "$TOOLS_DIR/dumpsterdiver" > /dev/null 2>&1 || true
[ ! -d "dvwa" ] && sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/digininja/DVWA.git "$TOOLS_DIR/dvwa" > /dev/null 2>&1 || true
[ ! -d "email2phonenumber" ] && sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/martinvigo/email2phonenumber.git > /dev/null 2>&1 || true
[ ! -d "evil-ssdp" ] && sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/initstring/evil-ssdp.git > /dev/null 2>&1 || true
[ ! -d "exiflooter" ] && sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/aydinnyunus/exifLooter.git "$TOOLS_DIR/exiflooter" > /dev/null 2>&1 || true
[ ! -d "goldeneye" ] && sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/jseidl/GoldenEye.git "$TOOLS_DIR/goldeneye" > /dev/null 2>&1 || true
[ ! -d "gsocket" ] && sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/hackerschoice/gsocket.git > /dev/null 2>&1 || true
## havoc - already cloned as Havoc in STEP 15
[ ! -d "hekatomb" ] && sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/ProcessusT/HEKATOMB.git "$TOOLS_DIR/hekatomb" > /dev/null 2>&1 || true
[ ! -d "hoaxshell" ] && sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/t3l3machus/hoaxshell.git > /dev/null 2>&1 || true
[ ! -d "inspy" ] && sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/leapsecurity/InSpy.git "$TOOLS_DIR/inspy" > /dev/null 2>&1 || true
[ ! -d "juice-shop" ] && sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/juice-shop/juice-shop.git > /dev/null 2>&1 || true
[ ! -d "kerberoast" ] && sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/nidem/kerberoast.git > /dev/null 2>&1 || true
[ ! -d "krbrelayx" ] && sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/dirkjanm/krbrelayx.git > /dev/null 2>&1 || true
[ ! -d "lapsdumper" ] && sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/n00py/LAPSDumper.git "$TOOLS_DIR/lapsdumper" > /dev/null 2>&1 || true
[ ! -d "ldeep" ] && sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/franc-pentest/ldeep.git > /dev/null 2>&1 || true
[ ! -d "ligolo-ng" ] && sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/nicocha30/ligolo-ng.git > /dev/null 2>&1 || true
[ ! -d "linkedin2username" ] && sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/initstring/linkedin2username.git > /dev/null 2>&1 || true
[ ! -d "linux-exploit-suggester" ] && true  # already cloned earlier
[ ! -d "maltego" ] && log "Maltego: download manually from https://www.maltego.com/downloads/"
[ ! -d "mssqlpwner" ] && sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/ScorpionesLabs/MSSqlPwner.git "$TOOLS_DIR/mssqlpwner" > /dev/null 2>&1 || true
[ ! -d "nextnet" ] && sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/hdm/nextnet.git > /dev/null 2>&1 || true
[ ! -d "odat" ] && sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/quentinhardy/odat.git > /dev/null 2>&1 || true
[ ! -d "passdetective" ] && sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/aydinnyunus/PassDetective.git "$TOOLS_DIR/passdetective" > /dev/null 2>&1 || true
[ ! -d "peirates" ] && sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/inguardians/peirates.git > /dev/null 2>&1 || true
[ ! -d "phishery" ] && sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/ryhanson/phishery.git > /dev/null 2>&1 || true
[ ! -d "portspoof" ] && sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/drk1wi/portspoof.git > /dev/null 2>&1 || true
[ ! -d "powercat" ] && sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/besimorhino/powercat.git > /dev/null 2>&1 || true
[ ! -d "pspy" ] && sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/DominicBreuker/pspy.git > /dev/null 2>&1 || true
[ ! -d "redeye" ] && sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/redeye-framework/Redeye.git "$TOOLS_DIR/redeye" > /dev/null 2>&1 || true
[ ! -d "reconspider" ] && sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/bhavsec/reconspider.git > /dev/null 2>&1 || true
[ ! -d "starkiller" ] && sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/BC-SECURITY/Starkiller.git "$TOOLS_DIR/starkiller" > /dev/null 2>&1 || true
[ ! -d "witnessme" ] && sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/byt3bl33d3r/WitnessMe.git "$TOOLS_DIR/witnessme" > /dev/null 2>&1 || true

log "Installing cloud/container security tools..."
{ $PIP install --quiet --no-warn-script-location \
    scoutsuite \
    prowler; } \
    > /dev/null 2>&1 || { warn "Cloud tools pip failed"; echo "pip-cloud" >> "$FAILED_FILE"; }

# trivy - install via .deb (go install fails due to size)
if ! command -v trivy &>/dev/null; then
    TRIVY_URL=$(curl -s https://api.github.com/repos/aquasecurity/trivy/releases/latest | grep "browser_download_url.*Linux-64bit.deb" | head -1 | cut -d '"' -f 4)
    if [ -n "$TRIVY_URL" ]; then
        wget -q "$TRIVY_URL" -O /tmp/trivy.deb 2>/dev/null && dpkg -i /tmp/trivy.deb > /dev/null 2>&1 && rm -f /tmp/trivy.deb || warn "trivy install failed"
    fi
fi

log "Installing last missing tools..."
apt-get install -y hashrat > /dev/null 2>&1 || warn "hashrat not available"

{ $PIP install --quiet --no-warn-script-location \
    emailharvester \
    faraday-cli \
    faraday-agent-dispatcher \
    humble; } \
    > /dev/null 2>&1 || { warn "Some last pip packages failed"; echo "pip-last" >> "$FAILED_FILE"; }

sudo -u "$REAL_USER" bash -c "export GIT_TERMINAL_PROMPT=0; export GOPATH=$GOPATH; export PATH=\$PATH:$GOPATH/bin; \
    go install github.com/sensepost/gowitness@latest > /dev/null 2>&1; \
    " || warn "Last missing Go tools failed"

cd "$TOOLS_DIR"
[ ! -d "getallurls" ] && sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/lc/gau.git "$TOOLS_DIR/getallurls" > /dev/null 2>&1 || true
[ ! -d "getsploit" ] && sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/vulnersCom/getsploit.git > /dev/null 2>&1 || true
[ ! -d "gitxray" ] && sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/kulkansecurity/gitxray.git > /dev/null 2>&1 || true
[ ! -d "bloodhound-ce-python" ] && $PIP install --quiet --no-warn-script-location bloodhound > /dev/null 2>&1 || true
[ ! -d "dwarf2json" ] && sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/volatilityfoundation/dwarf2json.git > /dev/null 2>&1 || true
[ ! -d "heartleech" ] && sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/robertdavidgraham/heartleech.git > /dev/null 2>&1 || true
[ ! -d "hostapd-mana" ] && sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/sensepost/hostapd-mana.git > /dev/null 2>&1 || true
[ ! -d "pack2" ] && sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/iphelix/pack.git "$TOOLS_DIR/pack2" > /dev/null 2>&1 || true

# Tools that are Kali-specific binaries/GUIs or commercial:
log "NOTE: The following tools cannot be installed directly on Ubuntu:"
log "  - caido: Download from https://caido.io/download"
log "  - maltego + maltego-teeth: Download from https://www.maltego.com/downloads/"
log "  - bettercap-ui: bettercap web UI, activate with 'bettercap -eval ui.update'"
log "  - android-sdk-meta: Install Android Studio from https://developer.android.com/studio"
log "  - dbeaver: snap install dbeaver-ce"
log "  - rizin-cutter + rz-ghidra: rizin is built from source in STEP 18D"
log "  - defectdojo: Docker: docker run -d -p 8080:8080 defectdojo/defectdojo-django"

snap install dbeaver-ce --classic > /dev/null 2>&1 || warn "dbeaver snap failed"

log "Installing last 15 remaining tools..."
# aflplusplus = afl++ (already installed as afl++)
# Kali-only (not in Ubuntu repos): gdb-peda
{ apt-get install -y \
    gr-air-modes gr-iqbal; } \
    > /dev/null 2>&1 || warn "Last missing apt packages not available"

# binwalk3 is the new version of binwalk, already covered
# cisco7crack
cd "$TOOLS_DIR"
[ ! -d "cisco7crack" ] && sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/theevilbit/ciscot7.git "$TOOLS_DIR/cisco7crack" > /dev/null 2>&1 || true
# cupid-wpa
[ ! -d "cupid-wpa" ] && sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/lgrangeia/cupid.git "$TOOLS_DIR/cupid-wpa" > /dev/null 2>&1 || true
# exploitdb-bin-sploits and exploitdb-papers are exploitdb extensions
[ ! -d "exploitdb-bin-sploits" ] && sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 120 git clone --depth 1 https://gitlab.com/exploit-database/exploitdb-bin-sploits.git > /dev/null 2>&1 || true
[ ! -d "exploitdb-papers" ] && sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 120 git clone --depth 1 https://gitlab.com/exploit-database/exploitdb-papers.git > /dev/null 2>&1 || true
# httpx-toolkit is httpx from projectdiscovery (already installed via go)
# ipv6toolkit
[ ! -d "ipv6toolkit" ] && sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/fgont/ipv6toolkit.git > /dev/null 2>&1 || true
# Kali-only (not in Ubuntu repos): libfindrtp0
# powershell-empire = Empire (already cloned)

log "Installing Rustscan..."
if ! command -v rustscan &>/dev/null; then
    RUSTSCAN_URL=$(curl -s https://api.github.com/repos/RustScan/RustScan/releases/latest | grep "browser_download_url.*amd64.deb" | head -1 | cut -d '"' -f 4)
    if [ -n "$RUSTSCAN_URL" ]; then
        wget -q "$RUSTSCAN_URL" -O /tmp/rustscan.deb 2>&1 && \
        dpkg -i /tmp/rustscan.deb > /dev/null 2>&1 && rm -f /tmp/rustscan.deb || warn "Rustscan install failed"
    else
        warn "Could not get Rustscan URL"
    fi
fi

log "Downloading CyberChef..."
if [ ! -d "$TOOLS_DIR/CyberChef" ]; then
    mkdir -p "$TOOLS_DIR/CyberChef"
    CYBERCHEF_URL=$(curl -s https://api.github.com/repos/gchq/CyberChef/releases/latest | grep "browser_download_url.*zip" | head -1 | cut -d '"' -f 4)
    if [ -n "$CYBERCHEF_URL" ]; then
        wget -q "$CYBERCHEF_URL" -O /tmp/cyberchef.zip
        unzip -q /tmp/cyberchef.zip -d "$TOOLS_DIR/CyberChef/"
        rm -f /tmp/cyberchef.zip
        chown -R "$REAL_USER:$REAL_USER" "$TOOLS_DIR/CyberChef"
        log "CyberChef downloaded at $TOOLS_DIR/CyberChef"
    fi
fi

log "Installing new Kali 2026.1 tools..."
cd "$TOOLS_DIR"
[ ! -d "SSTImap" ] && sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/vladko312/SSTImap.git > /dev/null 2>&1 || true
[ ! -d "autorecon" ] && sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/Tib3rius/AutoRecon.git "$TOOLS_DIR/autorecon" > /dev/null 2>&1 || true
$PIP install --quiet --no-warn-script-location autorecon > /dev/null 2>&1 || warn "autorecon pip failed"

log "Installing additional tools from software_instalado.md document..."
{ apt-get install -y \
    dnstwist \
    changeme \
    brutespray \
    bruteforce-luks bruteforce-salted-openssl bruteforce-wallet; } \
    > /dev/null 2>&1 || true

log "Installing additional tools (Go)..."
sudo -u "$REAL_USER" bash -c "export GIT_TERMINAL_PROMPT=0; export GOPATH=$GOPATH; export PATH=\$PATH:$GOPATH/bin; \
    go install github.com/tomnomnom/anew@latest > /dev/null 2>&1; \
    go install github.com/tomnomnom/gf@latest > /dev/null 2>&1; \
    go install github.com/tomnomnom/qsreplace@latest > /dev/null 2>&1; \
    go install github.com/tomnomnom/unfurl@latest > /dev/null 2>&1; \
    go install github.com/projectdiscovery/cvemap/cmd/cvemap@latest > /dev/null 2>&1; \
    " || warn "Some additional Go tools failed"

log "Installing additional tools (pip)..."
{ $PIP install --quiet --no-warn-script-location \
    mitm6 \
    scapy \
    requests beautifulsoup4 \
    paramiko cryptography \
    ; } \
    > /dev/null 2>&1 || { warn "Some additional pip packages failed"; echo "pip-additional" >> "$FAILED_FILE"; }
# bloodhound, shodan, censys, pyinstaller already installed in previous sections

log "Installing ZAP Proxy..."
snap install zaproxy --classic > /dev/null 2>&1 || warn "zaproxy snap failed"

log "Installing feroxbuster..."
snap install feroxbuster > /dev/null 2>&1 || warn "feroxbuster snap failed"

log "Installing additional tools (pip extras)..."
{ $PIP install --quiet --no-warn-script-location \
    wpscan-out-parse \
    droopescan \
    sshuttle \
    fierce \
    dnsgen; } \
    > /dev/null 2>&1 || true
# dirsearch, pwncat-cs already installed in previous sections

log "Cloning additional tools..."
cd "$TOOLS_DIR"
[ ! -d "BloodHound" ] && sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/SpecterOps/BloodHound.git > /dev/null 2>&1 || true
[ ! -d "testssl.sh" ] && sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/drwetter/testssl.sh.git > /dev/null 2>&1 || true
[ ! -d "dnscat2" ] && sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/iagox86/dnscat2.git > /dev/null 2>&1 || true
[ ! -d "PCredz" ] && sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/lgandx/PCredz.git > /dev/null 2>&1 || true
[ ! -d "EyeWitness" ] && sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/RedSiege/EyeWitness.git > /dev/null 2>&1 || true
[ ! -d "cupp" ] && sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/Mebus/cupp.git > /dev/null 2>&1 || true
[ ! -d "MobSF" ] && sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/MobSF/Mobile-Security-Framework-MobSF.git "$TOOLS_DIR/MobSF" > /dev/null 2>&1 || true
[ ! -d "w3af" ] && sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/andresriancho/w3af.git > /dev/null 2>&1 || true
[ ! -d "isr-evilgrade" ] && sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/infobyte/evilgrade.git "$TOOLS_DIR/isr-evilgrade" > /dev/null 2>&1 || true
[ ! -d "sn1per" ] && sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/1N3/Sn1per.git "$TOOLS_DIR/sn1per" > /dev/null 2>&1 || true
[ ! -d "legion-tool" ] && sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/GoVanguard/legion.git "$TOOLS_DIR/legion-tool" > /dev/null 2>&1 || true
[ ! -d "dradis-ce" ] && sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/dradis/dradis-ce.git > /dev/null 2>&1 || true
[ ! -d "chainsaw" ] && sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/WithSecureLabs/chainsaw.git > /dev/null 2>&1 || true
[ ! -d "gitleaks" ] && sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/gitleaks/gitleaks.git > /dev/null 2>&1 || true
[ ! -d "Caldera" ] && sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/mitre/caldera.git "$TOOLS_DIR/Caldera" > /dev/null 2>&1 || true

#==============================================================================
section "STEP 18D: TOOLS NOT AVAILABLE IN APT (ALTERNATIVE METHODS)"
#==============================================================================

log "Installing tools not in Ubuntu repos via alternative methods..."

# --- Via snap ---
log "Installing tools via snap..."
snap install commix > /dev/null 2>&1 || warn "commix snap failed"
snap install rustscan > /dev/null 2>&1 || warn "rustscan snap failed"
# dbeaver-ce and rizin already installed via snap in STEP 18C
# seclists already downloaded via git clone in STEP 17

# --- Via pip (inside pentest-venv) ---
log "Installing tools via pip..."
$PIP install --quiet --no-warn-script-location dnschef-ng > /dev/null 2>&1 || warn "Some pip packages failed"
# pyinstaller already installed via pip in STEP 18C

# --- Via official third-party repo (kismet) ---
log "Installing Kismet from official repo..."
if ! command -v kismet &>/dev/null; then
    wget -O - https://www.kismetwireless.net/repos/kismet-release.gpg.key 2>/dev/null | gpg --dearmor | tee /usr/share/keyrings/kismet-archive-keyring.gpg >/dev/null
    echo 'deb [signed-by=/usr/share/keyrings/kismet-archive-keyring.gpg] https://www.kismetwireless.net/repos/apt/release/noble noble main' | tee /etc/apt/sources.list.d/kismet.list
    apt-get update -y > /dev/null 2>&1
    apt-get install -y kismet > /dev/null 2>&1 || warn "Kismet install failed"
fi

# --- Via GitHub clone + build (compilation) ---
log "Installing build dependencies..."
apt-get install -y flex bison libpcap-dev libfftw3-dev libtool automake autoconf libreadline-dev libnfc-dev meson ninja-build librtlsdr-dev > /dev/null 2>&1 || true

log "Installing tools from GitHub (compilation)..."

# massdns - High-performance DNS resolver
if ! command -v massdns &>/dev/null; then
    cd "$TOOLS_DIR"
    [ ! -d "massdns" ] && { sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/blechschmidt/massdns.git > /dev/null 2>&1 || warn "massdns clone failed"; }
    if [ -d "massdns" ]; then
        cd massdns && make > /dev/null 2>&1 && cp bin/massdns /usr/local/bin/ 2>/dev/null || warn "massdns build failed"
    fi
fi

# intrace
if ! command -v intrace &>/dev/null; then
    cd "$TOOLS_DIR"
    [ ! -d "intrace" ] && { sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/robertswiecki/intrace.git > /dev/null 2>&1 || warn "intrace clone failed"; }
    if [ -d "intrace" ]; then
        cd intrace && make > /dev/null 2>&1 && cp intrace /usr/local/bin/ 2>/dev/null || warn "intrace build failed"
    fi
fi

# hexinject
cd "$TOOLS_DIR"
[ ! -d "hexinject" ] && { sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/ParrotSec/hexinject.git > /dev/null 2>&1 || warn "hexinject clone failed"; }
if [ -d "hexinject" ] && ! command -v hexinject &>/dev/null; then
    cd "$TOOLS_DIR/hexinject" && gcc -o hexinject hexinject.c prettypacket.c -lpcap -include ctype.h > /dev/null 2>&1 && cp hexinject /usr/local/bin/ 2>/dev/null && gcc -o hex2raw hex2raw.c > /dev/null 2>&1 && cp hex2raw /usr/local/bin/ 2>/dev/null || log "hexinject: source cloned at $TOOLS_DIR/hexinject (compile manually if needed)"
fi

# pwnat
cd "$TOOLS_DIR"
[ ! -d "pwnat" ] && { sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/samyk/pwnat.git > /dev/null 2>&1 || warn "pwnat clone failed"; }
if [ -d "pwnat" ] && ! command -v pwnat &>/dev/null; then
    cd pwnat && make > /dev/null 2>&1 && cp pwnat /usr/local/bin/ 2>/dev/null || warn "pwnat build failed"
fi

# bulk-extractor
cd "$TOOLS_DIR"
[ ! -d "bulk_extractor" ] && { sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --recurse-submodules --depth 1 https://github.com/simsong/bulk_extractor.git > /dev/null 2>&1 || warn "bulk_extractor clone failed"; }
if [ -d "bulk_extractor" ] && ! command -v bulk_extractor &>/dev/null; then
    cd bulk_extractor && timeout 120 ./bootstrap.sh > /dev/null 2>&1 && timeout 60 ./configure > /dev/null 2>&1 && timeout 300 make -j$(nproc) > /dev/null 2>&1 && make install > /dev/null 2>&1 || log "bulk_extractor: source cloned at $TOOLS_DIR/bulk_extractor (compile manually)"
fi

# voiphopper
cd "$TOOLS_DIR"
[ ! -d "voiphopper" ] && { sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/iknowjason/voiphopper.git > /dev/null 2>&1 || warn "voiphopper clone failed"; }

# kalibrate-rtl
cd "$TOOLS_DIR"
[ ! -d "kalibrate-rtl" ] && { sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/steve-m/kalibrate-rtl.git > /dev/null 2>&1 || warn "kalibrate-rtl clone failed"; }
if [ -d "kalibrate-rtl" ] && ! command -v kal &>/dev/null; then
    cd kalibrate-rtl && timeout 60 ./bootstrap > /dev/null 2>&1 && timeout 60 CXXFLAGS="-fpermissive" ./configure > /dev/null 2>&1 && timeout 180 make > /dev/null 2>&1 && make install > /dev/null 2>&1 || warn "kalibrate-rtl build failed"
fi

# proxmark3
cd "$TOOLS_DIR"
[ ! -d "proxmark3" ] && { sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/RfidResearchGroup/proxmark3.git > /dev/null 2>&1 || warn "proxmark3 clone failed"; }

# shellnoob
cd "$TOOLS_DIR"
[ ! -d "shellnoob" ] && { sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/reyammer/shellnoob.git > /dev/null 2>&1 || warn "shellnoob clone failed"; }
if [ -d "shellnoob" ]; then
    cd "$TOOLS_DIR/shellnoob" && yes | timeout 30 python3 shellnoob.py --install > /dev/null 2>&1 || warn "shellnoob install failed"
fi

# --- Via GitHub clone (script-only, no compilation) ---
log "Installing script-only tools from GitHub..."
cd "$TOOLS_DIR"

# enum4linux
[ ! -d "enum4linux" ] && { sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/CiscoCXSecurity/enum4linux.git > /dev/null 2>&1 || warn "enum4linux clone failed"; }

# ParamSpider
[ ! -d "ParamSpider" ] && { sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/devanshbatham/ParamSpider.git > /dev/null 2>&1 || warn "ParamSpider clone failed"; }

# lbd - load balancer detector
[ ! -d "lbd" ] && { sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/D3vil0p3r/lbd.git > /dev/null 2>&1 || warn "lbd clone failed"; }

# unix-privesc-check
[ ! -d "unix-privesc-check" ] && { sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/pentestmonkey/unix-privesc-check.git > /dev/null 2>&1 || warn "unix-privesc-check clone failed"; }

# davtest
[ ! -d "davtest" ] && { sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/cldrn/davtest.git > /dev/null 2>&1 || warn "davtest clone failed"; }

# smtp-user-enum
[ ! -d "smtp-user-enum" ] && { sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/pentestmonkey/smtp-user-enum.git > /dev/null 2>&1 || warn "smtp-user-enum clone failed"; }

# dnschef
[ ! -d "dnschef" ] && { sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/iphelix/dnschef.git > /dev/null 2>&1 || warn "dnschef clone failed"; }

# fern-wifi-cracker
[ ! -d "fern-wifi-cracker" ] && { sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/savio-code/fern-wifi-cracker.git > /dev/null 2>&1 || warn "fern-wifi-cracker clone failed"; }

# spooftooph
[ ! -d "spooftooph" ] && { sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/Asymmetric-Effort/spooftooph.git > /dev/null 2>&1 || warn "spooftooph clone failed"; }

# spike fuzzer
[ ! -d "spike" ] && { sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/guilhermeferreira/spikepp.git "$TOOLS_DIR/spike" > /dev/null 2>&1 || warn "spike clone failed"; }

# --- Via binary releases (downloads) ---
log "Downloading binary releases..."

# jadx
if ! command -v jadx &>/dev/null && [ ! -d "$TOOLS_DIR/jadx" ]; then
    JADX_URL=$(curl -s https://api.github.com/repos/skylot/jadx/releases/latest | grep "browser_download_url.*jadx-[0-9].*\.zip" | grep -v "gui" | head -1 | cut -d '"' -f 4)
    if [ -n "$JADX_URL" ]; then
        wget -q "$JADX_URL" -O /tmp/jadx.zip && unzip -q /tmp/jadx.zip -d "$TOOLS_DIR/jadx/" && rm -f /tmp/jadx.zip
        chmod +x "$TOOLS_DIR/jadx/bin/jadx" "$TOOLS_DIR/jadx/bin/jadx-gui" 2>/dev/null
        ln -sf "$TOOLS_DIR/jadx/bin/jadx" /usr/local/bin/jadx 2>/dev/null
        log "jadx installed at $TOOLS_DIR/jadx"
    else
        warn "Could not get jadx URL"
    fi
fi

# dex2jar
if [ ! -d "$TOOLS_DIR/dex2jar" ]; then
    DEX2JAR_URL=$(curl -s https://api.github.com/repos/pxb1988/dex2jar/releases/latest | grep "browser_download_url.*zip" | head -1 | cut -d '"' -f 4)
    if [ -n "$DEX2JAR_URL" ]; then
        wget -q "$DEX2JAR_URL" -O /tmp/dex2jar.zip && unzip -q /tmp/dex2jar.zip -d "$TOOLS_DIR/" && mv "$TOOLS_DIR"/dex-tools* "$TOOLS_DIR/dex2jar" 2>/dev/null
        chmod +x "$TOOLS_DIR/dex2jar/"*.sh 2>/dev/null
        rm -f /tmp/dex2jar.zip
        log "dex2jar installed at $TOOLS_DIR/dex2jar"
    else
        warn "Could not get dex2jar URL"
    fi
fi

# exploitdb/searchsploit
if ! command -v searchsploit &>/dev/null; then
    sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 120 git clone --depth 1 https://gitlab.com/exploit-database/exploitdb.git "$TOOLS_DIR/exploitdb" > /dev/null 2>&1 || true
    if [ -d "$TOOLS_DIR/exploitdb" ]; then
        ln -sf "$TOOLS_DIR/exploitdb/searchsploit" /usr/local/bin/searchsploit 2>/dev/null
        log "searchsploit installed"
    fi
fi

# --- Via rizin build (reverse engineering framework) ---
log "Installing rizin from source..."
if ! command -v rizin &>/dev/null; then
    cd "$TOOLS_DIR"
    [ ! -d "rizin" ] && { sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 --recurse-submodules https://github.com/rizinorg/rizin.git > /dev/null 2>&1 || warn "rizin clone failed"; }
    if [ -d "rizin" ]; then
        apt-get install -y meson ninja-build libmagic-dev > /dev/null 2>&1
        cd rizin && timeout 60 meson setup build > /dev/null 2>&1 && timeout 300 meson compile -C build > /dev/null 2>&1 && meson install -C build > /dev/null 2>&1 || log "rizin: source cloned at $TOOLS_DIR/rizin (compile manually)"
    fi
fi

# --- Additional missing tools ---
log "Installing additional tools not available in apt..."

# cryptcat - netcat with twofish encryption
cd "$TOOLS_DIR"
if ! command -v cryptcat &>/dev/null; then
    # cryptcat: original repo not available, use ncat --ssl as alternative
    if [ -d "cryptcat" ]; then
        cd cryptcat && make linux > /dev/null 2>&1 && cp cryptcat /usr/local/bin/ 2>/dev/null || warn "cryptcat build failed"
    fi
fi

# rebind - DNS rebinding tool
cd "$TOOLS_DIR"
# rebind: original repo not available, use singularity from nccgroup as DNS rebinding alternative
[ ! -d "singularity" ] && { sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/nccgroup/singularity.git > /dev/null 2>&1 || true; }

# sqsh - SQL shell for Sybase/MS-SQL (available as freetds + sqsh source)
cd "$TOOLS_DIR"
if ! command -v sqsh &>/dev/null; then
    apt-get install -y freetds-dev freetds-bin libct4 libreadline-dev > /dev/null 2>&1 || true
    [ ! -d "sqsh" ] && { sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/vonloxley/sqsh.git > /dev/null 2>&1 || warn "sqsh clone failed"; }
    if [ -d "sqsh" ]; then
        cd sqsh && timeout 60 autoreconf -if > /dev/null 2>&1 && timeout 60 ./configure --with-freetds > /dev/null 2>&1 && timeout 120 make > /dev/null 2>&1 && make install > /dev/null 2>&1 || log "sqsh: source cloned at $TOOLS_DIR/sqsh (compile manually)"
    fi
fi

# armitage - GUI for Metasploit (requires Java)
cd "$TOOLS_DIR"
if [ ! -d "armitage" ]; then
    sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/r00t0v3rr1d3/armitage.git > /dev/null 2>&1 || warn "armitage clone failed"
fi

# johnny - GUI for John the Ripper
cd "$TOOLS_DIR"
if [ ! -d "johnny" ]; then
    sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/openwall/johnny.git > /dev/null 2>&1 || warn "johnny clone failed"
fi

# rainbowcrack - rainbow table generator and lookup
cd "$TOOLS_DIR"
if [ ! -d "rainbowcrack" ]; then
    mkdir -p rainbowcrack
    RCRACK_URL="https://project-rainbowcrack.com/rainbowcrack-1.8-linux64.zip"
    wget -q "$RCRACK_URL" -O /tmp/rainbowcrack.zip 2>&1 && \
        unzip -q /tmp/rainbowcrack.zip -d "$TOOLS_DIR/rainbowcrack/" && \
        rm -f /tmp/rainbowcrack.zip || warn "rainbowcrack download failed - download manually from project-rainbowcrack.com"
    chown -R "$REAL_USER:$REAL_USER" "$TOOLS_DIR/rainbowcrack" 2>/dev/null || true
fi

# mfterm - Terminal for MIFARE Classic
cd "$TOOLS_DIR"
if ! command -v mfterm &>/dev/null; then
    [ ! -d "mfterm" ] && { sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/4ZM/mfterm.git > /dev/null 2>&1 || warn "mfterm clone failed"; }
    if [ -d "mfterm" ]; then
        apt-get install -y libnfc-dev > /dev/null 2>&1 || true
        cd mfterm && timeout 60 autoreconf -if > /dev/null 2>&1 && timeout 60 ./configure > /dev/null 2>&1 && timeout 120 make > /dev/null 2>&1 && make install > /dev/null 2>&1 || log "mfterm: source cloned at $TOOLS_DIR/mfterm (compile manually)"
    fi
fi

# gdb-peda - already cloned as 'peda' in STEP 7, configure symlink
if [ -d "$TOOLS_DIR/peda" ]; then
    ln -sf "$TOOLS_DIR/peda" "$TOOLS_DIR/gdb-peda" 2>/dev/null || true
    log "gdb-peda available at $TOOLS_DIR/peda (symlink at $TOOLS_DIR/gdb-peda)"
fi

# dirbuster - directory brute forcer (version OWASP, requiere Java)
cd "$TOOLS_DIR"
if [ ! -d "dirbuster" ]; then
    mkdir -p dirbuster
    DIRBUSTER_URL="https://sourceforge.net/projects/dirbuster/files/DirBuster%20%28jar%20%2B%20lists%29/1.0-RC1/DirBuster-1.0-RC1.tar.bz2/download"
    wget -q "$DIRBUSTER_URL" -O /tmp/dirbuster.tar.bz2 2>&1 && \
        tar -xjf /tmp/dirbuster.tar.bz2 -C "$TOOLS_DIR/dirbuster/" --strip-components=1 && \
        rm -f /tmp/dirbuster.tar.bz2 || warn "dirbuster download failed - functionality covered by dirb, gobuster, and ffuf"
    chown -R "$REAL_USER:$REAL_USER" "$TOOLS_DIR/dirbuster" 2>/dev/null || true
fi

# thc-pptp-bruter - PPTP VPN brute forcer (repo no longer available, PPTP is an obsolete protocol)

# --- Additional tools available in apt ---
log "Installing additional tools available in apt..."
apt-get install -y snort > /dev/null 2>&1 || warn "Some additional apt packages not available"

# --- Additional tools via pip (in venv) ---
log "Installing additional tools via pip..."
$PIP install --quiet --no-warn-script-location distorm3 maryam > /dev/null 2>&1 || { warn "Some 18D pip packages failed"; echo "pip-18d" >> "$FAILED_FILE"; }

# --- Additional tools via gem ---
log "Installing additional tools via gem..."
# pipal: gem not available, clone from GitHub
cd "$TOOLS_DIR"
[ ! -d "pipal" ] && { sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/digininja/pipal.git > /dev/null 2>&1 || true; }

# --- Additional tools from GitHub (compilation) ---
log "Installing additional tools from GitHub..."
cd "$TOOLS_DIR"

# crackle - BLE cracking
[ ! -d "crackle" ] && { sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/mikeryan/crackle.git > /dev/null 2>&1 || warn "crackle clone failed"; }
if [ -d "crackle" ] && ! command -v crackle &>/dev/null; then
    cd "$TOOLS_DIR/crackle" && make > /dev/null 2>&1 && cp crackle /usr/local/bin/ 2>/dev/null || warn "crackle build failed"
fi

# truecrack
cd "$TOOLS_DIR"
[ ! -d "truecrack" ] && { sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/lvaccaro/truecrack.git > /dev/null 2>&1 || warn "truecrack clone failed"; }
if [ -d "truecrack" ] && ! command -v truecrack &>/dev/null; then
    cd "$TOOLS_DIR/truecrack" && make > /dev/null 2>&1 && cp truecrack /usr/local/bin/ 2>/dev/null || log "truecrack: source cloned at $TOOLS_DIR/truecrack (compile manually)"
fi

# --- Additional script-only tools from GitHub ---
cd "$TOOLS_DIR"

# wifiphisher (also cloned in case pip fails)
[ ! -d "wifiphisher" ] && { sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/wifiphisher/wifiphisher.git > /dev/null 2>&1 || warn "wifiphisher clone failed"; }

# webacoo - web backdoor cookie
[ ! -d "webacoo" ] && { sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/anestisb/WeBaCoo.git "$TOOLS_DIR/webacoo" > /dev/null 2>&1 || warn "webacoo clone failed"; }

# xsser - XSS exploitation
[ ! -d "xsser" ] && { sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/epsylon/xsser.git > /dev/null 2>&1 || warn "xsser clone failed"; }

# wifi-honey
# wifi-honey: repo not available

# laudanum - webshell collection
[ ! -d "laudanum" ] && sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 120 git clone --depth 1 https://gitlab.com/kalilinux/packages/laudanum.git > /dev/null 2>&1 || true

# bluesnarfer
[ ! -d "bluesnarfer" ] && sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 120 git clone --depth 1 https://gitlab.com/kalilinux/packages/bluesnarfer.git > /dev/null 2>&1 || true

# redfang
[ ! -d "redfang" ] && sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 120 git clone --depth 1 https://gitlab.com/kalilinux/packages/redfang.git > /dev/null 2>&1 || true

# ferret-sidejack
[ ! -d "ferret-sidejack" ] && sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 120 git clone --depth 1 https://gitlab.com/kalilinux/packages/ferret-sidejack.git > /dev/null 2>&1 || true

# rtpflood
[ ! -d "rtpflood" ] && sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 120 git clone --depth 1 https://gitlab.com/kalilinux/packages/rtpflood.git > /dev/null 2>&1 || true

# maryam (also cloned as backup)
[ ! -d "maryam" ] && { sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true timeout 60 git clone --depth 1 https://github.com/saeeddhqan/Maryam.git "$TOOLS_DIR/maryam" > /dev/null 2>&1 || warn "maryam clone failed"; }

# --- Additional binary releases ---
log "Downloading additional binary releases..."

# jd-gui - Java decompiler GUI
if [ ! -f "$TOOLS_DIR/jd-gui.jar" ]; then
    JDGUI_URL=$(curl -s https://api.github.com/repos/java-decompiler/jd-gui/releases/latest | grep "browser_download_url.*\.jar\"" | head -1 | cut -d '"' -f 4)
    if [ -n "$JDGUI_URL" ]; then
        wget -q "$JDGUI_URL" -O "$TOOLS_DIR/jd-gui.jar" 2>&1 || warn "jd-gui download failed"
        log "jd-gui downloaded at $TOOLS_DIR/jd-gui.jar"
    fi
fi

# bytecode-viewer
if [ ! -f "$TOOLS_DIR/bytecode-viewer.jar" ]; then
    BCV_URL=$(curl -s https://api.github.com/repos/Konloch/bytecode-viewer/releases/latest | grep "browser_download_url.*\.jar\"" | head -1 | cut -d '"' -f 4)
    if [ -n "$BCV_URL" ]; then
        wget -q "$BCV_URL" -O "$TOOLS_DIR/bytecode-viewer.jar" 2>&1 || warn "bytecode-viewer download failed"
        log "bytecode-viewer downloaded at $TOOLS_DIR/bytecode-viewer.jar"
    fi
fi

#==============================================================================
section "STEP 19: PATH CONFIGURATION"
#==============================================================================

log "Configuring PATH and aliases..."
PROFILE_FILE="$REAL_HOME/.zshrc"
[ ! -f "$PROFILE_FILE" ] && PROFILE_FILE="$REAL_HOME/.bashrc"

# Add paths if they don't exist
if ! grep -q "pentest-venv" "$PROFILE_FILE" 2>/dev/null; then
    cat >> "$PROFILE_FILE" << 'PATHS'

# === PENTESTING TOOLS PATH ===
export GOPATH="$HOME/go"
export PATH="$PATH:$GOPATH/bin:$HOME/pentest-venv/bin:$HOME/tools:$HOME/.local/bin:/opt/metasploit-framework/bin"
alias msfconsole='cd /opt/metasploit-framework && ./msfconsole'
alias pentest-activate='source $HOME/pentest-venv/bin/activate'
alias tools='cd $HOME/tools'
alias wordlists='cd $HOME/wordlists'
PATHS
    log "PATH configured in $PROFILE_FILE"
fi

#==============================================================================
section "STEP 20: PERMISSIONS AND CLEANUP"
#==============================================================================

log "Adjusting permissions..."
chown -R "$REAL_USER:$REAL_USER" "$REAL_HOME/go" 2>/dev/null || true
chown -R "$REAL_USER:$REAL_USER" "$TOOLS_DIR" 2>/dev/null || true
chown -R "$REAL_USER:$REAL_USER" "$WORDLISTS_DIR" 2>/dev/null || true
chown -R "$REAL_USER:$REAL_USER" "$VENV" 2>/dev/null || true

log "Cleaning cache..."
apt-get autoremove -y > /dev/null 2>&1
apt-get autoclean -y > /dev/null 2>&1

#==============================================================================
section "FINAL SUMMARY"
#==============================================================================

echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  INSTALLATION COMPLETED${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo -e "Full log: ${CYAN}$LOG_FILE${NC}"
echo -e "Errors: ${CYAN}$FAILED_FILE${NC}"
echo ""
echo -e "${YELLOW}Important locations:${NC}"
echo -e "  Git tools:           $TOOLS_DIR/"
echo -e "  Wordlists:           $WORDLISTS_DIR/"
echo -e "  SecLists:            $WORDLISTS_DIR/SecLists/"
echo -e "  RockYou:             $WORDLISTS_DIR/rockyou.txt"
echo -e "  Python venv:         $VENV/"
echo -e "  Go tools:            $GOPATH/bin/"
echo -e "  Ghidra:              $TOOLS_DIR/ghidra/"
echo -e "  Metasploit:          /opt/metasploit-framework/"
echo ""
echo -e "${YELLOW}To activate the Python environment:${NC}"
echo -e "  source ~/pentest-venv/bin/activate"
echo ""
echo -e "${YELLOW}To use Docker (requires logout/login):${NC}"
echo -e "  docker run --net=host -it kalilinux/kali-rolling /bin/bash"
echo -e "  docker run --rm --net=host -it metasploitframework/metasploit-framework"
echo ""
echo -e "${RED}IMPORTANT: Change your password now with 'passwd'${NC}"
echo ""

#------------------------------------------------------------------------------
# Installed tools verification
#------------------------------------------------------------------------------
log "Verifying installed tools..."

# Count APT packages from the script that are actually installed
APT_EXPECTED_PKGS="nmap masscan arp-scan fping hping3 arping p0f dnsrecon dnsenum dnsmap dnsutils dnstracer whois nbtscan smbclient snmp onesixtyone braa traceroute tcptraceroute whatweb wafw00f sslscan dmitry netmask libimage-exiftool-perl ldap-utils fierce netdiscover ike-scan bind9-dnsutils nikto lynis afl++ yersinia sipvicious sqlmap dirb gobuster wapiti cadaver proxychains4 mitmproxy cutycapt parsero urlscan swaks mdbtools redis-tools postgresql-client john hashcat hydra medusa ncrack ophcrack patator fcrackzip pdfcrack rarcrack crunch cewl samdump2 chntpw hashid aircrack-ng wifite reaver bully pixiewps cowpatty mdk4 macchanger bluez ubertooth gnuradio hackrf rtl-sdr multimon-ng iw wavemon hcxtools hcxdumptool radare2 gdb edb-debugger ltrace strace valgrind binwalk foremost upx-ucl patchelf checksec yara apktool binutils hexedit nasm flashrom wireshark tshark ettercap-text-only bettercap dsniff ngrep tcpflow tcpreplay tcpick netsniff-ng sslsplit driftnet python3-scapy netsed weevely socat ncat sshuttle dns2tcp iodine ptunnel stunnel4 httptunnel udptunnel redsocks sslh miredo proxytunnel openvpn vpnc openconnect smbmap autopsy sleuthkit scalpel testdisk extundelete dcfldd dc3dd guymager ewf-tools afflib-tools magicrescue clamav ssdeep hashdeep xxd ghex chaosreader tcpxtract steghide stegsnow outguess exiv2 sqlitebrowser adb cherrytree recordmydesktop weasyprint docker.io tor wireguard dnsmasq apache2 nginx openssh-server mariadb-server postgresql redis-server samba chkrootkit rkhunter gddrescue tcpdump network-manager dnstwist cryptsetup"
APT_INSTALLED=0
APT_TOTAL=0
for pkg in $APT_EXPECTED_PKGS; do
    APT_TOTAL=$((APT_TOTAL + 1))
    if dpkg -l "$pkg" 2>/dev/null | grep -q "^ii"; then
        APT_INSTALLED=$((APT_INSTALLED + 1))
    fi
done

# Count Go binaries
GO_COUNT=0
if [ -d "$GOPATH/bin" ]; then
    GO_COUNT=$(find "$GOPATH/bin" -maxdepth 1 -type f -executable 2>/dev/null | wc -l)
fi

# Count git repos
GIT_COUNT=0
if [ -d "$TOOLS_DIR" ]; then
    GIT_COUNT=$(find "$TOOLS_DIR" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l)
fi

# Count pip packages in the venv
PIP_COUNT=0
if [ -f "$PIP" ]; then
    PIP_COUNT=$($PIP list --format=columns 2>/dev/null | tail -n +3 | wc -l || echo "0")
fi

APT_PERCENT=0
[ "$APT_TOTAL" -gt 0 ] && APT_PERCENT=$((APT_INSTALLED * 100 / APT_TOTAL))

echo -e "${CYAN}Installed tools verification:${NC}"
echo -e "  APT packages verified:    ${GREEN}$APT_INSTALLED/$APT_TOTAL ($APT_PERCENT%)${NC}"
echo -e "  Go binaries in ~/go/bin:  ${GREEN}$GO_COUNT${NC}"
echo -e "  Git repos in ~/tools:     ${GREEN}$GIT_COUNT${NC}"
echo -e "  Pip packages in venv:     ${GREEN}$PIP_COUNT${NC}"
echo ""

# Show tools that failed
if [ -s "$FAILED_FILE" ]; then
    # Filter empty lines from FAILED_FILE
    FAILED_CONTENT=$(grep -v '^[[:space:]]*$' "$FAILED_FILE" 2>/dev/null || true)
    if [ -n "$FAILED_CONTENT" ]; then
        echo -e "${RED}Tools that failed:${NC}"
        echo "$FAILED_CONTENT" | while IFS= read -r line; do
            echo -e "  ${RED}-${NC} $line"
        done
        echo ""
    fi
else
    echo -e "${GREEN}No installation failures were recorded.${NC}"
    echo ""
fi

log "Installation completed: $(date)"

# cryptsetup-nuke-password: Kali-exclusive package for emergency LUKS wipe
# Not available on Ubuntu and not needed for audits. Kali-only.
