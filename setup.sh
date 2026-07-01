#!/usr/bin/env bash
################################################################################
# VPS QuickStart - Professional Server Setup Script
# Version: 1.1.0
# Repository: https://github.com/your-repo/vps-quickstart
# License: MIT
# Author: Senior Linux Engineer
#
# Usage:
#   bash <(curl -fsSL https://raw.githubusercontent.com/your-repo/main/setup.sh)
#   bash setup.sh
################################################################################

# =============================================================================
# SHELL STRICTNESS
# =============================================================================
set -o pipefail
shopt -s inherit_errexit 2>/dev/null || true

# =============================================================================
# CURL-BASH SUPPORT: If piped, download and execute locally
# =============================================================================
if [[ ! -t 0 ]]; then
    SCRIPT_URL="https://raw.githubusercontent.com/amirim1/vps-quickstart/main/setup.sh"
    TEMP_SCRIPT=$(mktemp --suffix=.sh)
    trap 'rm -f "$TEMP_SCRIPT"' EXIT

    if ! curl -fsSL "$SCRIPT_URL" > "$TEMP_SCRIPT"; then
        echo "[✗] Failed to download script from $SCRIPT_URL" >&2
        exit 1
    fi

    if [[ ! -s "$TEMP_SCRIPT" ]]; then
        echo "[✗] Downloaded script is empty" >&2
        exit 1
    fi

    bash "$TEMP_SCRIPT"
    exit $?
fi

# =============================================================================
# CONFIGURATION SECTION - All parameters in one place
# =============================================================================
readonly SCRIPT_VERSION="1.1.0"
readonly SCRIPT_NAME="VPS QuickStart"
readonly SCRIPT_REPO="https://raw.githubusercontent.com/amirim1/vps-quickstart/main"

# System packages to install
readonly PACKAGES=(
    curl wget git unzip jq htop btop nano vim socat cron
    ca-certificates dnsutils net-tools iproute2 lsof
)

# SSH Configuration
readonly SSH_CONFIG_FILE="/etc/ssh/sshd_config"
readonly SSH_CONFIG_BACKUP="/etc/ssh/sshd_config.backup.$(date +%s%N)"

# UFW Configuration
readonly UFW_PORTS=(22 80 443)

# Swap Configuration
readonly SWAP_FILE="/swapfile"

# BBR Configuration
readonly BBR_MIN_KERNEL="4.9"

# Speedtest
readonly SPEEDTEST_CMD="speedtest-cli"

# 3x-ui Installation
readonly XUI_INSTALL_URL="https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh"

# Logging
readonly LOG_FILE="/var/log/vps-quickstart.log"

# OS Requirements
readonly MIN_DEBIAN_VERSION="12"
readonly MIN_UBUNTU_VERSION="22.04"

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly NC='\033[0m' # No Color

# =============================================================================
# GLOBAL STATE (cached)
# =============================================================================
CACHED_PUBLIC_IP=""
CACHED_PUBLIC_IPV6=""
CACHED_SSH_PORT=""

# =============================================================================
# SIGNAL HANDLERS
# =============================================================================
cleanup() {
    info "Interrupted by user. Cleaning up..."
    exit 130
}
trap cleanup INT TERM

# =============================================================================
# LOGGING FUNCTIONS
# =============================================================================

# Core logger - writes clean text to log, colored text to terminal
_log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local color=""
    local prefix=""

    case "$level" in
        INFO)  color="$BLUE";  prefix="[INFO]" ;;
        OK)    color="$GREEN"; prefix="[✓]" ;;
        WARN)  color="$YELLOW"; prefix="[!]" ;;
        ERR)   color="$RED";   prefix="[✗]" ;;
        *)     color="$NC";    prefix="[$level]" ;;
    esac

    # Terminal: colored
    echo -e "${color}${prefix}${NC} $message"
    # Log file: plain text
    echo "${timestamp} ${prefix} ${message}" >> "$LOG_FILE"
}

info()  { _log "INFO" "$@"; }
ok()    { _log "OK" "$@"; }
warn()  { _log "WARN" "$@"; }
err()   { _log "ERR" "$@"; }

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

# Confirmation prompt
confirm() {
    local prompt="${1:-Are you sure?}"
    local default="${2:-N}"
    local response

    if [[ "$default" =~ ^[Yy]$ ]]; then
        prompt="$prompt [Y/n]: "
    else
        prompt="$prompt [y/N]: "
    fi

    read -r -p "$(echo -e "${YELLOW}${prompt}${NC}")" response
    response=${response:-$default}
    [[ "$response" =~ ^[Yy]$ ]]
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        err "This script must be run as root"
        return 1
    fi
    return 0
}

# Check OS compatibility with version
check_os() {
    if [[ ! -f /etc/os-release ]]; then
        err "Cannot detect OS: /etc/os-release not found"
        return 1
    fi

    # shellcheck source=/dev/null
    source /etc/os-release
    local supported=false
    local min_version=""

    case "$ID" in
        ubuntu)
            min_version="$MIN_UBUNTU_VERSION"
            if [[ "$(printf '%s\n' "$min_version" "$VERSION_ID" | sort -V | head -n1)" == "$min_version" ]]; then
                supported=true
            fi
            ;;
        debian)
            min_version="$MIN_DEBIAN_VERSION"
            if [[ "$(printf '%s\n' "$min_version" "$VERSION_ID" | sort -V | head -n1)" == "$min_version" ]]; then
                supported=true
            fi
            ;;
    esac

    if [[ "$supported" != true ]]; then
        err "Unsupported OS: $PRETTY_NAME (required: Ubuntu ${MIN_UBUNTU_VERSION}+ or Debian ${MIN_DEBIAN_VERSION}+)"
        return 1
    fi

    info "OS detected: $PRETTY_NAME ($VERSION_ID)"
    return 0
}

# Check architecture
check_arch() {
    local arch
    arch=$(uname -m)
    case "$arch" in
        x86_64|aarch64|arm64)
            info "Architecture: $arch"
            return 0
            ;;
        *)
            err "Unsupported architecture: $arch"
            return 1
            ;;
    esac
}

# Check kernel version for BBR
check_kernel_version() {
    local current
    current=$(uname -r | cut -d. -f1,2)
    local required="$BBR_MIN_KERNEL"

    if [[ "$(printf '%s\n' "$required" "$current" | sort -V | head -n1)" != "$required" ]]; then
        err "Kernel version $current < $required. BBR requires kernel >= $BBR_MIN_KERNEL"
        return 1
    fi
    return 0
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check internet connectivity
check_internet() {
    if ping -c 1 -W 3 8.8.8.8 >/dev/null 2>&1 || ping -c 1 -W 3 1.1.1.1 >/dev/null 2>&1; then
        return 0
    fi
    return 1
}

# Get public IP (cached)
get_public_ip() {
    if [[ -n "$CACHED_PUBLIC_IP" ]]; then
        echo "$CACHED_PUBLIC_IP"
        return 0
    fi

    local ip=""
    ip=$(curl -fsSL -4 --max-time 10 https://api.ipify.org 2>/dev/null) || \
    ip=$(curl -fsSL -4 --max-time 10 https://ifconfig.me 2>/dev/null) || \
    ip=$(curl -fsSL -4 --max-time 10 https://icanhazip.com 2>/dev/null)

    CACHED_PUBLIC_IP="$ip"
    echo "$ip"
}

# Get public IPv6 (cached)
get_public_ipv6() {
    if [[ -n "$CACHED_PUBLIC_IPV6" ]]; then
        echo "$CACHED_PUBLIC_IPV6"
        return 0
    fi

    local ip=""
    ip=$(curl -fsSL -6 --max-time 10 https://api6.ipify.org 2>/dev/null) || \
    ip=$(curl -fsSL -6 --max-time 10 https://ifconfig.me 2>/dev/null)

    CACHED_PUBLIC_IPV6="$ip"
    echo "$ip"
}

# Cache IPs on startup
cache_ips() {
    CACHED_PUBLIC_IP=$(curl -fsSL -4 --max-time 5 https://api.ipify.org 2>/dev/null) || true
    CACHED_PUBLIC_IPV6=$(curl -fsSL -6 --max-time 5 https://api6.ipify.org 2>/dev/null) || true
}

# Wait for apt lock
wait_apt_lock() {
    local max_wait=120
    local waited=0
    while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do
        if [[ $waited -ge $max_wait ]]; then
            err "apt lock timeout after ${max_wait}s"
            return 1
        fi
        info "Waiting for apt lock... (${waited}s)"
        sleep 5
        waited=$((waited + 5))
    done
    return 0
}

# Update package list with error handling
apt_update() {
    wait_apt_lock || return 1
    local output
    output=$(apt-get update -y 2>&1)
    local rc=${PIPESTATUS[0]}
    if [[ $rc -ne 0 ]]; then
        err "apt-get update failed (code: $rc)"
        echo "$output" | tail -20 >&2
        return 1
    fi
    ok "Package list updated"
    return 0
}

# Check if package is installed
package_installed() {
    dpkg -l "$1" 2>/dev/null | grep -q ^ii
}

# Install single package with error handling
install_package() {
    local pkg="$1"
    if package_installed "$pkg"; then
        ok "Package already installed: $pkg"
        return 0
    fi

    info "Installing: $pkg"
    wait_apt_lock || return 1

    local output
    output=$(apt-get install -y "$pkg" 2>&1)
    local rc=${PIPESTATUS[0]}

    if [[ $rc -eq 0 ]]; then
        ok "Installed: $pkg"
        return 0
    else
        err "Failed to install: $pkg (code: $rc)"
        echo "$output" | tail -10 >&2
        return 1
    fi
}

# Install multiple packages
install_packages() {
    local pkgs=("$@")
    local failed=0
    for pkg in "${pkgs[@]}"; do
        install_package "$pkg" || failed=1
    done
    return $failed
}

# Backup file with atomic naming
backup_file() {
    local file="$1"
    if [[ -f "$file" ]]; then
        local backup_name="${file}.backup.$(date +%s%N)"
        cp "$file" "$backup_name"
        ok "Backed up: $file -> $backup_name"
    fi
}

# Restore file from most recent backup
restore_file() {
    local file="$1"
    local backup
    backup=$(ls -t "${file}.backup."* 2>/dev/null | head -1)
    if [[ -n "$backup" ]]; then
        cp "$backup" "$file"
        ok "Restored: $file from $backup"
        return 0
    fi
    err "No backup found for: $file"
    return 1
}

# Test SSH config
test_ssh_config() {
    if sshd -t 2>/dev/null; then
        ok "SSH configuration test passed"
        return 0
    else
        err "SSH configuration test failed"
        return 1
    fi
}

# Restart service safely with error handling
restart_service() {
    local service="$1"
    info "Restarting service: $service"

    local output
    output=$(systemctl restart "$service" 2>&1)
    local rc=${PIPESTATUS[0]}

    if [[ $rc -eq 0 ]]; then
        ok "Service restarted: $service"
        return 0
    else
        err "Failed to restart: $service (code: $rc)"
        echo "$output" | tail -5 >&2
        return 1
    fi
}

# Enable service
enable_service() {
    local service="$1"
    if systemctl enable "$service" 2>/dev/null; then
        ok "Service enabled: $service"
        return 0
    else
        err "Failed to enable: $service"
        return 1
    fi
}

# Check if service is active
service_active() {
    systemctl is-active --quiet "$1" 2>/dev/null
}

# Press any key to continue
press_any_key() {
    echo -e "\n${CYAN}Press any key to continue...${NC}"
    read -n 1 -s -r
    echo
}

# Get current SSH port from config
get_current_ssh_port() {
    if [[ -n "$CACHED_SSH_PORT" ]]; then
        echo "$CACHED_SSH_PORT"
        return 0
    fi

    local port=22
    if [[ -f "$SSH_CONFIG_FILE" ]]; then
        local config_port
        config_port=$(grep -E "^\s*Port\s+[0-9]+" "$SSH_CONFIG_FILE" | tail -1 | awk '{print $2}')
        [[ -n "$config_port" ]] && port="$config_port"
    fi

    CACHED_SSH_PORT="$port"
    echo "$port"
}

# Print header (NO clear, NO HTTP requests)
print_header() {
    echo -e "${CYAN}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                    VPS QuickStart v${SCRIPT_VERSION}                   ║"
    echo "║              Professional Server Setup Script                ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    # Use cached values instead of HTTP requests
    local os_info="Unknown"
    if [[ -f /etc/os-release ]]; then
        # shellcheck source=/dev/null
        source /etc/os-release
        os_info="$PRETTY_NAME"
    fi

    echo -e "${BLUE}OS:${NC} $os_info"
    echo -e "${BLUE}Kernel:${NC} $(uname -r)"
    echo -e "${BLUE}Arch:${NC} $(uname -m)"
    echo -e "${BLUE}Uptime:${NC} $(uptime -p 2>/dev/null || uptime | sed 's/.*up \([^,]*\),.*/\1/')"
    echo -e "${BLUE}IPv4:${NC} ${CACHED_PUBLIC_IP:-Not detected}"
    [[ -n "$CACHED_PUBLIC_IPV6" ]] && echo -e "${BLUE}IPv6:${NC} $CACHED_PUBLIC_IPV6"
    echo
}

# Print menu
print_menu() {
    echo -e "${BOLD}════════════════════════════ MENU ════════════════════════════${NC}"
    echo -e "  ${GREEN}1)${NC}  Update System"
    echo -e "  ${GREEN}2)${NC}  Install Base Packages"
    echo -e "  ${GREEN}3)${NC}  Configure SSH"
    echo -e "  ${GREEN}4)${NC}  Configure Firewall (UFW)"
    echo -e "  ${GREEN}5)${NC}  Install Fail2Ban"
    echo -e "  ${GREEN}6)${NC}  Create Swap File"
    echo -e "  ${GREEN}7)${NC}  Enable BBR"
    echo -e "  ${GREEN}8)${NC}  Manage IPv6"
    echo -e "  ${GREEN}9)${NC}  Server Information"
    echo -e "  ${GREEN}10)${NC} Network Connectivity Test"
    echo -e "  ${GREEN}11)${NC} Speed Test"
    echo -e "  ${GREEN}12)${NC} Domain Check"
    echo -e "  ${GREEN}13)${NC} Install 3x-ui Panel"
    echo -e "  ${GREEN}14)${NC} Create User"
    echo -e "  ${GREEN}15)${NC} Configure Sudo (Passwordless)"
    echo -e "  ${RED}16)${NC} Exit"
    echo -e "${BOLD}═══════════════════════════════════════════════════════════════${NC}"
}

# =============================================================================
# FEATURE FUNCTIONS
# =============================================================================

# 1. Update System
update_system() {
    info "Updating package list..."
    apt_update || return 1

    info "Upgrading packages..."
    wait_apt_lock || return 1
    local output
    output=$(apt-get upgrade -y 2>&1)
    local rc=${PIPESTATUS[0]}

    if [[ $rc -eq 0 ]]; then
        ok "Packages upgraded"
    else
        err "Upgrade failed (code: $rc)"
        echo "$output" | tail -20 >&2
        return 1
    fi

    info "Removing unused packages..."
    output=$(apt-get autoremove -y 2>&1)
    rc=${PIPESTATUS[0]}
    if [[ $rc -ne 0 ]]; then
        warn "autoremove returned code $rc"
        echo "$output" | tail -10 >&2
    fi

    output=$(apt-get autoclean -y 2>&1)
    rc=${PIPESTATUS[0]}
    if [[ $rc -ne 0 ]]; then
        warn "autoclean returned code $rc"
        echo "$output" | tail -10 >&2
    fi

    ok "Cleanup complete"
    return 0
}

# 2. Install Base Packages
install_base_packages() {
    info "Installing base packages: ${PACKAGES[*]}"
    install_packages "${PACKAGES[@]}" || return 1
    ok "All base packages processed"
    return 0
}

# 3. Configure SSH
configure_ssh() {
    info "Configuring SSH..."

    # Backup current config
    backup_file "$SSH_CONFIG_FILE"

    # Get current port
    local current_port
    current_port=$(get_current_ssh_port)
    info "Current SSH port: $current_port"

    # Get new port
    local new_port
    while true; do
        read -r -p "$(echo -e "${YELLOW}Enter SSH port [$current_port]: ${NC}")" new_port
        new_port=${new_port:-$current_port}
        if [[ "$new_port" =~ ^[0-9]+$ ]] && (( new_port >= 1 && new_port <= 65535 )); then
            break
        fi
        err "Invalid port. Must be 1-65535"
    done

    # Disable password auth?
    local disable_password
    if confirm "Disable password authentication? (key-only login)" "N"; then
        disable_password="no"
    else
        disable_password="yes"
    fi

    # Disable root login?
    local disable_root
    if confirm "Disable root login?" "Y"; then
        disable_root="no"
    else
        disable_root="yes"
    fi

    # Apply changes
    info "Applying SSH configuration..."

    # Port
    sed -i "s/^#*Port .*/Port $new_port/" "$SSH_CONFIG_FILE"
    grep -q "^Port " "$SSH_CONFIG_FILE" || echo "Port $new_port" >> "$SSH_CONFIG_FILE"

    # PasswordAuthentication
    sed -i "s/^#*PasswordAuthentication .*/PasswordAuthentication $disable_password/" "$SSH_CONFIG_FILE"
    grep -q "^PasswordAuthentication " "$SSH_CONFIG_FILE" || echo "PasswordAuthentication $disable_password" >> "$SSH_CONFIG_FILE"

    # PermitRootLogin
    sed -i "s/^#*PermitRootLogin .*/PermitRootLogin $disable_root/" "$SSH_CONFIG_FILE"
    grep -q "^PermitRootLogin " "$SSH_CONFIG_FILE" || echo "PermitRootLogin $disable_root" >> "$SSH_CONFIG_FILE"

    # PubkeyAuthentication
    sed -i 's/^#*PubkeyAuthentication .*/PubkeyAuthentication yes/' "$SSH_CONFIG_FILE"
    grep -q "^PubkeyAuthentication " "$SSH_CONFIG_FILE" || echo "PubkeyAuthentication yes" >> "$SSH_CONFIG_FILE"

    # Test config
    if ! test_ssh_config; then
        err "SSH config test failed. Restoring backup..."
        restore_file "$SSH_CONFIG_FILE"
        return 1
    fi

    CACHED_SSH_PORT="$new_port"
    restart_service ssh || return 1

    ok "SSH configured on port $new_port"
    warn "IMPORTANT: Ensure you have SSH key access before disconnecting!"
    return 0
}

# 4. Configure Firewall (UFW)
configure_firewall() {
    info "Configuring UFW firewall..."

    install_package ufw || return 1

    # Warning about reset
    if confirm "WARNING: This will reset ALL existing UFW rules. Continue?" "N"; then
        ufw --force reset 2>/dev/null
        ok "UFW rules reset"
    else
        info "Skipping UFW reset"
    fi

    # Default policies
    ufw default deny incoming
    ufw default allow outgoing

    # Allow SSH port (current from config)
    local ssh_port
    ssh_port=$(get_current_ssh_port)
    ufw allow "$ssh_port"/tcp comment "SSH"
    ok "Allowed SSH port: $ssh_port"

    # Allow additional ports
    for port in "${UFW_PORTS[@]}"; do
        if [[ "$port" != "$ssh_port" ]]; then
            ufw allow "$port"/tcp comment "Service"
            ok "Allowed port: $port"
        fi
    done

    # Enable UFW
    if confirm "Enable UFW firewall now?" "Y"; then
        ufw --force enable
        ok "UFW enabled"
    else
        warn "UFW configured but not enabled"
    fi

    ufw status verbose
    return 0
}

# 5. Install Fail2Ban
install_fail2ban() {
    info "Installing Fail2Ban..."

    install_package fail2ban || return 1

    # Get current SSH port for jail config
    local ssh_port
    ssh_port=$(get_current_ssh_port)

    # Create local jail config
    local jail_local="/etc/fail2ban/jail.local"
    cat > "$jail_local" <<EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3
backend = systemd

[sshd]
enabled = true
port = $ssh_port
filter = sshd
logpath = %(sshd_log)s
maxretry = 3
EOF

    enable_service fail2ban
    restart_service fail2ban
    ok "Fail2Ban installed and configured (monitoring port $ssh_port)"
    return 0
}

# 6. Create Swap
create_swap() {
    if [[ -f "$SWAP_FILE" ]]; then
        warn "Swap file already exists: $SWAP_FILE"
        local size
        size=$(ls -lh "$SWAP_FILE" | awk '{print $5}')
        info "Current size: $size"
        if ! confirm "Recreate swap file?" "N"; then
            return 0
        fi
        swapoff "$SWAP_FILE" 2>/dev/null || true
        rm -f "$SWAP_FILE"
    fi

    local size_gb
    while true; do
        read -r -p "$(echo -e "${YELLOW}Enter swap size in GB (e.g., 2, 4): ${NC}")" size_gb
        if [[ "$size_gb" =~ ^[0-9]+$ ]] && (( size_gb >= 1 && size_gb <= 64 )); then
            break
        fi
        err "Invalid size. Enter 1-64 GB"
    done

    # Check disk space
    local available_gb
    available_gb=$(df -BG / | tail -1 | awk '{print $4}' | tr -d 'G')
    if (( size_gb + 2 > available_gb )); then
        err "Not enough disk space. Available: ${available_gb}GB, requested: ${size_gb}GB (+2GB buffer)"
        return 1
    fi

    info "Creating ${size_gb}GB swap file..."
    if fallocate -l "${size_gb}G" "$SWAP_FILE" 2>/dev/null; then
        : # success
    else
        info "fallocate failed, using dd (slower)..."
        if ! dd if=/dev/zero of="$SWAP_FILE" bs=1M count=$((size_gb * 1024)) status=progress 2>&1; then
            err "Failed to create swap file with dd"
            rm -f "$SWAP_FILE"
            return 1
        fi
    fi

    chmod 600 "$SWAP_FILE"
    if ! mkswap "$SWAP_FILE" 2>/dev/null; then
        err "mkswap failed"
        rm -f "$SWAP_FILE"
        return 1
    fi

    if ! swapon "$SWAP_FILE" 2>/dev/null; then
        err "swapon failed"
        rm -f "$SWAP_FILE"
        return 1
    fi

    # Add to fstab if not present
    if ! grep -q "^$SWAP_FILE " /etc/fstab; then
        echo "$SWAP_FILE none swap sw 0 0" >> /etc/fstab
    fi

    ok "Swap created: ${size_gb}GB"
    swapon --show
    return 0
}

# 7. Enable BBR
enable_bbr() {
    info "Enabling BBR congestion control..."

    if ! check_kernel_version; then
        return 1
    fi

    # Check if already enabled
    if sysctl net.ipv4.tcp_congestion_control 2>/dev/null | grep -q bbr; then
        ok "BBR already enabled"
        return 0
    fi

    # Apply sysctl settings
    cat > /etc/sysctl.d/99-bbr.conf <<'EOF'
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
EOF

    if ! sysctl --system 2>/dev/null; then
        err "sysctl --system failed"
        return 1
    fi

    if sysctl net.ipv4.tcp_congestion_control 2>/dev/null | grep -q bbr; then
        ok "BBR enabled successfully"
        return 0
    else
        err "Failed to enable BBR"
        return 1
    fi
}

# 8. Manage IPv6
manage_ipv6() {
    while true; do
        print_header
        echo -e "${BOLD}════════════════════════════ IPv6 MANAGEMENT ════════════════════════════${NC}"
        echo -e "  ${GREEN}1)${NC} Disable IPv6"
        echo -e "  ${GREEN}2)${NC} Enable IPv6"
        echo -e "  ${GREEN}3)${NC} Check IPv6 Status"
        echo -e "  ${RED}4)${NC} Back to Main Menu"
        echo -e "${BOLD}═══════════════════════════════════════════════════════════════════════${NC}"

        read -r -p "$(echo -e "${YELLOW}Select option [1-4]: ${NC}")" choice

        case "$choice" in
            1) disable_ipv6 ;;
            2) enable_ipv6 ;;
            3) check_ipv6_status ;;
            4) return 0 ;;
            *) err "Invalid option" ;;
        esac
        press_any_key
    done
}

disable_ipv6() {
    info "Disabling IPv6..."
    cat > /etc/sysctl.d/99-disable-ipv6.conf <<'EOF'
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF

    if ! sysctl --system 2>/dev/null; then
        warn "sysctl --system returned non-zero"
    fi

    # Update UFW to disable IPv6
    if [[ -f /etc/default/ufw ]]; then
        sed -i 's/IPV6=yes/IPV6=no/' /etc/default/ufw 2>/dev/null
        if service_active ufw; then
            restart_service ufw || true
        fi
    fi

    ok "IPv6 disabled (requires reboot for full effect)"
}

enable_ipv6() {
    info "Enabling IPv6..."
    rm -f /etc/sysctl.d/99-disable-ipv6.conf
    if ! sysctl --system 2>/dev/null; then
        warn "sysctl --system returned non-zero"
    fi

    # Update UFW to enable IPv6
    if [[ -f /etc/default/ufw ]]; then
        sed -i 's/IPV6=no/IPV6=yes/' /etc/default/ufw 2>/dev/null
        if service_active ufw; then
            restart_service ufw || true
        fi
    fi

    ok "IPv6 enabled (requires reboot for full effect)"
}

check_ipv6_status() {
    info "IPv6 Status:"
    local disabled
    disabled=$(sysctl -n net.ipv6.conf.all.disable_ipv6 2>/dev/null)
    if [[ "$disabled" == "1" ]]; then
        echo -e "  ${RED}IPv6: DISABLED${NC} (via sysctl)"
    else
        echo -e "  ${GREEN}IPv6: ENABLED${NC} (via sysctl)"
    fi

    local ipv6_addr="$CACHED_PUBLIC_IPV6"
    if [[ -n "$ipv6_addr" ]]; then
        echo -e "  ${GREEN}Public IPv6:${NC} $ipv6_addr"
    else
        echo -e "  ${YELLOW}Public IPv6:${NC} Not detected"
    fi

    # Check interfaces
    echo -e "  ${BLUE}Interfaces with IPv6:${NC}"
    ip -6 addr show scope global 2>/dev/null | grep -E '^ [0-9]+:|inet6' | head -20 | while IFS= read -r line; do
        echo "    $line"
    done
}

# 9. Server Information
server_info() {
    print_header
    echo -e "${BOLD}════════════════════════════ SERVER INFORMATION ════════════════════════════${NC}"

    # OS Info
    local os_info="Unknown"
    if [[ -f /etc/os-release ]]; then
        # shellcheck source=/dev/null
        source /etc/os-release
        os_info="$PRETTY_NAME"
    fi
    echo -e "${CYAN}OS:${NC} $os_info"
    echo -e "${CYAN}Kernel:${NC} $(uname -r)"
    echo -e "${CYAN}Architecture:${NC} $(uname -m)"

    # CPU
    echo -e "\n${CYAN}CPU:${NC}"
    lscpu 2>/dev/null | grep -E 'Model name|CPU\(s\):|Thread|Core|MHz' | sed 's/^/  /'

    # Memory
    echo -e "\n${CYAN}Memory:${NC}"
    free -h | sed 's/^/  /'

    # Disk
    echo -e "\n${CYAN}Disk Usage:${NC}"
    df -h / | sed 's/^/  /'
    echo
    df -h | grep -vE '^Filesystem|tmpfs|udev' | sed 's/^/  /'

    # Network
    echo -e "\n${CYAN}Network:${NC}"
    echo -e "  Public IPv4: ${CACHED_PUBLIC_IP:-Not detected}"
    [[ -n "$CACHED_PUBLIC_IPV6" ]] && echo -e "  Public IPv6: $CACHED_PUBLIC_IPV6"

    ip -4 addr show scope global 2>/dev/null | grep -E '^ [0-9]+:|inet ' | sed 's/^/  /'

    # Virtualization
    echo -e "\n${CYAN}Virtualization:${NC}"
    if command_exists systemd-detect-virt; then
        echo -e "  $(systemd-detect-virt)"
    elif command_exists virt-what; then
        virt-what | sed 's/^/  /'
    else
        echo "  Unknown"
    fi

    # Load
    echo -e "\n${CYAN}Load Average:${NC} $(uptime | awk -F'load average:' '{print $2}')"

    echo -e "${BOLD}═══════════════════════════════════════════════════════════════════════${NC}"
}

# 10. Network Connectivity Test
network_test() {
    info "Testing network connectivity..."

    local tests=(
        "8.8.8.8:Google DNS"
        "1.1.1.1:Cloudflare DNS"
        "github.com:GitHub"
        "google.com:Google"
    )

    echo -e "\n${BOLD}IPv4 Connectivity:${NC}"
    for test in "${tests[@]}"; do
        IFS=':' read -r host desc <<< "$test"
        if ping -c 2 -W 3 "$host" >/dev/null 2>&1; then
            ok "  $desc ($host): REACHABLE"
        else
            err "  $desc ($host): UNREACHABLE"
        fi
    done

    # DNS Resolution
    echo -e "\n${BOLD}DNS Resolution:${NC}"
    for dns in "8.8.8.8" "1.1.1.1" "9.9.9.9"; do
        if dig @"$dns" google.com +short +time=3 >/dev/null 2>&1; then
            ok "  DNS $dns: OK"
        else
            err "  DNS $dns: FAILED"
        fi
    done

    # IPv6
    echo -e "\n${BOLD}IPv6 Connectivity:${NC}"
    if [[ -n "$CACHED_PUBLIC_IPV6" ]]; then
        if ping -6 -c 2 -W 3 2001:4860:4860::8888 >/dev/null 2>&1; then
            ok "  Google IPv6 DNS: REACHABLE"
        else
            warn "  Google IPv6 DNS: UNREACHABLE"
        fi
    else
        info "  No public IPv6 detected"
    fi

    # HTTP/HTTPS
    echo -e "\n${BOLD}HTTP/HTTPS:${NC}"
    local http_code
    http_code=$(curl -fsSL --max-time 10 -o /dev/null -w "%{http_code}" https://google.com 2>/dev/null)
    if [[ "$http_code" == "200" ]]; then
        ok "  HTTPS (google.com): OK"
    else
        err "  HTTPS (google.com): FAILED (code: $http_code)"
    fi

    http_code=$(curl -fsSL --max-time 10 -o /dev/null -w "%{http_code}" http://httpbin.org/get 2>/dev/null)
    if [[ "$http_code" == "200" ]]; then
        ok "  HTTP (httpbin.org): OK"
    else
        err "  HTTP (httpbin.org): FAILED (code: $http_code)"
    fi
}

# 11. Speed Test
speed_test() {
    if ! command_exists "$SPEEDTEST_CMD"; then
        info "Installing speedtest-cli..."
        if ! install_package speedtest-cli; then
            warn "Package install failed. Trying pip3..."
            if command_exists pip3; then
                # On Ubuntu 24.04+, pip3 requires --break-system-packages
                if ! pip3 install speedtest-cli 2>/dev/null && ! pip3 install --break-system-packages speedtest-cli 2>/dev/null; then
                    err "Failed to install speedtest-cli"
                    return 1
                fi
            else
                err "speedtest-cli not available and pip3 not found"
                return 1
            fi
        fi
    fi

    info "Running speed test (this may take 30-60 seconds)..."
    local output
    output=$($SPEEDTEST_CMD --simple 2>&1)
    local rc=${PIPESTATUS[0]}

    if [[ $rc -eq 0 ]]; then
        echo "$output" | while IFS= read -r line; do
            [[ -n "$line" ]] && echo -e "  ${CYAN}$line${NC}"
        done
    else
        err "Speed test failed (code: $rc)"
        echo "$output" >&2
        return 1
    fi
}

# 12. Domain Check
domain_check() {
    local domain
    read -r -p "$(echo -e "${YELLOW}Enter domain to check: ${NC}")" domain
    [[ -z "$domain" ]] && { err "Domain required"; return 1; }

    info "Checking domain: $domain"

    # Check dig availability
    if ! command_exists dig; then
        err "dig command not found. Install dnsutils first (option 2)."
        return 1
    fi

    # A records
    echo -e "\n${BOLD}A Records (IPv4):${NC}"
    local a_records
    a_records=$(dig +short "$domain" A 2>/dev/null)
    if [[ -n "$a_records" ]]; then
        echo "$a_records" | while IFS= read -r ip; do
            [[ -n "$ip" ]] && echo -e "  ${GREEN}$ip${NC}"
        done
    else
        warn "  No A records found"
    fi

    # AAAA records
    echo -e "\n${BOLD}AAAA Records (IPv6):${NC}"
    local aaaa_records
    aaaa_records=$(dig +short "$domain" AAAA 2>/dev/null)
    if [[ -n "$aaaa_records" ]]; then
        echo "$aaaa_records" | while IFS= read -r ip; do
            [[ -n "$ip" ]] && echo -e "  ${GREEN}$ip${NC}"
        done
    else
        warn "  No AAAA records found"
    fi

    # Compare with server IP
    local server_ip="$CACHED_PUBLIC_IP"
    echo -e "\n${BOLD}Server IP:${NC} ${server_ip:-Not detected}"

    if [[ -n "$server_ip" && -n "$a_records" ]]; then
        local match=false
        while IFS= read -r ip; do
            [[ "$ip" == "$server_ip" ]] && match=true
        done <<< "$a_records"

        if [[ "$match" == true ]]; then
            ok "Domain A record matches server IP"
        else
            warn "Domain A record does NOT match server IP"
        fi
    fi

    # HTTPS check (basic)
    echo -e "\n${BOLD}HTTPS Check:${NC}"
    local http_code
    http_code=$(curl -fsSL --max-time 10 -o /dev/null -w "%{http_code}" "https://$domain" 2>/dev/null)
    if [[ "$http_code" == "200" ]]; then
        ok "HTTPS accessible (200 OK)"
    else
        warn "HTTPS not accessible or returns non-2xx (code: ${http_code:-N/A})"
    fi
}

# 13. Install 3x-ui
install_3xui() {
    info "Installing 3x-ui panel..."

    if confirm "This will install 3x-ui from MHSanaei's repository. Continue?" "Y"; then
        # Download installer to temp file first for error handling
        local installer
        installer=$(mktemp)
        if ! curl -fsSL "$XUI_INSTALL_URL" -o "$installer"; then
            err "Failed to download 3x-ui installer"
            rm -f "$installer"
            return 1
        fi

        if [[ ! -s "$installer" ]]; then
            err "Downloaded installer is empty"
            rm -f "$installer"
            return 1
        fi

        bash "$installer" 2>&1 | while IFS= read -r line; do
            [[ -n "$line" ]] && info "$line"
        done
        local rc=${PIPESTATUS[0]}
        rm -f "$installer"

        if [[ $rc -ne 0 ]]; then
            err "3x-ui installation failed (code: $rc)"
            return 1
        fi

        ok "3x-ui installation completed"

        # Show default info
        echo -e "\n${BOLD}Default 3x-ui Info:${NC}"
        echo -e "  ${CYAN}Panel URL:${NC} http://${CACHED_PUBLIC_IP:-your-ip}:2053/"
        echo -e "  ${CYAN}Username:${NC} admin"
        echo -e "  ${CYAN}Password:${NC} admin"
        echo -e "  ${CYAN}Port:${NC} 2053 (default)"
        warn "CHANGE DEFAULT CREDENTIALS IMMEDIATELY AFTER FIRST LOGIN!"
    else
        info "Installation cancelled"
    fi
}

# 14. Create User
create_user() {
    local username
    while true; do
        read -r -p "$(echo -e "${YELLOW}Enter username: ${NC}")" username
        if [[ -z "$username" ]]; then
            err "Username cannot be empty"
            continue
        fi
        if [[ "$username" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
            break
        fi
        err "Invalid username. Use lowercase, numbers, underscore, hyphen. Start with letter/underscore."
    done

    if id "$username" &>/dev/null; then
        err "User already exists: $username"
        return 1
    fi

    local password
    while true; do
        read -s -r -p "$(echo -e "${YELLOW}Enter password: ${NC}")" password
        echo
        if [[ ${#password} -ge 8 ]]; then
            break
        fi
        err "Password must be at least 8 characters"
    done

    local confirm_pass
    read -s -r -p "$(echo -e "${YELLOW}Confirm password: ${NC}")" confirm_pass
    echo
    [[ "$password" != "$confirm_pass" ]] && { err "Passwords do not match"; return 1; }

    # Create user
    if useradd -m -s /bin/bash "$username" 2>/dev/null; then
        echo "$username:$password" | chpasswd
        ok "User created: $username"
    else
        err "Failed to create user"
        return 1
    fi

    # Add to sudo group?
    if confirm "Add user to sudo group?" "Y"; then
        usermod -aG sudo "$username" || usermod -aG wheel "$username"
        ok "Added to sudo group"
    fi

    # Setup SSH key?
    if confirm "Setup SSH key for this user?" "N"; then
        local ssh_key
        read -r -p "$(echo -e "${YELLOW}Paste public SSH key: ${NC}")" ssh_key
        if [[ -n "$ssh_key" ]]; then
            local ssh_dir="/home/$username/.ssh"
            mkdir -p "$ssh_dir"
            echo "$ssh_key" > "$ssh_dir/authorized_keys"
            chmod 700 "$ssh_dir"
            chmod 600 "$ssh_dir/authorized_keys"
            chown -R "$username:$username" "$ssh_dir"
            ok "SSH key configured"
        fi
    fi

    return 0
}

# 15. Configure Sudo Passwordless
configure_sudo() {
    local username
    read -r -p "$(echo -e "${YELLOW}Enter username for passwordless sudo: ${NC}")" username

    if ! id "$username" &>/dev/null; then
        err "User not found: $username"
        return 1
    fi

    local sudoers_file="/etc/sudoers.d/90-$username-nopasswd"

    # Atomic creation with restricted umask
    (
        umask 077
        echo "$username ALL=(ALL) NOPASSWD:ALL" > "$sudoers_file"
    )
    chmod 440 "$sudoers_file"

    # Validate
    if visudo -cf "$sudoers_file" 2>/dev/null; then
        ok "Passwordless sudo configured for: $username"
        return 0
    else
        err "Invalid sudoers syntax, removing file"
        rm -f "$sudoers_file"
        return 1
    fi
}

# =============================================================================
# MAIN LOOP
# =============================================================================

main() {
    # Initialize log
    mkdir -p "$(dirname "$LOG_FILE")"
    touch "$LOG_FILE"
    chmod 644 "$LOG_FILE"

    info "Starting $SCRIPT_NAME v$SCRIPT_VERSION"

    # Pre-flight checks
    check_root || exit 1
    check_os || exit 1
    check_arch || exit 1

    # Cache IPs once at startup
    cache_ips

    # Main menu loop
    while true; do
        print_header
        print_menu

        read -r -p "$(echo -e "${YELLOW}Select option [1-16]: ${NC}")" choice

        case "$choice" in
            1) update_system ;;
            2) install_base_packages ;;
            3) configure_ssh ;;
            4) configure_firewall ;;
            5) install_fail2ban ;;
            6) create_swap ;;
            7) enable_bbr ;;
            8) manage_ipv6 ;;
            9) server_info ;;
            10) network_test ;;
            11) speed_test ;;
            12) domain_check ;;
            13) install_3xui ;;
            14) create_user ;;
            15) configure_sudo ;;
            16)
                info "Exiting $SCRIPT_NAME"
                exit 0
                ;;
            *)
                err "Invalid option: $choice"
                ;;
        esac

        press_any_key
    done
}

# Run main
main "$@"
