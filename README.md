```
         _                 _        ____  _         _ _
  _   _ | |__  _   _ _ __ | |_ _   |___ \| | ____ _| (_)
 | | | || '_ \| | | | '_ \| __| | | |__) | |/ / _` | | |
 | |_| || |_) | |_| | | | | |_| |_| / __/|   < (_| | | |
  \__,_||_.__/ \__,_|_| |_|\__|\__,_|_____|_|\_\__,_|_|_|
```

# ubuntu2kali

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![OS: Ubuntu 24.04](https://img.shields.io/badge/OS-Ubuntu%2024.04-E95420?logo=ubuntu&logoColor=white)](https://ubuntu.com/)
[![Shell Script](https://img.shields.io/badge/Shell-Bash-4EAA25?logo=gnubash&logoColor=white)](install-kali-tools.sh)
[![GitHub Stars](https://img.shields.io/github/stars/chochy2001/ubuntu2kali?style=social)](https://github.com/chochy2001/ubuntu2kali)

**Transform your Ubuntu 24.04 machine into a complete penetration testing workstation with 500+ Kali Linux tools -- no need to reinstall your OS.**

ubuntu2kali is a single Bash script that installs, configures, and organizes the full arsenal of Kali Linux security tools on a standard Ubuntu 24.04 system. It covers 22 categories ranging from reconnaissance to forensics, setting up everything inside a clean directory structure with isolated Python virtual environments and properly configured Go paths.

---

## Features

- Installs 500+ penetration testing and security tools across 22 categories
- Supports multiple installation methods: apt, pip (inside a venv), Go, Ruby gems, git clone, snap, and direct binary downloads
- Creates an isolated Python virtual environment (`~/pentest-venv`) to avoid polluting your system
- Organizes cloned repositories under `~/tools` and wordlists under `~/wordlists`
- Configures Go toolchain with `GOPATH` at `~/go`
- Disables network services (SSH, Apache, Nginx, databases) after install for security -- enable them only when needed
- Adds Docker group membership for convenient container usage
- Installs Metasploit Framework, Burp Suite Community, Ghidra, and CyberChef
- Comprehensive logging to `~/kali-tools-install.log` with failures tracked in `~/kali-tools-failed.log`
- Configures PATH and shell aliases automatically

---

## Prerequisites

Before running the installer, make sure you have the following:

- **Ubuntu 24.04 LTS** (fresh or existing install)
- **Root / sudo access** -- the script must be run as root
- **At least 20GB free disk space** (recommended: 50GB+, full install can use 40-60GB)
- **Stable internet connection** -- required throughout the entire installation (typically 45 minutes to 2+ hours depending on connection speed)
- **SSH key configured for GitHub** (REQUIRED for cloning repositories). The script will auto-generate an SSH key if none exists, but you **MUST** add it to your GitHub account before running the installer. To set up manually:
  ```bash
  ssh-keygen -t ed25519 -C "your_email@example.com"
  eval "$(ssh-agent -s)"
  ssh-add ~/.ssh/id_ed25519
  ```
  Then add the public key (`~/.ssh/id_ed25519.pub`) to your GitHub account under **Settings > SSH and GPG keys**. Test your connection with:
  ```bash
  ssh -T git@github.com
  ```
- **`python3.12-venv` package** -- required for creating the isolated Python environment. The script installs this automatically if missing.

**Note:** Some Kali-exclusive packages will show "Unable to locate package" warnings during installation. This is normal and expected, as those packages are only available in Kali Linux repositories. The script handles these gracefully and logs them to `~/kali-tools-failed.log`.

**Note:** The script uses dynamic user detection -- it works for any user, not just a specific hardcoded username.

---

## Quick Install

```bash
git clone https://github.com/chochy2001/ubuntu2kali.git
cd ubuntu2kali
chmod +x install-kali-tools.sh
sudo ./install-kali-tools.sh
```

Or as a one-liner:

```bash
git clone https://github.com/chochy2001/ubuntu2kali.git && cd ubuntu2kali && sudo ./install-kali-tools.sh
```

---

## Requirements

| Requirement | Details |
|---|---|
| Operating System | Ubuntu 24.04 LTS (Noble Numbat) |
| Architecture | x86_64 / amd64 |
| Privileges | Root (the script must be run with `sudo`) |
| Disk Space | At least 50 GB free (recommended: 80+ GB) |
| RAM | 4 GB minimum, 8+ GB recommended |
| Internet | Required throughout the entire installation |
| Time | 1-3 hours depending on connection speed |

---

## What Gets Installed

The script is organized into 22 steps. The table below summarizes each category with approximate tool counts and notable examples.

| # | Category | Tool Count (approx.) | Example Tools |
|---|---|---|---|
| 0 | System Preparation | 80+ | build-essential, python3, golang-go, ruby, nodejs, cmake, tmux, docker |
| 1 | Information Gathering | 50+ | nmap, masscan, subfinder, amass, httpx, dnsenum, theHarvester, sherlock |
| 2 | Vulnerability Analysis | 15+ | nikto, nuclei, lynis, OpenVAS/GVM, wfuzz, boofuzz, afl++ |
| 3 | Web Application Analysis | 35+ | sqlmap, ffuf, gobuster, katana, Burp Suite, WPScan, XSStrike, dalfox |
| 4 | Database Assessment | 5+ | sqlmap, mdbtools, redis-tools, mongoaudit, pgcli |
| 5 | Password Attacks | 25+ | john, hashcat, hydra, medusa, ncrack, cewl, pypykatz, kerbrute |
| 6 | Wireless Attacks | 25+ | aircrack-ng, kismet, wifite, reaver, bully, fluxion, hcxtools |
| 7 | Reverse Engineering | 30+ | Ghidra, radare2, rizin, gdb + GEF/pwndbg/peda, frida, angr, binwalk |
| 8 | Exploitation Tools | 20+ | Metasploit, pwntools, impacket, chisel, Responder, PEASS-ng |
| 9 | Sniffing & Spoofing | 15+ | Wireshark, ettercap, bettercap, dsniff, scapy, tcpreplay |
| 10 | Post Exploitation | 20+ | Empire, PowerSploit, nishang, socat, sshuttle, proxychains4, PowerShell |
| 11 | Forensics | 35+ | Autopsy, Sleuth Kit, volatility3, foremost, scalpel, steghide, ClamAV |
| 12 | Reporting Tools | 5+ | CherryTree, Faraday, MkDocs, WeasyPrint |
| 13 | Social Engineering | 5+ | SET, GoPhish, zphisher, evilginx2 |
| 14 | System Services | 20+ | Docker, Tor, WireGuard, Apache, Nginx, MariaDB, PostgreSQL, Samba |
| 15 | C2 Frameworks | 3+ | Sliver, Havoc, Empire + Starkiller |
| 16 | ProjectDiscovery Suite | 10+ | pdtm, interactsh, proxify, shuffledns, notify, chaos, urlfinder |
| 17 | Wordlists | 3+ | SecLists, rockyou.txt, PayloadsAllTheThings |
| 18 | Additional Kali Tools | 160+ | RustScan, CyberChef, BloodHound, testssl.sh, mimikatz, AutoRecon, Caldera |
| 18D | Alternative Install Methods | 15+ | Tools not in apt installed via snap, pip, third-party repos, or GitHub builds (kismet, commix, massdns, jadx, rizin, etc.) |
| 19 | PATH Configuration | -- | Shell aliases and PATH exports for all installed tools |
| 20 | Permissions & Cleanup | -- | Ownership fixes, apt cache cleanup |

**Total: 500+ individual tools and packages**

---

## Directory Structure After Install

```
~/
|-- tools/                    # Git-cloned tool repositories (~80 repos)
|   |-- ghidra/
|   |-- Responder/
|   |-- PEASS-ng/
|   |-- BloodHound/
|   |-- CyberChef/
|   |-- mimikatz/
|   |-- ...
|
|-- wordlists/                # Wordlists for password attacks and fuzzing
|   |-- SecLists/
|   |-- rockyou.txt
|
|-- pentest-venv/             # Isolated Python virtual environment
|   |-- bin/
|   |-- lib/
|
|-- go/                       # Go workspace
|   |-- bin/                  # Compiled Go tools (subfinder, httpx, nuclei, etc.)
|
|-- kali-tools-install.log    # Full installation log
|-- kali-tools-failed.log     # Failed package log
```

---

## Post-Install

1. **Log out and log back in** (or reboot) so that group changes (docker, wireshark) take effect.

2. **Activate the Python pentesting environment** when you need Python-based tools:
   ```bash
   source ~/pentest-venv/bin/activate
   ```
   Or use the alias:
   ```bash
   pentest-activate
   ```

3. **Verify Go tools** are in your PATH:
   ```bash
   which subfinder nuclei httpx
   ```

4. **Start services only when needed** -- they are disabled by default for security:
   ```bash
   sudo systemctl start ssh
   sudo systemctl start postgresql
   sudo systemctl start docker
   ```

5. **Review logs** for any tools that failed to install:
   ```bash
   cat ~/kali-tools-failed.log
   ```

6. **Fix failed installations** -- if the first run had issues (network timeouts, package errors), run the fix script to retry failed items:
   ```bash
   sudo ./fix-install.sh
   ```

7. **Keep tools updated** -- periodically update all installed tools using:
   ```bash
   sudo ./update-tools.sh
   ```

8. **Change your password** as recommended by the script:
   ```bash
   passwd
   ```

---

## Troubleshooting

- **Git clone hangs asking for username**: The script sets `GIT_TERMINAL_PROMPT=0` to prevent interactive git prompts. If a clone still hangs, press `Ctrl+C` and re-run the script. Make sure your SSH key is added to your GitHub account.
- **`pentest-venv/bin/pip: No such file or directory`**: The Python virtual environment was not created properly. Run `sudo ./fix-install.sh` to recreate it and reinstall all pip packages.
- **Permission denied on wordlists**: Run `sudo ./fix-install.sh` to fix ownership and permissions on the `~/wordlists` directory.
- **`Unable to locate package X`**: These are Kali-exclusive packages that are not available in Ubuntu repositories. This is expected behavior and can be safely ignored. Many of these tools are installed via alternative methods in Step 18D (snap, pip, third-party repos, or compiled from GitHub source).
- **Snap tools have limited filesystem access**: Tools installed via snap (ZAP Proxy, feroxbuster, dbeaver, rizin) may not be able to access files outside your home directory due to snap confinement.

---

## Updating Tools

Use `update-tools.sh` to keep all installed tools up to date:

```bash
sudo ./update-tools.sh                # Update all tools AND check for missing Kali packages
sudo ./update-tools.sh --update-only  # Only update installed tools (skip missing check)
sudo ./update-tools.sh --check-only   # Only check for missing Kali packages (no updates)
```

The updater covers apt packages, pip packages in the venv, Go binaries, git repositories, Ruby gems, snap packages, Metasploit, and Nuclei templates. A detailed report of missing Kali packages is saved to `~/kali-tools-missing-report.txt`.

---

## Known Limitations

- **Kali-exclusive packages**: Some tools are packaged exclusively for Kali Linux and are not available in Ubuntu repositories. The script handles these gracefully with warnings and fallback suggestions.
- **Repository availability**: Certain apt packages may not exist in the Ubuntu 24.04 repos. These are logged in `~/kali-tools-failed.log`.
- **Commercial/proprietary tools**: Tools like Maltego, Caido, and Burp Suite Professional require separate downloads or licenses. The script provides download URLs in the log output.
- **Snap confinement**: Some snap-installed tools (ZAP Proxy, feroxbuster, dbeaver, cutter-re) may have filesystem access restrictions due to snap sandboxing.
- **Dynamic user detection**: The scripts detect the running user automatically via `SUDO_USER` or `logname`, so no manual username editing is needed.
- **Disk space**: A full installation can consume 40-60 GB of disk space depending on which tools succeed.
- **ARM architectures**: This script is designed for x86_64. Some binary downloads and Go builds may not work on ARM.

---

## Contributing

Contributions are welcome. Please read [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on how to report issues, suggest tools, and submit pull requests.

---

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

---

## Disclaimer

This toolkit is intended for authorized security testing, educational purposes, and Capture The Flag (CTF) competitions only. Always obtain proper authorization before testing systems you do not own. The author is not responsible for any misuse of these tools.

---

## Author

**chochy2001** -- [github.com/chochy2001](https://github.com/chochy2001)

Built with dedication for the security community.
