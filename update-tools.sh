#!/bin/bash
#==============================================================================
# KALI TOOLS UPDATER & MISSING TOOLS CHECKER
# Updates all installed pentesting tools and checks for missing Kali packages
#
# Usage: chmod +x update-tools.sh && sudo ./update-tools.sh [--update-only|--check-only]
#==============================================================================

set +e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

REAL_USER="${SUDO_USER:-$(logname 2>/dev/null || echo $USER)}"
REAL_HOME="/home/$REAL_USER"
LOG_FILE="$REAL_HOME/kali-tools-update.log"
REPORT_FILE="$REAL_HOME/kali-tools-missing-report.txt"
VENV="$REAL_HOME/pentest-venv"
PIP="$VENV/bin/pip"
TOOLS_DIR="$REAL_HOME/tools"
export GOPATH="$REAL_HOME/go"
export PATH="$PATH:$GOPATH/bin:/usr/local/go/bin:$VENV/bin"
export GIT_TERMINAL_PROMPT=0
export DEBIAN_FRONTEND=noninteractive

# Counters
UPDATED_COUNT=0
ERROR_COUNT=0
MISSING_COUNT=0
START_TIME=$(date +%s)

# Parse flags
DO_UPDATE=true
DO_CHECK=true
case "${1:-}" in
    --update-only) DO_CHECK=false ;;
    --check-only)  DO_UPDATE=false ;;
    --help|-h)
        echo "Usage: sudo $0 [--update-only|--check-only]"
        echo "  (default)       Update all tools and check for missing Kali tools"
        echo "  --update-only   Only update installed tools"
        echo "  --check-only    Only check for missing Kali tools"
        exit 0
        ;;
    "") ;;
    *)
        echo "Unknown flag: $1. Use --help for usage."
        exit 1
        ;;
esac

# Verify root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}[-] Run as root: sudo $0${NC}"
    exit 1
fi

# Logging
echo "" > "$LOG_FILE"

log()     { echo -e "${GREEN}[+]${NC} $1" | tee -a "$LOG_FILE"; }
warn()    { echo -e "${YELLOW}[!]${NC} $1" | tee -a "$LOG_FILE"; }
error()   { echo -e "${RED}[-]${NC} $1" | tee -a "$LOG_FILE"; ((ERROR_COUNT++)); }
section() { echo -e "\n${CYAN}${BOLD}=== $1 ===${NC}" | tee -a "$LOG_FILE"; }
progress(){ echo -e "${BLUE}  -> ${NC}$1" | tee -a "$LOG_FILE"; }

log "Update started: $(date)"
log "System: $(lsb_release -ds 2>/dev/null || cat /etc/os-release | head -1) - Kernel: $(uname -r)"
log "Flags: update=$DO_UPDATE check=$DO_CHECK"

#==============================================================================
# UPDATE SECTION
#==============================================================================
if [ "$DO_UPDATE" = true ]; then

section "1/7 - APT PACKAGES"
log "Running apt-get update..."
if apt-get update -y >> "$LOG_FILE" 2>&1; then
    log "apt-get update completed"
else
    error "apt-get update failed"
fi

log "Running apt-get upgrade..."
if apt-get upgrade -y >> "$LOG_FILE" 2>&1; then
    log "apt-get upgrade completed"
    ((UPDATED_COUNT++))
else
    error "apt-get upgrade failed"
fi

apt-get autoremove -y >> "$LOG_FILE" 2>&1

#==============================================================================
section "2/7 - PYTHON PACKAGES (pentest-venv)"
#==============================================================================
if [ -f "$PIP" ]; then
    log "Upgrading pip itself..."
    $PIP install --upgrade pip setuptools wheel >> "$LOG_FILE" 2>&1 || warn "pip self-upgrade failed"

    log "Upgrading all pip packages in $VENV..."
    OUTDATED=$($PIP list --outdated --format=columns 2>/dev/null | tail -n +3 | awk '{print $1}')
    if [ -n "$OUTDATED" ]; then
        PKG_COUNT=$(echo "$OUTDATED" | wc -l)
        log "Found $PKG_COUNT outdated pip packages"
        COUNTER=0
        echo "$OUTDATED" | while read -r pkg; do
            ((COUNTER++))
            progress "[$COUNTER/$PKG_COUNT] Upgrading $pkg..."
            $PIP install --upgrade "$pkg" >> "$LOG_FILE" 2>&1 || warn "Failed to upgrade pip package: $pkg"
        done
        ((UPDATED_COUNT++))
    else
        log "All pip packages are up to date"
    fi
else
    error "Python venv not found at $VENV"
fi

#==============================================================================
section "3/7 - GO BINARIES"
#==============================================================================
log "Re-installing all Go tools at @latest..."

GO_TOOLS=(
    # ProjectDiscovery suite
    "github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest"
    "github.com/projectdiscovery/httpx/cmd/httpx@latest"
    "github.com/projectdiscovery/naabu/v2/cmd/naabu@latest"
    "github.com/projectdiscovery/dnsx/cmd/dnsx@latest"
    "github.com/projectdiscovery/tlsx/cmd/tlsx@latest"
    "github.com/projectdiscovery/asnmap/cmd/asnmap@latest"
    "github.com/projectdiscovery/mapcidr/cmd/mapcidr@latest"
    "github.com/projectdiscovery/cdncheck/cmd/cdncheck@latest"
    "github.com/projectdiscovery/alterx/cmd/alterx@latest"
    "github.com/projectdiscovery/uncover/cmd/uncover@latest"
    "github.com/projectdiscovery/cloudlist/cmd/cloudlist@latest"
    "github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest"
    "github.com/projectdiscovery/katana/cmd/katana@latest"
    "github.com/projectdiscovery/pdtm/cmd/pdtm@latest"
    "github.com/projectdiscovery/interactsh/cmd/interactsh-client@latest"
    "github.com/projectdiscovery/proxify/cmd/proxify@latest"
    "github.com/projectdiscovery/shuffledns/cmd/shuffledns@latest"
    "github.com/projectdiscovery/notify/cmd/notify@latest"
    "github.com/projectdiscovery/urlfinder/cmd/urlfinder@latest"
    "github.com/projectdiscovery/chaos-client/cmd/chaos@latest"
    "github.com/projectdiscovery/simplehttpserver/cmd/simplehttpserver@latest"
    "github.com/projectdiscovery/cvemap/cmd/cvemap@latest"
    # Other Go tools
    "github.com/owasp-amass/amass/v4/...@master"
    "github.com/tomnomnom/assetfinder@latest"
    "github.com/sundowndev/phoneinfoga/v2@latest"
    "github.com/ffuf/ffuf/v2@latest"
    "github.com/OJ/gobuster/v3@latest"
    "github.com/tomnomnom/httprobe@latest"
    "github.com/hakluke/hakrawler@latest"
    "github.com/lc/gau/v2/cmd/gau@latest"
    "github.com/tomnomnom/waybackurls@latest"
    "github.com/jaeles-project/gospider@latest"
    "github.com/hahwul/dalfox/v2@latest"
    "github.com/ropnop/kerbrute@latest"
    "github.com/jpillora/chisel@latest"
    "github.com/cgboal/sonern/cmd/crobat@latest"
    "github.com/sensepost/godoh@latest"
    "github.com/rverton/webanalyze/cmd/webanalyze@latest"
    "github.com/dwisiswant0/crlfuzz/cmd/crlfuzz@latest"
    "github.com/aquasecurity/trivy/cmd/trivy@latest"
    "github.com/sensepost/gowitness@latest"
    "github.com/ar-emre/goshs@latest"
    "github.com/tomnomnom/anew@latest"
    "github.com/tomnomnom/gf@latest"
    "github.com/tomnomnom/qsreplace@latest"
    "github.com/tomnomnom/unfurl@latest"
)

GO_TOTAL=${#GO_TOOLS[@]}
GO_COUNTER=0
GO_FAIL=0
for tool in "${GO_TOOLS[@]}"; do
    ((GO_COUNTER++))
    TOOL_NAME=$(echo "$tool" | awk -F'/' '{print $NF}' | cut -d'@' -f1)
    progress "[$GO_COUNTER/$GO_TOTAL] $TOOL_NAME"
    if sudo -u "$REAL_USER" bash -c "export GOPATH=$GOPATH; export PATH=\$PATH:$GOPATH/bin:/usr/local/go/bin; go install $tool" >> "$LOG_FILE" 2>&1; then
        :
    else
        warn "Failed to update Go tool: $TOOL_NAME"
        ((GO_FAIL++))
    fi
done
log "Go tools updated: $((GO_TOTAL - GO_FAIL))/$GO_TOTAL succeeded"
((UPDATED_COUNT++))

#==============================================================================
section "4/7 - GIT REPOSITORIES (~/tools/)"
#==============================================================================
if [ -d "$TOOLS_DIR" ]; then
    GIT_REPOS=0
    GIT_UPDATED=0
    GIT_FAILED=0

    for dir in "$TOOLS_DIR"/*/; do
        [ ! -d "$dir/.git" ] && continue
        ((GIT_REPOS++))
        REPO_NAME=$(basename "$dir")
        progress "Pulling $REPO_NAME..."
        if sudo -u "$REAL_USER" git -C "$dir" pull --ff-only >> "$LOG_FILE" 2>&1; then
            ((GIT_UPDATED++))
        else
            # Try reset if ff-only fails (shallow clone issues)
            if sudo -u "$REAL_USER" git -C "$dir" pull >> "$LOG_FILE" 2>&1; then
                ((GIT_UPDATED++))
            else
                warn "Failed to update git repo: $REPO_NAME"
                ((GIT_FAILED++))
            fi
        fi
    done

    # Also update wordlists/SecLists if it exists
    if [ -d "$REAL_HOME/wordlists/SecLists/.git" ]; then
        progress "Pulling SecLists..."
        sudo -u "$REAL_USER" git -C "$REAL_HOME/wordlists/SecLists" pull >> "$LOG_FILE" 2>&1 || warn "SecLists pull failed"
        ((GIT_REPOS++))
        ((GIT_UPDATED++))
    fi

    log "Git repos updated: $GIT_UPDATED/$GIT_REPOS succeeded ($GIT_FAILED failed)"
    ((UPDATED_COUNT++))
else
    warn "Tools directory $TOOLS_DIR not found"
fi

#==============================================================================
section "5/7 - RUBY GEMS"
#==============================================================================
GEMS=(wpscan evil-winrm haiti-hash one_gadget zsteg)
GEM_TOTAL=${#GEMS[@]}
GEM_COUNTER=0
for gem_name in "${GEMS[@]}"; do
    ((GEM_COUNTER++))
    progress "[$GEM_COUNTER/$GEM_TOTAL] Updating $gem_name..."
    if gem update "$gem_name" >> "$LOG_FILE" 2>&1; then
        :
    else
        warn "Failed to update gem: $gem_name"
    fi
done
log "Ruby gems update completed"
((UPDATED_COUNT++))

#==============================================================================
section "6/7 - SNAP PACKAGES"
#==============================================================================
if command -v snap &>/dev/null; then
    log "Refreshing snap packages..."
    if snap refresh >> "$LOG_FILE" 2>&1; then
        log "Snap packages updated"
    else
        warn "Some snap refreshes may have failed"
    fi
    ((UPDATED_COUNT++))
else
    warn "snap not found, skipping"
fi

#==============================================================================
section "7/7 - METASPLOIT & NUCLEI TEMPLATES"
#==============================================================================
if command -v msfupdate &>/dev/null; then
    log "Updating Metasploit Framework..."
    if msfupdate >> "$LOG_FILE" 2>&1; then
        log "Metasploit updated"
        ((UPDATED_COUNT++))
    else
        error "Metasploit update failed"
    fi
elif [ -f /opt/metasploit-framework/bin/msfupdate ]; then
    log "Updating Metasploit Framework..."
    if /opt/metasploit-framework/bin/msfupdate >> "$LOG_FILE" 2>&1; then
        log "Metasploit updated"
        ((UPDATED_COUNT++))
    else
        error "Metasploit update failed"
    fi
else
    warn "msfupdate not found, skipping Metasploit update"
fi

if command -v nuclei &>/dev/null || [ -f "$GOPATH/bin/nuclei" ]; then
    NUCLEI_BIN="nuclei"
    [ -f "$GOPATH/bin/nuclei" ] && NUCLEI_BIN="$GOPATH/bin/nuclei"
    log "Updating nuclei templates..."
    if sudo -u "$REAL_USER" "$NUCLEI_BIN" -update-templates >> "$LOG_FILE" 2>&1; then
        log "Nuclei templates updated"
        ((UPDATED_COUNT++))
    else
        warn "Nuclei template update failed"
    fi
else
    warn "nuclei not found, skipping template update"
fi

fi  # end DO_UPDATE

#==============================================================================
# MISSING TOOLS CHECK SECTION
#==============================================================================
if [ "$DO_CHECK" = true ]; then

section "CHECKING FOR MISSING KALI TOOLS"
log "Comparing installed tools against Kali metapackage tool lists..."

# Comprehensive list of tools from Kali Linux metapackages (kali-tools-*)
# This is the reference list based on official Kali metapackages
KALI_TOOLS_LIST=(
    # kali-tools-information-gathering
    nmap masscan arp-scan fping hping3 arping p0f
    dnsrecon dnsenum dnsmap dnsutils dnstracer whois
    nbtscan enum4linux smbclient
    snmp onesixtyone braa
    traceroute tcptraceroute
    whatweb wafw00f sslscan
    dmitry netmask intrace
    libimage-exiftool-perl
    ldap-utils
    fierce lbd
    netdiscover
    ike-scan
    dirbuster
    bind9-dnsutils
    0trace irpas metagoofil smbmap unicornscan
    zenmap urlcrazy twofi tlssled ssldump
    firewalk ftester qsslcaudit
    amap altdns arpwatch asleap
    bing-ip2hosts
    cmseek cntlm
    dnswalk
    eapmd5pass exifprobe
    fiked findomain fragrouter
    goofile graudit gtkhash
    horst hosthunter httprint
    ident-user-enum
    knocker
    massdns
    pnscan
    tiger

    # kali-tools-vulnerability
    nikto lynis
    afl++
    exploitdb
    yersinia
    sipvicious
    skipfish
    spike
    voiphopper
    unix-privesc-check
    bed cisco-auditing-tool cisco-global-exploiter cisco-ocs cisco-torch
    copy-router-config dhcpig
    slowhttptest t50 siege
    iaxflood inviteflood
    sctpscan siparmyknife sipp sipsak sipcrack
    gvm

    # kali-tools-web
    sqlmap
    dirb gobuster
    wapiti
    commix
    cadaver davtest
    proxychains4
    mitmproxy
    cutycapt
    parsero
    urlscan
    swaks
    smtp-user-enum sendemail
    apache-users dotdotpwn padbuster
    httrack
    joomscan jsql-injection
    sqlninja sqlsus sqldict
    oscanner sidguesser tnscmd10g
    uniscan webacoo webscarab
    xsser

    # kali-tools-database
    mdbtools
    redis-tools
    postgresql-client
    sqlitebrowser

    # kali-tools-passwords
    john hashcat hashcat-utils
    hydra medusa ncrack
    ophcrack ophcrack-cli
    patator
    fcrackzip pdfcrack rarcrack
    crunch
    cewl
    rsmangler
    samdump2
    chntpw
    hash-identifier hashid
    seclists
    wordlists
    maskprocessor statsprocessor
    thc-pptp-bruter
    cmospwd gpp-decrypt
    johnny
    pack rainbowcrack
    sucrack

    # kali-tools-wireless
    aircrack-ng
    kismet
    wifite
    fern-wifi-cracker
    reaver bully
    pixiewps
    cowpatty
    mdk4
    macchanger
    spooftooph
    bluez
    btscanner
    ubertooth
    gnuradio gqrx-sdr
    hackrf rtl-sdr
    multimon-ng
    iw wavemon wireless-regdb wireless-tools
    hcxtools hcxdumptool

    # kali-tools-reverse-engineering
    radare2 rizin
    gdb
    edb-debugger
    ltrace strace
    valgrind
    binwalk
    foremost
    upx-ucl
    patchelf
    checksec
    yara python3-yara
    apktool dex2jar smali
    jadx
    binutils
    hexedit
    nasm
    python3-pefile python3-capstone
    flashrom
    jd-gui bytecode-viewer javasnoop

    # kali-tools-exploitation
    armitage shellnoob termineter

    # kali-tools-sniffing-spoofing
    wireshark tshark
    ettercap-graphical ettercap-text-only
    bettercap
    dsniff
    ngrep
    tcpflow tcpreplay tcpick
    netsniff-ng
    hexinject
    sslsplit
    dnschef
    driftnet
    python3-scapy
    rebind
    netsed
    darkstat above
    sniffjoke sslsniff
    hamster-sidejack ferret-sidejack
    isr-evilgrade
    wifi-honey

    # kali-tools-post-exploitation
    weevely
    webshells
    socat ncat netcat-traditional
    cryptcat
    sshuttle
    dns2tcp
    iodine
    ptunnel
    stunnel4
    httptunnel udptunnel
    redsocks
    sslh
    pwnat
    miredo
    proxytunnel
    openvpn
    cymothoa dbd sbd
    exe2hexbat laudanum
    shellter veil
    powershell

    # kali-tools-forensics
    autopsy sleuthkit
    scalpel
    testdisk
    extundelete
    dcfldd dc3dd
    guymager
    ewf-tools
    afflib-tools
    bulk-extractor
    magicrescue
    clamav
    ssdeep hashdeep
    xxd ghex
    chaosreader
    tcpxtract
    steghide stegsnow
    outguess
    exiv2
    chkrootkit rkhunter
    ddrescue
    ext3grep
    galleta
    gpart grokevt
    mac-robber memdump metacam
    missidentify myrescue nasty
    pasco pdf-parser pdfid
    pst-utils
    readpe recoverdm recoverjpeg
    reglookup rephrase
    rifiuti rifiuti2
    rsakeyfind
    safecopy scrounge-ntfs
    truecrack undbx unhide
    vinetto wce winregfs
    xmount xplico
    forensic-artifacts forensics-colorize
    plaso

    # kali-tools-reporting
    cherrytree
    recordmydesktop
    weasyprint

    # kali-tools-social-engineering
    # (SET is git-cloned, not apt)

    # kali-tools-bluetooth
    blue-hydra bluelog blueranger bluesnarfer
    crackle redfang

    # kali-tools-crypto-stego
    aesfix aeskeyfind ccrypt stegosuite

    # kali-tools-sdr
    chirp inspectrum
    gr-osmosdr
    kalibrate-rtl
    uhd-host

    # kali-tools-rfid
    proxmark3 libnfc-bin mfoc mfcuk mfterm

    # kali-tools-voip
    enumiax ohrwurm
    protos-sip rtpbreak rtpflood
    rtpinsertsound rtpmixsound

    # kali-tools-protect
    cryptsetup cryptsetup-initramfs
    fwbuilder

    # System services from install script
    docker.io docker-compose
    tor
    wireguard
    dnsmasq
    pure-ftpd
    atftpd tftp-hpa
    apache2 nginx
    openssh-server
    mariadb-server
    postgresql
    redis-server
    samba
    snmpd
    nfs-common
    rpcbind
    inetsim
    mosquitto
    sqsh
    freerdp3-x11
    tightvncserver xtightvncviewer

    # Base development/system tools
    build-essential gcc g++ make cmake
    python3 python3-pip python3-venv python3-dev
    ruby ruby-dev rubygems
    golang-go
    default-jdk default-jre
    php php-cli
    nodejs npm
    perl
    clang llvm
    gcc-mingw-w64
    subversion
    pipx
    tmux screen jq tree net-tools
    vim nano
    imagemagick ghostscript graphviz
    gparted gdisk
    htop lsof sysstat smartmontools
    dos2unix figlet
    iproute2 ethtool vlan
    iptables nftables
    easy-rsa opensc
    ftp telnet rdesktop
    minicom
    axel

    # Additional packages from install script
    tcpdump
    network-manager
    bundler
    adb
    legion
    dnstwist dnsgen
    changeme
    crowbar brutespray
    bruteforce-luks bruteforce-salted-openssl bruteforce-wallet
    gdb-peda
    libfindrtp0
    hashrat
    imhex
    cifs-utils
    dislocker
    lvm2 parted
)

# Deduplicate the list
KALI_TOOLS_UNIQUE=($(printf '%s\n' "${KALI_TOOLS_LIST[@]}" | sort -u))

log "Checking ${#KALI_TOOLS_UNIQUE[@]} packages from Kali metapackage lists..."

MISSING_TOOLS=()
INSTALLED_TOOLS=()

for pkg in "${KALI_TOOLS_UNIQUE[@]}"; do
    if dpkg -l "$pkg" 2>/dev/null | grep -q "^ii"; then
        INSTALLED_TOOLS+=("$pkg")
    else
        MISSING_TOOLS+=("$pkg")
    fi
done

MISSING_COUNT=${#MISSING_TOOLS[@]}
INSTALLED_COUNT=${#INSTALLED_TOOLS[@]}

log "Installed: $INSTALLED_COUNT / ${#KALI_TOOLS_UNIQUE[@]} Kali packages"
log "Missing:   $MISSING_COUNT packages"

# Generate report
{
    echo "============================================"
    echo " KALI TOOLS MISSING REPORT"
    echo " Generated: $(date)"
    echo " System: $(lsb_release -ds 2>/dev/null || echo 'Unknown')"
    echo "============================================"
    echo ""
    echo "SUMMARY"
    echo "-------"
    echo "Total Kali packages checked: ${#KALI_TOOLS_UNIQUE[@]}"
    echo "Installed:                    $INSTALLED_COUNT"
    echo "Missing:                      $MISSING_COUNT"
    echo ""
    echo "NOTE: Some packages are Kali-exclusive and may not be available"
    echo "in Ubuntu repositories. Install what is available and ignore"
    echo "packages that are not found."
    echo ""
    echo "MISSING PACKAGES"
    echo "-----------------"
    for pkg in $(printf '%s\n' "${MISSING_TOOLS[@]}" | sort); do
        echo "  - $pkg"
    done
    echo ""
    echo "SUGGESTED INSTALL COMMAND"
    echo "-------------------------"
    echo "sudo apt-get install -y \\"
    COLS=0
    LINE="    "
    for pkg in $(printf '%s\n' "${MISSING_TOOLS[@]}" | sort); do
        LINE="$LINE $pkg"
        ((COLS++))
        if [ $COLS -ge 6 ]; then
            echo "$LINE \\"
            LINE="    "
            COLS=0
        fi
    done
    [ -n "$(echo "$LINE" | tr -d ' ')" ] && echo "$LINE"
    echo ""
    echo "============================================"
    echo " Tools installed via other methods (not apt)"
    echo "============================================"
    echo ""
    echo "Go binaries in $GOPATH/bin/:"
    ls "$GOPATH/bin/" 2>/dev/null | sed 's/^/  - /' || echo "  (none found)"
    echo ""
    echo "Git repos in $TOOLS_DIR/:"
    ls "$TOOLS_DIR/" 2>/dev/null | sed 's/^/  - /' || echo "  (none found)"
    echo ""
    echo "Python packages in $VENV:"
    $PIP list --format=columns 2>/dev/null | tail -n +3 | awk '{print "  - "$1" ("$2")"}' || echo "  (none found)"
    echo ""
    echo "Ruby gems (security-related):"
    for g in wpscan evil-winrm haiti-hash one_gadget zsteg; do
        ver=$(gem list "$g" --local 2>/dev/null | grep "$g" | head -1)
        [ -n "$ver" ] && echo "  - $ver" || echo "  - $g (not installed)"
    done
    echo ""
    echo "Snap packages:"
    snap list 2>/dev/null | tail -n +2 | awk '{print "  - "$1" ("$2")"}' || echo "  (none found)"
    echo ""
} > "$REPORT_FILE"

chown "$REAL_USER:$REAL_USER" "$REPORT_FILE"

log "Missing tools report saved to: $REPORT_FILE"

if [ $MISSING_COUNT -gt 0 ]; then
    echo ""
    echo -e "${YELLOW}${BOLD}Missing Kali packages ($MISSING_COUNT):${NC}"
    for pkg in $(printf '%s\n' "${MISSING_TOOLS[@]}" | sort); do
        echo -e "  ${RED}-${NC} $pkg"
    done
    echo ""
    echo -e "${CYAN}Quick install attempt:${NC}"
    echo -e "  sudo apt-get install -y $(printf '%s ' "${MISSING_TOOLS[@]}" | head -c 500)..."
    echo -e "  (Full command in $REPORT_FILE)"
fi

fi  # end DO_CHECK

#==============================================================================
# FINAL SUMMARY
#==============================================================================
END_TIME=$(date +%s)
ELAPSED=$(( END_TIME - START_TIME ))
MINUTES=$(( ELAPSED / 60 ))
SECONDS_REM=$(( ELAPSED % 60 ))

echo ""
echo -e "${GREEN}${BOLD}============================================${NC}"
echo -e "${GREEN}${BOLD}  UPDATE COMPLETE${NC}"
echo -e "${GREEN}${BOLD}============================================${NC}"
echo ""
echo -e "  Duration:         ${CYAN}${MINUTES}m ${SECONDS_REM}s${NC}"

if [ "$DO_UPDATE" = true ]; then
    echo -e "  Update groups:    ${CYAN}${UPDATED_COUNT} completed${NC}"
    echo -e "  Errors:           ${RED}${ERROR_COUNT}${NC}"
fi

if [ "$DO_CHECK" = true ]; then
    echo -e "  Missing Kali pkgs:${YELLOW} ${MISSING_COUNT}${NC}"
    echo -e "  Report:           ${CYAN}${REPORT_FILE}${NC}"
fi

echo -e "  Log:              ${CYAN}${LOG_FILE}${NC}"
echo ""

chown "$REAL_USER:$REAL_USER" "$LOG_FILE"

log "Update finished: $(date)"
