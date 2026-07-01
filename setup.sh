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
# INTERNATIONALIZATION (i18n)
# =============================================================================
declare -A I18N_EN
declare -A I18N_RU
CURRENT_LANG="en"

# English translations
I18N_EN["lang_name"]="English"
I18N_EN["select_language"]="Select language / Выберите язык:"
I18N_EN["lang_en"]="1) English"
I18N_EN["lang_ru"]="2) Русский"
I18N_EN["invalid_option"]="Invalid option"
I18N_EN["must_run_as_root"]="This script must be run as root"
I18N_EN["os_detected"]="OS detected"
I18N_EN["unsupported_os"]="Unsupported OS"
I18N_EN["required"]="required"
I18N_EN["architecture"]="Architecture"
I18N_EN["unsupported_arch"]="Unsupported architecture"
I18N_EN["kernel_too_old"]="Kernel too old. BBR requires kernel >="
I18N_EN["apt_lock_timeout"]="apt lock timeout after"
I18N_EN["waiting_apt"]="Waiting for apt lock..."
I18N_EN["update_failed"]="apt-get update failed"
I18N_EN["package_list_updated"]="Package list updated"
I18N_EN["package_already_installed"]="Package already installed"
I18N_EN["installing"]="Installing"
I18N_EN["installed"]="Installed"
I18N_EN["failed_to_install"]="Failed to install"
I18N_EN["backed_up"]="Backed up"
I18N_EN["restored"]="Restored"
I18N_EN["no_backup_found"]="No backup found for"
I18N_EN["ssh_test_passed"]="SSH configuration test passed"
I18N_EN["ssh_test_failed"]="SSH configuration test failed"
I18N_EN["restarting_service"]="Restarting service"
I18N_EN["service_restarted"]="Service restarted"
I18N_EN["failed_to_restart"]="Failed to restart"
I18N_EN["service_enabled"]="Service enabled"
I18N_EN["failed_to_enable"]="Failed to enable"
I18N_EN["press_any_key"]="Press any key to continue..."
I18N_EN["menu_title"]="MENU"
I18N_EN["update_system"]="Update System"
I18N_EN["install_base_packages"]="Install Base Packages"
I18N_EN["configure_ssh"]="Configure SSH"
I18N_EN["configure_firewall"]="Configure Firewall (UFW)"
I18N_EN["install_fail2ban"]="Install Fail2Ban"
I18N_EN["create_swap"]="Create Swap File"
I18N_EN["enable_bbr"]="Enable BBR"
I18N_EN["manage_ipv6"]="Manage IPv6"
I18N_EN["server_info"]="Server Information"
I18N_EN["network_test"]="Network Connectivity Test"
I18N_EN["speed_test"]="Speed Test"
I18N_EN["domain_check"]="Domain Check"
I18N_EN["install_3xui"]="Install 3x-ui Panel"
I18N_EN["create_user"]="Create User"
I18N_EN["configure_sudo"]="Configure Sudo (Passwordless)"
I18N_EN["exit"]="Exit"
I18N_EN["updating_package_list"]="Updating package list..."
I18N_EN["upgrading_packages"]="Upgrading packages..."
I18N_EN["packages_upgraded"]="Packages upgraded"
I18N_EN["upgrade_failed"]="Upgrade failed"
I18N_EN["removing_unused"]="Removing unused packages..."
I18N_EN["autoremove_failed"]="autoremove returned code"
I18N_EN["autoclean_failed"]="autoclean returned code"
I18N_EN["cleanup_complete"]="Cleanup complete"
I18N_EN["installing_base"]="Installing base packages"
I18N_EN["all_base_installed"]="All base packages processed"
I18N_EN["configuring_ssh"]="Configuring SSH..."
I18N_EN["current_ssh_port"]="Current SSH port"
I18N_EN["enter_ssh_port"]="Enter SSH port"
I18N_EN["invalid_port"]="Invalid port. Must be 1-65535"
I18N_EN["disable_password_auth"]="Disable password authentication? (key-only login)"
I18N_EN["disable_root_login"]="Disable root login?"
I18N_EN["applying_ssh"]="Applying SSH configuration..."
I18N_EN["ssh_config_failed"]="SSH config test failed. Restoring backup..."
I18N_EN["ssh_configured"]="SSH configured on port"
I18N_EN["ssh_warning"]="IMPORTANT: Ensure you have SSH key access before disconnecting!"
I18N_EN["configuring_ufw"]="Configuring UFW firewall..."
I18N_EN["ufw_reset_warning"]="WARNING: This will reset ALL existing UFW rules. Continue?"
I18N_EN["ufw_rules_reset"]="UFW rules reset"
I18N_EN["ufw_skipping_reset"]="Skipping UFW reset"
I18N_EN["ufw_enabled"]="UFW enabled"
I18N_EN["ufw_not_enabled"]="UFW configured but not enabled"
I18N_EN["installing_fail2ban"]="Installing Fail2Ban..."
I18N_EN["fail2ban_configured"]="Fail2Ban installed and configured (monitoring port"
I18N_EN["swap_exists"]="Swap file already exists"
I18N_EN["current_size"]="Current size"
I18N_EN["recreate_swap"]="Recreate swap file?"
I18N_EN["enter_swap_size"]="Enter swap size in GB (e.g., 2, 4)"
I18N_EN["invalid_swap_size"]="Invalid size. Enter 1-64 GB"
I18N_EN["not_enough_space"]="Not enough disk space. Available"
I18N_EN["requested"]="requested"
I18N_EN["creating_swap"]="Creating swap file..."
I18N_EN["fallocate_failed"]="fallocate failed, using dd (slower)..."
I18N_EN["dd_failed"]="Failed to create swap file with dd"
I18N_EN["mkswap_failed"]="mkswap failed"
I18N_EN["swapon_failed"]="swapon failed"
I18N_EN["swap_created"]="Swap created"
I18N_EN["enabling_bbr"]="Enabling BBR congestion control..."
I18N_EN["bbr_already_enabled"]="BBR already enabled"
I18N_EN["bbr_enabled"]="BBR enabled successfully"
I18N_EN["bbr_failed"]="Failed to enable BBR"
I18N_EN["disabling_ipv6"]="Disabling IPv6..."
I18N_EN["enabling_ipv6"]="Enabling IPv6..."
I18N_EN["ipv6_disabled"]="IPv6 disabled (requires reboot for full effect)"
I18N_EN["ipv6_enabled"]="IPv6 enabled (requires reboot for full effect)"
I18N_EN["ipv6_status"]="IPv6 Status:"
I18N_EN["ipv6_disabled_sysctl"]="IPv6: DISABLED (via sysctl)"
I18N_EN["ipv6_enabled_sysctl"]="IPv6: ENABLED (via sysctl)"
I18N_EN["public_ipv6"]="Public IPv6"
I18N_EN["not_detected"]="Not detected"
I18N_EN["interfaces_with_ipv6"]="Interfaces with IPv6"
I18N_EN["server_information"]="SERVER INFORMATION"
I18N_EN["memory"]="Memory"
I18N_EN["disk_usage"]="Disk Usage"
I18N_EN["network"]="Network"
I18N_EN["public_ipv4"]="Public IPv4"
I18N_EN["virtualization"]="Virtualization"
I18N_EN["unknown"]="Unknown"
I18N_EN["load_average"]="Load Average"
I18N_EN["testing_network"]="Testing network connectivity..."
I18N_EN["ipv4_connectivity"]="IPv4 Connectivity"
I18N_EN["reachable"]="REACHABLE"
I18N_EN["unreachable"]="UNREACHABLE"
I18N_EN["dns_resolution"]="DNS Resolution"
I18N_EN["dns_ok"]="OK"
I18N_EN["dns_failed"]="FAILED"
I18N_EN["ipv6_connectivity"]="IPv6 Connectivity"
I18N_EN["no_public_ipv6"]="No public IPv6 detected"
I18N_EN["http_https"]="HTTP/HTTPS"
I18N_EN["http_ok"]="OK"
I18N_EN["http_failed"]="FAILED"
I18N_EN["http_code"]="code"
I18N_EN["installing_speedtest"]="Installing speedtest-cli..."
I18N_EN["speedtest_failed_install"]="Failed to install speedtest-cli"
I18N_EN["running_speedtest"]="Running speed test (this may take 30-60 seconds)..."
I18N_EN["speedtest_failed"]="Speed test failed"
I18N_EN["enter_domain"]="Enter domain to check"
I18N_EN["domain_required"]="Domain required"
I18N_EN["checking_domain"]="Checking domain"
I18N_EN["a_records"]="A Records (IPv4)"
I18N_EN["no_a_records"]="No A records found"
I18N_EN["aaaa_records"]="AAAA Records (IPv6)"
I18N_EN["no_aaaa_records"]="No AAAA records found"
I18N_EN["server_ip"]="Server IP"
I18N_EN["domain_matches"]="Domain A record matches server IP"
I18N_EN["domain_not_match"]="Domain A record does NOT match server IP"
I18N_EN["https_check"]="HTTPS Check"
I18N_EN["https_accessible"]="HTTPS accessible"
I18N_EN["https_not_accessible"]="HTTPS not accessible or returns non-2xx"
I18N_EN["installing_3xui"]="Installing 3x-ui panel..."
I18N_EN["3xui_confirm"]="This will install 3x-ui from MHSanaei's repository. Continue?"
I18N_EN["3xui_download_failed"]="Failed to download 3x-ui installer"
I18N_EN["3xui_empty"]="Downloaded installer is empty"
I18N_EN["3xui_install_failed"]="3x-ui installation failed"
I18N_EN["3xui_completed"]="3x-ui installation completed"
I18N_EN["3xui_url"]="Panel URL"
I18N_EN["3xui_username"]="Username"
I18N_EN["3xui_password"]="Password"
I18N_EN["3xui_port"]="Port (default)"
I18N_EN["3xui_change_creds"]="CHANGE DEFAULT CREDENTIALS IMMEDIATELY AFTER FIRST LOGIN!"
I18N_EN["3xui_cancelled"]="Installation cancelled"
I18N_EN["enter_username"]="Enter username"
I18N_EN["username_empty"]="Username cannot be empty"
I18N_EN["invalid_username"]="Invalid username. Use lowercase, numbers, underscore, hyphen. Start with letter/underscore."
I18N_EN["user_exists"]="User already exists"
I18N_EN["enter_password"]="Enter password"
I18N_EN["password_too_short"]="Password must be at least 8 characters"
I18N_EN["confirm_password"]="Confirm password"
I18N_EN["passwords_not_match"]="Passwords do not match"
I18N_EN["user_created"]="User created"
I18N_EN["failed_create_user"]="Failed to create user"
I18N_EN["add_to_sudo"]="Add user to sudo group?"
I18N_EN["added_to_sudo"]="Added to sudo group"
I18N_EN["setup_ssh_key"]="Setup SSH key for this user?"
I18N_EN["paste_ssh_key"]="Paste public SSH key"
I18N_EN["ssh_key_configured"]="SSH key configured"
I18N_EN["enter_username_sudo"]="Enter username for passwordless sudo"
I18N_EN["user_not_found"]="User not found"
I18N_EN["sudo_configured"]="Passwordless sudo configured for"
I18N_EN["sudo_invalid"]="Invalid sudoers syntax, removing file"
I18N_EN["exiting"]="Exiting"
I18N_EN["internet_required"]="Internet connection required for this feature"
I18N_EN["cancelled"]="Cancelled"
I18N_EN["continue"]="Continue?"
I18N_EN["yes"]="Yes"
I18N_EN["no"]="No"
I18N_EN["select_option"]="Select option"
I18N_EN["interrupted_by_user"]="Interrupted by user. Cleaning up..."
I18N_EN["not_detected"]="Not detected"
I18N_EN["cfg_firewall"]="Configure Firewall (UFW)"
I18N_EN["allowed_port"]="Allowed port"
I18N_EN["os"]="OS"
I18N_EN["kernel"]="Kernel"
I18N_EN["arch"]="Architecture"
I18N_EN["uptime"]="Uptime"
I18N_EN["cpu"]="CPU"
I18N_EN["memory"]="Memory"
I18N_EN["disk_usage"]="Disk Usage"
I18N_EN["network"]="Network"
I18N_EN["virtualization"]="Virtualization"
I18N_EN["load_average"]="Load Average"
I18N_EN["unknown"]="Unknown"
I18N_EN["public_ipv4"]="Public IPv4"
I18N_EN["public_ipv6"]="Public IPv6"
I18N_EN["testing_network"]="Testing network connectivity..."
I18N_EN["ipv4_conn"]="IPv4 Connectivity"
I18N_EN["reachable"]="REACHABLE"
I18N_EN["unreachable"]="UNREACHABLE"
I18N_EN["dns_resolution"]="DNS Resolution"
I18N_EN["dns_ok"]="OK"
I18N_EN["dns_fail"]="FAILED"
I18N_EN["ipv6_conn"]="IPv6 Connectivity"
I18N_EN["no_ipv6"]="No public IPv6 detected"
I18N_EN["https_https"]="HTTP/HTTPS"
I18N_EN["https_ok"]="OK"
I18N_EN["http_fail"]="FAILED"

# Russian translations
I18N_RU["lang_name"]="Русский"
I18N_RU["select_language"]="Select language / Выберите язык:"
I18N_RU["lang_en"]="1) English"
I18N_RU["lang_ru"]="2) Русский"
I18N_RU["invalid_option"]="Неверный вариант"
I18N_RU["must_run_as_root"]="Этот скрипт должен быть запущен от root"
I18N_RU["os_detected"]="Обнаружена ОС"
I18N_RU["unsupported_os"]="Неподдерживаемая ОС"
I18N_RU["required"]="требуется"
I18N_RU["architecture"]="Архитектура"
I18N_RU["unsupported_arch"]="Неподдерживаемая архитектура"
I18N_RU["kernel_too_old"]="Слишком старое ядро. BBR требует ядро >="
I18N_RU["apt_lock_timeout"]="Таймаут блокировки apt после"
I18N_RU["waiting_apt"]="Ожидание блокировки apt..."
I18N_RU["update_failed"]="apt-get update завершился с ошибкой"
I18N_RU["package_list_updated"]="Список пакетов обновлен"
I18N_RU["package_already_installed"]="Пакет уже установлен"
I18N_RU["installing"]="Установка"
I18N_RU["installed"]="Установлен"
I18N_RU["failed_to_install"]="Не удалось установить"
I18N_RU["backed_up"]="Резервная копия создана"
I18N_RU["restored"]="Восстановлено"
I18N_RU["no_backup_found"]="Резервная копия не найдена для"
I18N_RU["ssh_test_passed"]="Тест конфигурации SSH пройден"
I18N_RU["ssh_test_failed"]="Тест конфигурации SSH не пройден"
I18N_RU["restarting_service"]="Перезапуск службы"
I18N_RU["service_restarted"]="Служба перезапущена"
I18N_RU["failed_to_restart"]="Не удалось перезапустить"
I18N_RU["service_enabled"]="Служба включена"
I18N_RU["failed_to_enable"]="Не удалось включить"
I18N_RU["press_any_key"]="Нажмите любую клавишу для продолжения..."
I18N_RU["menu_title"]="МЕНЮ"
I18N_RU["update_system"]="Обновление системы"
I18N_RU["install_base_packages"]="Установка базовых пакетов"
I18N_RU["configure_ssh"]="Настройка SSH"
I18N_RU["configure_firewall"]="Настройка Firewall (UFW)"
I18N_RU["install_fail2ban"]="Установка Fail2Ban"
I18N_RU["create_swap"]="Создание Swap"
I18N_RU["enable_bbr"]="Включение BBR"
I18N_RU["manage_ipv6"]="Управление IPv6"
I18N_RU["server_info"]="Информация о сервере"
I18N_RU["network_test"]="Проверка сети"
I18N_RU["speed_test"]="Проверка скорости"
I18N_RU["domain_check"]="Проверка домена"
I18N_RU["install_3xui"]="Установка 3x-ui"
I18N_RU["create_user"]="Создание пользователя"
I18N_RU["configure_sudo"]="Настройка Sudo (без пароля)"
I18N_RU["exit"]="Выход"
I18N_RU["updating_package_list"]="Обновление списка пакетов..."
I18N_RU["upgrading_packages"]="Обновление пакетов..."
I18N_RU["packages_upgraded"]="Пакеты обновлены"
I18N_RU["upgrade_failed"]="Обновление не удалось"
I18N_RU["removing_unused"]="Удаление неиспользуемых пакетов..."
I18N_RU["autoremove_failed"]="autoremove завершился с кодом"
I18N_RU["autoclean_failed"]="autoclean завершился с кодом"
I18N_RU["cleanup_complete"]="Очистка завершена"
I18N_RU["installing_base"]="Установка базовых пакетов"
I18N_RU["all_base_installed"]="Все базовые пакеты обработаны"
I18N_RU["configuring_ssh"]="Настройка SSH..."
I18N_RU["current_ssh_port"]="Текущий порт SSH"
I18N_RU["enter_ssh_port"]="Введите порт SSH"
I18N_RU["invalid_port"]="Неверный порт. Должен быть 1-65535"
I18N_RU["disable_password_auth"]="Отключить аутентификацию по паролю? (только ключи)"
I18N_RU["disable_root_login"]="Отключить вход под root?"
I18N_RU["applying_ssh"]="Применение конфигурации SSH..."
I18N_RU["ssh_config_failed"]="Тест конфигурации SSH не пройден. Восстановление из резервной копии..."
I18N_RU["ssh_configured"]="SSH настроен на порту"
I18N_RU["ssh_warning"]="ВАЖНО: Убедитесь, что у вас есть SSH-ключ перед отключением!"
I18N_RU["configuring_ufw"]="Настройка фаервола UFW..."
I18N_RU["ufw_reset_warning"]="ВНИМАНИЕ: Это сбросит ВСЕ существующие правила UFW. Продолжить?"
I18N_RU["ufw_rules_reset"]="Правила UFW сброшены"
I18N_RU["ufw_skipping_reset"]="Пропуск сброса UFW"
I18N_RU["ufw_enabled"]="UFW включен"
I18N_RU["ufw_not_enabled"]="UFW настроен, но не включен"
I18N_RU["installing_fail2ban"]="Установка Fail2Ban..."
I18N_RU["fail2ban_configured"]="Fail2Ban установлен и настроен (мониторинг порта"
I18N_RU["swap_exists"]="Файл подкачки уже существует"
I18N_RU["current_size"]="Текущий размер"
I18N_RU["recreate_swap"]="Пересоздать файл подкачки?"
I18N_RU["enter_swap_size"]="Введите размер swap в ГБ (например, 2, 4)"
I18N_RU["invalid_swap_size"]="Неверный размер. Введите 1-64 ГБ"
I18N_RU["not_enough_space"]="Недостаточно места на диске. Доступно"
I18N_RU["requested"]="запрошено"
I18N_RU["creating_swap"]="Создание файла подкачки..."
I18N_RU["fallocate_failed"]="fallocate не удался, используем dd (медленнее)..."
I18N_RU["dd_failed"]="Не удалось создать swap с помощью dd"
I18N_RU["mkswap_failed"]="mkswap не удался"
I18N_RU["swapon_failed"]="swapon не удался"
I18N_RU["swap_created"]="Swap создан"
I18N_RU["enabling_bbr"]="Включение BBR congestion control..."
I18N_RU["bbr_already_enabled"]="BBR уже включен"
I18N_RU["bbr_enabled"]="BBR успешно включен"
I18N_RU["bbr_failed"]="Не удалось включить BBR"
I18N_RU["disabling_ipv6"]="Отключение IPv6..."
I18N_RU["enabling_ipv6"]="Включение IPv6..."
I18N_RU["ipv6_disabled"]="IPv6 отключен (требуется перезагрузка)"
I18N_RU["ipv6_enabled"]="IPv6 включен (требуется перезагрузка)"
I18N_RU["ipv6_status"]="Статус IPv6:"
I18N_RU["ipv6_disabled_sysctl"]="IPv6: ОТКЛЮЧЕН (через sysctl)"
I18N_RU["ipv6_enabled_sysctl"]="IPv6: ВКЛЮЧЕН (через sysctl)"
I18N_RU["public_ipv6"]="Публичный IPv6"
I18N_RU["not_detected"]="Не обнаружен"
I18N_RU["interfaces_with_ipv6"]="Интерфейсы с IPv6"
I18N_RU["server_information"]="ИНФОРМАЦИЯ О СЕРВЕРЕ"
I18N_RU["memory"]="Память"
I18N_RU["disk_usage"]="Использование диска"
I18N_RU["network"]="Сеть"
I18N_RU["public_ipv4"]="Публичный IPv4"
I18N_RU["virtualization"]="Виртуализация"
I18N_RU["unknown"]="Неизвестно"
I18N_RU["load_average"]="Средняя нагрузка"
I18N_RU["testing_network"]="Проверка сетевого соединения..."
I18N_RU["ipv4_connectivity"]="IPv4 соединение"
I18N_RU["reachable"]="ДОСТУПЕН"
I18N_RU["unreachable"]="НЕДОСТУПЕН"
I18N_RU["dns_resolution"]="DNS резолвинг"
I18N_RU["dns_ok"]="ОК"
I18N_RU["dns_failed"]="ОШИБКА"
I18N_RU["ipv6_connectivity"]="IPv6 соединение"
I18N_RU["no_public_ipv6"]="Публичный IPv6 не обнаружен"
I18N_RU["http_https"]="HTTP/HTTPS"
I18N_RU["http_ok"]="ОК"
I18N_RU["http_failed"]="ОШИБКА"
I18N_RU["http_code"]="код"
I18N_RU["installing_speedtest"]="Установка speedtest-cli..."
I18N_RU["speedtest_failed_install"]="Не удалось установить speedtest-cli"
I18N_RU["running_speedtest"]="Запуск теста скорости (это может занять 30-60 секунд)..."
I18N_RU["speedtest_failed"]="Тест скорости не удался"
I18N_RU["enter_domain"]="Введите домен для проверки"
I18N_RU["domain_required"]="Требуется домен"
I18N_RU["checking_domain"]="Проверка домена"
I18N_RU["a_records"]="A-записи (IPv4)"
I18N_RU["no_a_records"]="A-записи не найдены"
I18N_RU["aaaa_records"]="AAAA-записи (IPv6)"
I18N_RU["no_aaaa_records"]="AAAA-записи не найдены"
I18N_RU["server_ip"]="IP сервера"
I18N_RU["domain_matches"]="A-запись домена совпадает с IP сервера"
I18N_RU["domain_not_match"]="A-запись домена НЕ совпадает с IP сервера"
I18N_RU["https_check"]="Проверка HTTPS"
I18N_RU["https_accessible"]="HTTPS доступен"
I18N_RU["https_not_accessible"]="HTTPS недоступен или возвращает не-2xx"
I18N_RU["installing_3xui"]="Установка панели 3x-ui..."
I18N_RU["3xui_confirm"]="Будет установлена панель 3x-ui из репозитория MHSanaei. Продолжить?"
I18N_RU["3xui_download_failed"]="Не удалось скачать установщик 3x-ui"
I18N_RU["3xui_empty"]="Скачанный установщик пуст"
I18N_RU["3xui_install_failed"]="Установка 3x-ui не удалась"
I18N_RU["3xui_completed"]="Установка 3x-ui завершена"
I18N_RU["3xui_url"]="URL панели"
I18N_RU["3xui_username"]="Имя пользователя"
I18N_RU["3xui_password"]="Пароль"
I18N_RU["3xui_port"]="Порт (по умолчанию)"
I18N_RU["3xui_change_creds"]="ИЗМЕНИТЕ СТАНДАРТНЫЕ ДАННЫЕ СРАЗУ ПОСЛЕ ПЕРВОГО ВХОДА!"
I18N_RU["3xui_cancelled"]="Установка отменена"
I18N_RU["enter_username"]="Введите имя пользователя"
I18N_RU["username_empty"]="Имя пользователя не может быть пустым"
I18N_RU["invalid_username"]="Неверное имя пользователя. Используйте строчные буквы, цифры, подчеркивание, дефис. Начните с буквы/подчеркивания."
I18N_RU["user_exists"]="Пользователь уже существует"
I18N_RU["enter_password"]="Введите пароль"
I18N_RU["password_too_short"]="Пароль должен быть не менее 8 символов"
I18N_RU["confirm_password"]="Подтвердите пароль"
I18N_RU["passwords_not_match"]="Пароли не совпадают"
I18N_RU["user_created"]="Пользователь создан"
I18N_RU["failed_create_user"]="Не удалось создать пользователя"
I18N_RU["add_to_sudo"]="Добавить пользователя в группу sudo?"
I18N_RU["added_to_sudo"]="Добавлен в группу sudo"
I18N_RU["setup_ssh_key"]="Настроить SSH-ключ для этого пользователя?"
I18N_RU["paste_ssh_key"]="Вставьте публичный SSH-ключ"
I18N_RU["ssh_key_configured"]="SSH-ключ настроен"
I18N_RU["enter_username_sudo"]="Введите имя пользователя для sudo без пароля"
I18N_RU["user_not_found"]="Пользователь не найден"
I18N_RU["sudo_configured"]="Sudo без пароля настроен для"
I18N_RU["sudo_invalid"]="Неверный синтаксис sudoers, файл удален"
I18N_RU["exiting"]="Выход"
I18N_RU["internet_required"]="Для этой функции требуется интернет-соединение"
I18N_RU["cancelled"]="Отменено"
I18N_RU["continue"]="Продолжить?"
I18N_RU["yes"]="Да"
I18N_RU["no"]="Нет"
I18N_RU["select_option"]="Выберите вариант"
I18N_RU["interrupted_by_user"]="Прервано пользователем. Очистка..."
I18N_RU["not_detected"]="Не обнаружен"
I18N_RU["cfg_firewall"]="Настройка Firewall (UFW)"
I18N_RU["allowed_port"]="Открыт порт"
I18N_RU["os"]="ОС"
I18N_RU["kernel"]="Ядро"
I18N_RU["arch"]="Архитектура"
I18N_RU["uptime"]="Время работы"
I18N_RU["cpu"]="Процессор"
I18N_RU["memory"]="Память"
I18N_RU["disk_usage"]="Использование диска"
I18N_RU["network"]="Сеть"
I18N_RU["virtualization"]="Виртуализация"
I18N_RU["load_average"]="Средняя нагрузка"
I18N_RU["unknown"]="Неизвестно"
I18N_RU["public_ipv4"]="Публичный IPv4"
I18N_RU["public_ipv6"]="Публичный IPv6"
I18N_RU["testing_network"]="Проверка сетевого соединения..."
I18N_RU["ipv4_conn"]="IPv4 соединение"
I18N_RU["reachable"]="ДОСТУПЕН"
I18N_RU["unreachable"]="НЕДОСТУПЕН"
I18N_RU["dns_resolution"]="DNS резолвинг"
I18N_RU["dns_ok"]="ОК"
I18N_RU["dns_fail"]="ОШИБКА"
I18N_RU["ipv6_conn"]="IPv6 соединение"
I18N_RU["no_ipv6"]="Публичный IPv6 не обнаружен"
I18N_RU["https_https"]="HTTP/HTTPS"
I18N_RU["https_ok"]="ОК"
I18N_RU["http_fail"]="ОШИБКА"
I18N_RU["back"]="Назад в главное меню"

# Translation function
_() {
    local key="$1"
    if [[ "$CURRENT_LANG" == "ru" && -n "${I18N_RU[$key]}" ]]; then
        echo "${I18N_RU[$key]}"
    else
        echo "${I18N_EN[$key]}"
    fi
}

# Language selection
select_language() {
    echo -e "${CYAN}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║              Select Language / Выберите язык                 ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo -e "  ${GREEN}1)${NC} English"
    echo -e "  ${GREEN}2)${NC} Русский"
    echo
    read -r -p "$(echo -e "${YELLOW}Enter choice / Введите выбор [1-2]: ${NC}")" choice

    case "$choice" in
        2)
            CURRENT_LANG="ru"
            ok "Language set to: Русский"
            ;;
        1|*)
            CURRENT_LANG="en"
            ok "Language set to: English"
            ;;
    esac
    echo
}

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
    info "$(_ "interrupted_by_user")"
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
    local prompt="${1:-$(_ "continue")}"
    local default="${2:-N}"
    local yes_str="$(_ "yes")"
    local no_str="$(_ "no")"
    local response

    if [[ "$default" =~ ^[Yy]$ ]]; then
        prompt="$prompt [$yes_str/$(_ "no")]: "
    else
        prompt="$prompt [$(_ "yes")/$no_str]: "
    fi

    read -r -p "$(echo -e "${YELLOW}${prompt}${NC}")" response
    response=${response:-$default}
    [[ "$response" =~ ^[Yy]$ ]]
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        err "$(_ "must_run_as_root")"
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
    echo -e "\n${CYAN}$(_ "press_any_key")${NC}"
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

print_header() {
    echo -e "${CYAN}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                    VPS QuickStart v${SCRIPT_VERSION}                   ║"
    echo "║              Professional Server Setup Script                ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    local os_info="Unknown"
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        os_info="$PRETTY_NAME"
    fi

    echo -e "${BLUE}OS:${NC} $os_info"
    echo -e "${BLUE}Kernel:${NC} $(uname -r)"
    echo -e "${BLUE}Arch:${NC} $(uname -m)"
    echo -e "${BLUE}Uptime:${NC} $(uptime -p 2>/dev/null || uptime | sed 's/.*up \([^,]*\),.*/\1/')"
    echo -e "${BLUE}IPv4:${NC} ${CACHED_PUBLIC_IP:-$(_ "not_detected")}"
    [[ -n "$CACHED_PUBLIC_IPV6" ]] && echo -e "${BLUE}IPv6:${NC} $CACHED_PUBLIC_IPV6"
    echo
}

# Print menu
print_menu() {
    local menu_title="MENU"
    if [[ "$CURRENT_LANG" == "ru" ]]; then
        menu_title="МЕНЮ"
    fi
    echo -e "${BOLD}════════════════════════════ $menu_title ════════════════════════════${NC}"
    echo -e "  ${GREEN}1)${NC}  $(_ "update_system")"
    echo -e "  ${GREEN}2)${NC}  $(_ "install_base_packages")"
    echo -e "  ${GREEN}3)${NC}  $(_ "configure_ssh")"
    echo -e "  ${GREEN}4)${NC}  $(_ "configure_firewall")"
    echo -e "  ${GREEN}5)${NC}  $(_ "install_fail2ban")"
    echo -e "  ${GREEN}6)${NC}  $(_ "create_swap")"
    echo -e "  ${GREEN}7)${NC}  $(_ "enable_bbr")"
    echo -e "  ${GREEN}8)${NC}  $(_ "manage_ipv6")"
    echo -e "  ${GREEN}9)${NC}  $(_ "server_info")"
    echo -e "  ${GREEN}10)${NC} $(_ "network_test")"
    echo -e "  ${GREEN}11)${NC} $(_ "speed_test")"
    echo -e "  ${GREEN}12)${NC} $(_ "domain_check")"
    echo -e "  ${GREEN}13)${NC} $(_ "install_3xui")"
    echo -e "  ${GREEN}14)${NC} $(_ "create_user")"
    echo -e "  ${GREEN}15)${NC} $(_ "configure_sudo")"
    echo -e "  ${RED}16)${NC} $(_ "exit")"
    echo -e "${BOLD}═══════════════════════════════════════════════════════════════════════${NC}"
}

# =============================================================================
# FEATURE FUNCTIONS
# =============================================================================

# 1. Update System
update_system() {
    info "$(_ "updating_package_list")"
    apt_update || return 1

    info "$(_ "upgrading_packages")"
    wait_apt_lock || return 1
    local output
    output=$(apt-get upgrade -y 2>&1)
    local rc=${PIPESTATUS[0]}

    if [[ $rc -eq 0 ]]; then
        ok "$(_ "packages_upgraded")"
    else
        err "$(_ "upgrade_failed") (code: $rc)"
        echo "$output" | tail -20 >&2
        return 1
    fi

    info "$(_ "removing_unused")"
    output=$(apt-get autoremove -y 2>&1)
    rc=${PIPESTATUS[0]}
    if [[ $rc -ne 0 ]]; then
        warn "$(_ "autoremove_failed") $rc"
        echo "$output" | tail -10 >&2
    fi

    output=$(apt-get autoclean -y 2>&1)
    rc=${PIPESTATUS[0]}
    if [[ $rc -ne 0 ]]; then
        warn "$(_ "autoclean_failed") $rc"
        echo "$output" | tail -10 >&2
    fi

    ok "$(_ "cleanup_complete")"
    return 0
}

# 2. Install Base Packages
install_base_packages() {
    info "$(_ "installing_base"): ${PACKAGES[*]}"
    install_packages "${PACKAGES[@]}" || return 1
    ok "$(_ "all_base_installed")"
    return 0
}

# 3. Configure SSH
configure_ssh() {
    info "$(_ "configuring_ssh")"

    # Backup current config
    backup_file "$SSH_CONFIG_FILE"

    # Get current port
    local current_port
    current_port=$(get_current_ssh_port)
    info "$(_ "current_ssh_port"): $current_port"

    # Get new port
    local new_port
    while true; do
        read -r -p "$(echo -e "${YELLOW}$(_ "enter_ssh_port") [$current_port]: ${NC}")" new_port
        new_port=${new_port:-$current_port}
        if [[ "$new_port" =~ ^[0-9]+$ ]] && (( new_port >= 1 && new_port <= 65535 )); then
            break
        fi
        err "$(_ "invalid_port")"
    done

    # Disable password auth?
    local disable_password
    if confirm "$(_ "disable_password_auth")" "N"; then
        disable_password="no"
    else
        disable_password="yes"
    fi

    # Disable root login?
    local disable_root
    if confirm "$(_ "disable_root_login")" "Y"; then
        disable_root="no"
    else
        disable_root="yes"
    fi

    # Apply changes
    info "$(_ "applying_ssh")"

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
        err "$(_ "ssh_config_failed")"
        restore_file "$SSH_CONFIG_FILE"
        return 1
    fi

    CACHED_SSH_PORT="$new_port"
    restart_service ssh || return 1

    ok "$(_ "ssh_configured") $new_port"
    warn "$(_ "ssh_warning")"
    return 0
}

# 4. Configure Firewall (UFW)
configure_firewall() {
    info "$(_ "configuring_ufw")"

    install_package ufw || return 1

    # Warning about reset
    if confirm "$(_ "ufw_reset_warning")" "N"; then
        ufw --force reset 2>/dev/null
        ok "$(_ "ufw_rules_reset")"
    else
        info "$(_ "ufw_skipping_reset")"
    fi

    # Default policies
    ufw default deny incoming
    ufw default allow outgoing

    # Allow SSH port (current from config)
    local ssh_port
    ssh_port=$(get_current_ssh_port)
    ufw allow "$ssh_port"/tcp comment "SSH"
    ok "$(_ "allowed_port"): $ssh_port ($(_ "configure_ssh"))"

    # Allow additional ports
    for port in "${UFW_PORTS[@]}"; do
        if [[ "$port" != "$ssh_port" ]]; then
            ufw allow "$port"/tcp comment "Service"
            ok "$(_ "allowed_port"): $port"
        fi
    done

    # Enable UFW
    if confirm "$(_ "ufw_enabled")" "Y"; then
        ufw --force enable
        ok "$(_ "ufw_enabled")"
    else
        warn "$(_ "ufw_not_enabled")"
    fi

    ufw status verbose
    return 0
}

# 5. Install Fail2Ban
install_fail2ban() {
    info "$(_ "installing_fail2ban")"

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
    ok "$(_ "fail2ban_configured") $ssh_port)"
    return 0
}

# 6. Create Swap
create_swap() {
    if [[ -f "$SWAP_FILE" ]]; then
        warn "$(_ "swap_exists"): $SWAP_FILE"
        local size
        size=$(ls -lh "$SWAP_FILE" | awk '{print $5}')
        info "$(_ "current_size"): $size"
        if ! confirm "$(_ "recreate_swap")" "N"; then
            return 0
        fi
        swapoff "$SWAP_FILE" 2>/dev/null || true
        rm -f "$SWAP_FILE"
    fi

    local size_gb
    while true; do
        read -r -p "$(echo -e "${YELLOW}$(_ "enter_swap_size"): ${NC}")" size_gb
        if [[ "$size_gb" =~ ^[0-9]+$ ]] && (( size_gb >= 1 && size_gb <= 64 )); then
            break
        fi
        err "$(_ "invalid_swap_size")"
    done

    # Check disk space
    local available_gb
    available_gb=$(df -BG / | tail -1 | awk '{print $4}' | tr -d 'G')
    if (( size_gb + 2 > available_gb )); then
        err "$(_ "not_enough_space"): ${available_gb}GB, $(_ "requested"): ${size_gb}GB (+2GB buffer)"
        return 1
    fi

    info "$(_ "creating_swap")"
    if fallocate -l "${size_gb}G" "$SWAP_FILE" 2>/dev/null; then
        : # success
    else
        info "$(_ "fallocate_failed")"
        if ! dd if=/dev/zero of="$SWAP_FILE" bs=1M count=$((size_gb * 1024)) status=progress 2>&1; then
            err "$(_ "dd_failed")"
            rm -f "$SWAP_FILE"
            return 1
        fi
    fi

    chmod 600 "$SWAP_FILE"
    if ! mkswap "$SWAP_FILE" 2>/dev/null; then
        err "$(_ "mkswap_failed")"
        rm -f "$SWAP_FILE"
        return 1
    fi

    if ! swapon "$SWAP_FILE" 2>/dev/null; then
        err "$(_ "swapon_failed")"
        rm -f "$SWAP_FILE"
        return 1
    fi

    # Add to fstab if not present
    if ! grep -q "^$SWAP_FILE " /etc/fstab; then
        echo "$SWAP_FILE none swap sw 0 0" >> /etc/fstab
    fi

    ok "$(_ "swap_created"): ${size_gb}GB"
    swapon --show
    return 0
}

# 7. Enable BBR
enable_bbr() {
    info "$(_ "enabling_bbr")"

    if ! check_kernel_version; then
        return 1
    fi

    # Check if already enabled
    if sysctl net.ipv4.tcp_congestion_control 2>/dev/null | grep -q bbr; then
        ok "$(_ "bbr_already_enabled")"
        return 0
    fi

    # Apply sysctl settings
    cat > /etc/sysctl.d/99-bbr.conf <<'EOF'
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
EOF

    if ! sysctl --system 2>/dev/null; then
        err "$(_ "bbr_failed")"
        return 1
    fi

    if sysctl net.ipv4.tcp_congestion_control 2>/dev/null | grep -q bbr; then
        ok "$(_ "bbr_enabled")"
        return 0
    else
        err "$(_ "bbr_failed")"
        return 1
    fi
}

# 8. Manage IPv6
manage_ipv6() {
    while true; do
        print_header
        local ipv6_title="IPv6 MANAGEMENT"
        if [[ "$CURRENT_LANG" == "ru" ]]; then
            ipv6_title="УПРАВЛЕНИЕ IPv6"
        fi
        echo -e "${BOLD}════════════════════════════ $ipv6_title ════════════════════════════${NC}"
        echo -e "  ${GREEN}1)${NC} $(_ "disabling_ipv6")"
        echo -e "  ${GREEN}2)${NC} $(_ "enabling_ipv6")"
        echo -e "  ${GREEN}3)${NC} $(_ "ipv6_status")"
        echo -e "  ${RED}4)${NC} $(_ "back")"
        echo -e "${BOLD}═══════════════════════════════════════════════════════════════════════${NC}"

        read -r -p "$(echo -e "${YELLOW}$(_ "select_option") [1-4]: ${NC}")" choice

        case "$choice" in
            1) disable_ipv6 ;;
            2) enable_ipv6 ;;
            3) check_ipv6_status ;;
            4) return 0 ;;
            *) err "$(_ "invalid_option")" ;;
        esac
        press_any_key
    done
}

disable_ipv6() {
    info "$(_ "disabling_ipv6")"
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

    ok "$(_ "ipv6_disabled")"
}

enable_ipv6() {
    info "$(_ "enabling_ipv6")"
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

    ok "$(_ "ipv6_enabled")"
}

check_ipv6_status() {
    info "$(_ "ipv6_status")"
    local disabled
    disabled=$(sysctl -n net.ipv6.conf.all.disable_ipv6 2>/dev/null)
    if [[ "$disabled" == "1" ]]; then
        echo -e "  ${RED}$(_ "ipv6_disabled_sysctl")${NC}"
    else
        echo -e "  ${GREEN}$(_ "ipv6_enabled_sysctl")${NC}"
    fi

    local ipv6_addr="$CACHED_PUBLIC_IPV6"
    if [[ -n "$ipv6_addr" ]]; then
        echo -e "  ${GREEN}$(_ "public_ipv6"):${NC} $ipv6_addr"
    else
        echo -e "  ${YELLOW}$(_ "public_ipv6"):${NC} $(_ "not_detected")"
    fi

    # Check interfaces
    echo -e "  ${BLUE}$(_ "interfaces_with_ipv6"):${NC}"
    ip -6 addr show scope global 2>/dev/null | grep -E '^ [0-9]+:|inet6' | head -20 | while IFS= read -r line; do
        echo "    $line"
    done
}

server_info() {
    print_header
    echo -e "${BOLD}════════════════════════════ $(_ "server_info") ════════════════════════════${NC}"

    local os_info="$(_ "unknown")"
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        os_info="$PRETTY_NAME"
    fi
    echo -e "${CYAN}$(_ "os"):${NC} $os_info"
    echo -e "${CYAN}$(_ "kernel"):${NC} $(uname -r)"
    echo -e "${CYAN}$(_ "arch"):${NC} $(uname -m)"

    echo -e "\n${CYAN}$(_ "cpu"):${NC}"
    lscpu 2>/dev/null | grep -E 'Model name|CPU\(s\):|Thread|Core|MHz' | sed 's/^/  /'

    echo -e "\n${CYAN}$(_ "memory"):${NC}"
    free -h | sed 's/^/  /'

    echo -e "\n${CYAN}$(_ "disk_usage"):${NC}"
    df -h / | sed 's/^/  /'
    echo
    df -h | grep -vE '^Filesystem|tmpfs|udev' | sed 's/^/  /'

    echo -e "\n${CYAN}$(_ "network"):${NC}"
    echo -e "  $(_ "public_ipv4"): ${CACHED_PUBLIC_IP:-$(_ "not_detected")}"
    [[ -n "$CACHED_PUBLIC_IPV6" ]] && echo -e "  $(_ "public_ipv6"): $CACHED_PUBLIC_IPV6"
    ip -4 addr show scope global 2>/dev/null | grep -E '^ [0-9]+:|inet ' | sed 's/^/  /'

    echo -e "\n${CYAN}$(_ "virtualization"):${NC}"
    if command_exists systemd-detect-virt; then
        echo -e "  $(systemd-detect-virt)"
    elif command_exists virt-what; then
        virt-what | sed 's/^/  /'
    else
        echo "  $(_ "unknown")"
    fi

    echo -e "\n${CYAN}$(_ "load_average"):${NC} $(uptime | awk -F'load average:' '{print $2}')"

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

    # Language selection
    select_language

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
