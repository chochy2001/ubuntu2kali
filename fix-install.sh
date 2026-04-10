#!/bin/bash
#==============================================================================
# FIX SCRIPT for install-kali-tools.sh
# Repairs only the items that failed during the original run:
#   1. pentest-venv creation + all pip installs
#   2. SecLists clone (permission denied on wordlists dir)
#   3. exploitdb gitlab repos (stuck on auth prompt)
#   4. phoneinfoga (skipped - known build issue)
#   5. Step 19 (PATH config) and Step 20 (permissions/cleanup)
#==============================================================================

set +e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

REAL_USER="${SUDO_USER:-$(logname 2>/dev/null || echo $USER)}"
REAL_HOME="/home/$REAL_USER"
LOG_FILE="$REAL_HOME/kali-tools-fix.log"
export GIT_TERMINAL_PROMPT=0

log() { echo -e "${GREEN}[+]${NC} $1" | tee -a "$LOG_FILE"; }
warn() { echo -e "${YELLOW}[!]${NC} $1" | tee -a "$LOG_FILE"; }
error() { echo -e "${RED}[-]${NC} $1" | tee -a "$LOG_FILE"; }
section() { echo -e "\n${CYAN}=== $1 ===${NC}" | tee -a "$LOG_FILE"; }

# Verify root
if [ "$EUID" -ne 0 ]; then
    echo "Run as root: sudo ./fix-install.sh"
    exit 1
fi

echo "" > "$LOG_FILE"
log "Repair started: $(date)"
log "System: $(lsb_release -ds 2>/dev/null || echo 'unknown') - Kernel: $(uname -r)"

#==============================================================================
section "FIX 1: CREATE PENTEST-VENV AND INSTALL ALL PIP PACKAGES"
#==============================================================================

VENV="$REAL_HOME/pentest-venv"

# Ensure python3.12-venv is installed before creating venv
log "Verifying python3.12-venv..."
apt-get install -y python3.12-venv python3-venv 2>&1 | tail -3 || true

# Remove broken venv if it exists but is incomplete
if [ -d "$VENV" ] && [ ! -f "$VENV/bin/pip" ]; then
    log "Removing broken venv at $VENV..."
    rm -rf "$VENV"
fi

# Create venv as the real user
if [ ! -d "$VENV" ]; then
    log "Creating pentest-venv..."
    sudo -u "$REAL_USER" python3 -m venv "$VENV"
    if [ $? -ne 0 ]; then
        error "FATAL: Could not create the venv. Aborting."
        exit 1
    fi
    log "pentest-venv created successfully at $VENV"
else
    log "pentest-venv already exists at $VENV"
fi

PIP="$VENV/bin/pip"

# Verify pip works
if [ ! -f "$PIP" ]; then
    error "FATAL: $PIP does not exist after creating the venv."
    exit 1
fi

log "Upgrading pip, setuptools, wheel..."
$PIP install --upgrade pip setuptools wheel 2>&1 | tail -3

# --- Step 1: Information Gathering (pip) ---
log "Installing pip packages: Information Gathering..."
$PIP install \
    shodan censys theharvester \
    dnsrecon sublist3r \
    sslyze \
    enum4linux-ng \
    knockpy \
    wafw00f \
    sherlock-project \
    2>&1 | tail -5 || warn "Some info gathering pip packages failed"

# --- Step 2: Vulnerability Analysis (pip) ---
log "Installing pip packages: Vulnerability Analysis..."
$PIP install \
    wfuzz \
    boofuzz \
    vulners \
    2>&1 | tail -5 || warn "Some vuln analysis pip packages failed"

# --- Step 3: Web Application Analysis (pip) ---
log "Installing pip packages: Web Application..."
$PIP install \
    sqlmap \
    dirsearch \
    arjun \
    paramspider \
    mitmproxy \
    2>&1 | tail -5 || warn "Some web pip packages failed"

# --- Step 4: Database Assessment (pip) ---
log "Installing pip packages: Database Assessment..."
$PIP install \
    mongoaudit pgcli mycli \
    2>&1 | tail -5 || warn "Some DB pip packages failed"

# --- Step 5: Password Attacks (pip) ---
log "Installing pip packages: Password Attacks..."
$PIP install \
    hashid \
    pypykatz \
    lsassy \
    netexec \
    2>&1 | tail -5 || warn "Some password pip packages failed"

# --- Step 7: Reverse Engineering (pip) ---
log "Installing pip packages: Reverse Engineering..."
$PIP install \
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
    volatility3 \
    2>&1 | tail -5 || warn "Some reverse engineering pip packages failed"

# --- Step 8: Exploitation Tools (pip) ---
log "Installing pip packages: Exploitation Tools..."
$PIP install \
    pwntools \
    impacket \
    netexec \
    certipy-ad \
    coercer \
    bloodyad \
    ldapdomaindump \
    dploot \
    pwncat-cs \
    routersploit \
    2>&1 | tail -5 || warn "Some exploitation pip packages failed"

# --- Step 11: Forensics (pip) ---
log "Installing pip packages: Forensics..."
$PIP install \
    volatility3 \
    oletools \
    pdfid \
    pdf-parser \
    stegoveritas \
    2>&1 | tail -5 || warn "Some forensics pip packages failed"

# --- Step 12: Reporting (pip) ---
log "Installing pip packages: Reporting..."
$PIP install \
    faradaysec mkdocs \
    2>&1 | tail -5 || warn "Some reporting pip packages failed"

# --- Step 13: SET requirements ---
log "Installing pip packages: SET requirements..."
TOOLS_DIR="$REAL_HOME/tools"
if [ -d "$TOOLS_DIR/social-engineer-toolkit" ] && [ -f "$TOOLS_DIR/social-engineer-toolkit/requirements.txt" ]; then
    $PIP install -r "$TOOLS_DIR/social-engineer-toolkit/requirements.txt" 2>&1 | tail -5 || warn "SET requirements failed"
else
    warn "social-engineer-toolkit not found, skipping requirements.txt"
fi

# --- Step 17: Large pip batch ---
log "Installing pip packages: Large batch..."
$PIP install \
    name-that-hash \
    h8mail \
    osrframework \
    crackmapexec \
    pocsuite3 \
    instaloader \
    pompem \
    spraykatz \
    poshc2 \
    sploitscan \
    trufflehog \
    redsnarf \
    phpsploit \
    phpggc \
    s3scanner \
    pacu \
    2>&1 | tail -5 || warn "Some large batch pip packages failed"

# --- Cloud/container security (pip) ---
log "Installing pip packages: Cloud security..."
$PIP install \
    scoutsuite \
    prowler \
    2>&1 | tail -5 || warn "Cloud tools pip packages failed"

# --- Last batch (pip) ---
log "Installing pip packages: Final batch..."
$PIP install \
    emailharvester \
    faraday-cli \
    faraday-agent-dispatcher \
    humble \
    2>&1 | tail -5 || warn "Some final batch pip packages failed"

# --- bloodhound standalone ---
log "Installing pip packages: bloodhound..."
$PIP install bloodhound 2>&1 | tail -3 || warn "bloodhound pip failed"

# --- Kali 2026.1 tools (pip) ---
log "Installing pip packages: Kali 2026.1..."
$PIP install sstimap 2>&1 | tail -3 || warn "sstimap pip failed"
$PIP install autorecon 2>&1 | tail -3 || warn "autorecon pip failed"

# --- Additional pip tools ---
log "Installing pip packages: Additional..."
$PIP install \
    bloodhound \
    mitm6 \
    scapy \
    requests beautifulsoup4 \
    paramiko cryptography \
    spiderfoot \
    recon-ng \
    shodan censys \
    pyinstaller \
    2>&1 | tail -5 || warn "Some additional pip packages failed"

# --- Extra pip tools ---
log "Installing pip packages: Extras..."
$PIP install \
    wpscan-out-parse \
    droopescan \
    bbqsql \
    dirsearch \
    ghauri \
    pwncat-cs \
    sshuttle \
    fierce \
    dnsgen \
    2>&1 | tail -5 || warn "Some extra pip packages failed"

log "All pip packages processed."

#==============================================================================
section "FIX 2: SECLISTS CLONE (PERMISSION FIX)"
#==============================================================================

WORDLISTS_DIR="$REAL_HOME/wordlists"

log "Fixing permissions on $WORDLISTS_DIR..."
mkdir -p "$WORDLISTS_DIR"
chown "$REAL_USER:$REAL_USER" "$WORDLISTS_DIR"

if [ ! -d "$WORDLISTS_DIR/SecLists" ]; then
    log "Cloning SecLists..."
    sudo -u "$REAL_USER" git clone --depth 1 https://github.com/danielmiessler/SecLists.git "$WORDLISTS_DIR/SecLists" 2>&1 | tail -3
    if [ $? -eq 0 ]; then
        log "SecLists cloned successfully"
    else
        error "SecLists clone failed"
    fi
else
    log "SecLists already exists at $WORDLISTS_DIR/SecLists"
fi

#==============================================================================
section "FIX 3: EXPLOITDB REPOS (GIT_TERMINAL_PROMPT=0)"
#==============================================================================

cd "$TOOLS_DIR" 2>/dev/null || { mkdir -p "$TOOLS_DIR"; chown "$REAL_USER:$REAL_USER" "$TOOLS_DIR"; cd "$TOOLS_DIR"; }

if [ ! -d "$TOOLS_DIR/exploitdb-bin-sploits" ]; then
    log "Cloning exploitdb-bin-sploits (no auth prompt)..."
    sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 git clone --depth 1 https://gitlab.com/exploit-database/exploitdb-bin-sploits.git "$TOOLS_DIR/exploitdb-bin-sploits" 2>&1 | tail -3
    if [ $? -eq 0 ]; then
        log "exploitdb-bin-sploits cloned successfully"
    else
        warn "exploitdb-bin-sploits clone failed (may require authenticated access to gitlab)"
    fi
else
    log "exploitdb-bin-sploits already exists"
fi

if [ ! -d "$TOOLS_DIR/exploitdb-papers" ]; then
    log "Cloning exploitdb-papers (no auth prompt)..."
    sudo -u "$REAL_USER" env GIT_TERMINAL_PROMPT=0 git clone --depth 1 https://gitlab.com/exploit-database/exploitdb-papers.git "$TOOLS_DIR/exploitdb-papers" 2>&1 | tail -3
    if [ $? -eq 0 ]; then
        log "exploitdb-papers cloned successfully"
    else
        warn "exploitdb-papers clone failed (may require authenticated access to gitlab)"
    fi
else
    log "exploitdb-papers already exists"
fi

#==============================================================================
section "FIX 4: PHONEINFOGA (SKIP)"
#==============================================================================

warn "phoneinfoga: OMITIDO - known build issue (web/client.go pattern client/dist/* no matching files)"
warn "To install manually: see https://github.com/sundowndev/phoneinfoga#installation"

#==============================================================================
section "FIX 5: STEP 19 - PATH CONFIGURATION"
#==============================================================================

log "Configuring PATH and aliases..."
PROFILE_FILE="$REAL_HOME/.zshrc"
[ ! -f "$PROFILE_FILE" ] && PROFILE_FILE="$REAL_HOME/.bashrc"

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
else
    log "PATH was already configured in $PROFILE_FILE"
fi

#==============================================================================
section "FIX 6: STEP 20 - PERMISSIONS AND CLEANUP"
#==============================================================================

log "Adjusting permissions..."
chown -R "$REAL_USER:$REAL_USER" "$REAL_HOME/go" 2>/dev/null || true
chown -R "$REAL_USER:$REAL_USER" "$TOOLS_DIR" 2>/dev/null || true
chown -R "$REAL_USER:$REAL_USER" "$WORDLISTS_DIR" 2>/dev/null || true
chown -R "$REAL_USER:$REAL_USER" "$VENV" 2>/dev/null || true

log "Cleaning cache..."
apt-get autoremove -y 2>&1 | tail -1
apt-get autoclean -y 2>&1 | tail -1

#==============================================================================
section "REPAIR SUMMARY"
#==============================================================================

echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  REPAIR COMPLETED${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo -e "Log: ${CYAN}$LOG_FILE${NC}"
echo ""

# Verify status
echo -e "${CYAN}Verification:${NC}"

if [ -f "$VENV/bin/pip" ]; then
    PIP_COUNT=$($PIP list 2>/dev/null | wc -l || echo "0")
    echo -e "  ${GREEN}[OK]${NC} pentest-venv: $PIP_COUNT packages installed"
else
    echo -e "  ${RED}[FAIL]${NC} pentest-venv: pip not found"
fi

if [ -d "$WORDLISTS_DIR/SecLists" ]; then
    echo -e "  ${GREEN}[OK]${NC} SecLists cloned"
else
    echo -e "  ${RED}[FAIL]${NC} SecLists not found"
fi

if [ -d "$TOOLS_DIR/exploitdb-bin-sploits" ]; then
    echo -e "  ${GREEN}[OK]${NC} exploitdb-bin-sploits cloned"
else
    echo -e "  ${YELLOW}[WARN]${NC} exploitdb-bin-sploits not cloned (may require auth)"
fi

if [ -d "$TOOLS_DIR/exploitdb-papers" ]; then
    echo -e "  ${GREEN}[OK]${NC} exploitdb-papers cloned"
else
    echo -e "  ${YELLOW}[WARN]${NC} exploitdb-papers not cloned (may require auth)"
fi

if grep -q "pentest-venv" "$PROFILE_FILE" 2>/dev/null; then
    echo -e "  ${GREEN}[OK]${NC} PATH configured in $PROFILE_FILE"
else
    echo -e "  ${RED}[FAIL]${NC} PATH not configured"
fi

echo -e "  ${YELLOW}[SKIP]${NC} phoneinfoga (known build issue)"
echo ""

GOPATH="$REAL_HOME/go"
GO_COUNT=$(ls "$GOPATH/bin/" 2>/dev/null | wc -l || echo "0")
GIT_COUNT=$(ls "$TOOLS_DIR/" 2>/dev/null | wc -l || echo "0")

echo -e "${CYAN}Installed tools (approx):${NC}"
echo -e "  Go binaries:     $GO_COUNT"
echo -e "  Git repos:       $GIT_COUNT"
echo -e "  Python packages: $PIP_COUNT"
echo ""
echo -e "${YELLOW}To activate the Python environment:${NC}"
echo -e "  source ~/pentest-venv/bin/activate"
echo ""

log "Repair finished: $(date)"
