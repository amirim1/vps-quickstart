# VPS QuickStart

[![Version](https://img.shields.io/badge/version-1.1.0-blue.svg)](https://github.com/amirim1/vps-quickstart)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Bash](https://img.shields.io/badge/bash-5.0%2B-orange.svg)](https://www.gnu.org/software/bash/)

> Professional interactive server setup script for Debian/Ubuntu VPS

**Languages:** [English](README.md) | [Русский](README.ru.md)

A single-file Bash script with an interactive menu for initial VPS configuration. No external dependencies, no Python, no dialogs — just pure Bash.

## Features

- **16 independent menu items** — run only what you need
- **Professional error handling** — script never crashes, always returns to menu
- **ANSI-colored output** — modern terminal interface
- **Curl-bash ready** — one-liner installation
- **Idempotent** — safe to run multiple times

## Supported OS

- Debian 12+
- Ubuntu 22.04+
- Ubuntu 24.04+

## Quick Start

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/amirim1/vps-quickstart/main/setup.sh)
```

Or download and run locally:

```bash
curl -fsSL -o setup.sh https://raw.githubusercontent.com/amirim1/vps-quickstart/main/setup.sh
bash setup.sh
```

## Menu

| # | Feature | Description |
|---|---------|-------------|
| 1 | Update System | apt update, upgrade, autoremove, autoclean |
| 2 | Install Base Packages | curl, wget, git, jq, htop, btop, vim, and more |
| 3 | Configure SSH | Change port, disable password/root login, enable keys |
| 4 | Configure Firewall (UFW) | Install, configure ports, enable with confirmation |
| 5 | Install Fail2Ban | Auto-sync with current SSH port |
| 6 | Create Swap | User-defined size, disk space check, fstab |
| 7 | Enable BBR | Kernel check, sysctl configuration |
| 8 | Manage IPv6 | Disable/enable/check IPv6 with UFW sync |
| 9 | Server Information | OS, CPU, RAM, disk, network, virtualization |
| 10 | Network Test | Ping, DNS, HTTP/HTTPS connectivity |
| 11 | Speed Test | Download/upload via speedtest-cli |
| 12 | Domain Check | A/AAAA records, IP match, HTTPS status |
| 13 | Install 3x-ui | MHSanaei's 3x-ui panel |
| 14 | Create User | Username, password, sudo, SSH key |
| 15 | Configure Sudo | Passwordless sudo with visudo validation |
| 16 | Exit | Clean exit |

## Screenshots

```
╔══════════════════════════════════════════════════════════════╗
║                    VPS QuickStart v1.1.0                     ║
║              Professional Server Setup Script                ║
╚══════════════════════════════════════════════════════════════╝
OS: Ubuntu 22.04.4 LTS
Kernel: 5.15.0
Arch: x86_64
Uptime: 3 days, 2 hours
IPv4: 192.168.1.100

════════════════════════════ MENU ════════════════════════════
  1) Update System
  2) Install Base Packages
  ...
```

## Architecture

```
setup.sh
├── Configuration Section    # All parameters in one place
├── Utility Functions        # Logging, checks, helpers
├── Validation Functions     # Root, OS, arch, kernel
├── Feature Functions (1-15) # Independent, self-contained
└── Main Loop              # Menu display & selection
```

## Logging

All operations are logged to `/var/log/vps-quickstart.log` in plain text format (no ANSI codes).

## Requirements

- Root access
- Bash 5.0+
- Internet connection (for some features)

## License

[MIT](LICENSE)
