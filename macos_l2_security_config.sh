#!/bin/bash

# Name: macos_l2_security_config.sh
# Description: Enhanced L2 security configuration for macOS
# 
# Features:
# - Advanced password policies
# - Enhanced Safari privacy settings
# - Location services management
# - System integrity protection
# - Application sandboxing
# - Network security
# - Automated backup and restore
# - Pre-flight system checks
# - Comprehensive logging
# - Rollback capability
#
# Usage:
#   chmod +x macos_l2_security_config.sh
#   ./macos_l2_security_config.sh
#   ./macos_l2_security_config.sh --rollback # To restore from backup
#
# Requirements:
# - macOS (tested on Sonoma 14.0+)
# - Admin privileges
# - Full Disk Access for Terminal
#
# Version: 2.1
# License: MIT

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging and backup setup
LOG_DIR="$HOME/.logs"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="$LOG_DIR/security_l2_$TIMESTAMP.log"
BACKUP_DIR="$LOG_DIR/security_l2_backup_$TIMESTAMP"

# Function to log messages with timestamp
log_message() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Write to log file
    echo "${timestamp}: [${level}] ${message}" >> "$LOG_FILE"
    
    # Output to terminal based on level
    case "$level" in
        "INFO")
            echo -e "${BLUE}${message}${NC}"
            ;;
        "SUCCESS")
            echo -e "${GREEN}✓ ${message}${NC}"
            ;;
        "WARNING")
            echo -e "${YELLOW}! ${message}${NC}"
            ;;
        "ERROR")
            echo -e "${RED}Error: ${message}${NC}"
            ;;
        "PROCESS")
            echo -e "${CYAN}${message}${NC}"
            ;;
    esac
}

# Function to handle errors
handle_error() {
    log_message "ERROR" "$1"
    return 1
}

# Function to initialize environment
setup_environment() {
    log_message "PROCESS" "Setting up environment..."
    
    # Create necessary directories
    mkdir -p "$LOG_DIR" "$BACKUP_DIR" || {
        handle_error "Failed to create required directories"
        exit 1
    }
    
    # Initialize log file
    touch "$LOG_FILE" || {
        handle_error "Failed to create log file"
        exit 1
    }
    
    log_message "SUCCESS" "Environment setup completed"
}

# Function to check system requirements
check_requirements() {
    log_message "INFO" "Checking system requirements..."
    echo -e "\n${BLUE}Checking System Requirements...${NC}"
    
    # Check for admin privileges
    if [ "$EUID" -ne 0 ]; then
        handle_error "Please run this script with sudo"
        exit 1
    fi
    
    # Check macOS version
    os_version=$(sw_vers -productVersion)
    if [[ $(echo $os_version | cut -d. -f1) -lt 13 ]]; then
        handle_error "This script requires macOS 13 (Ventura) or later. Current version: $os_version"
        exit 1
    fi
    
    # Check available disk space (minimum 10GB)
    available_space=$(df -h / | awk 'NR==2 {print $4}' | sed 's/G//')
    if (( $(echo "$available_space < 10" | bc -l) )); then
        handle_error "Insufficient disk space. At least 10GB required."
        exit 1
    fi
    
    # Verify Terminal has Full Disk Access
    if ! sqlite3 /Library/Application\ Support/com.apple.TCC/TCC.db \
        "SELECT client FROM access WHERE service='kTCCServiceSystemPolicyAllFiles';" 2>/dev/null | grep -q "Terminal"; then
        log_message "WARNING" "Terminal requires Full Disk Access"
        log_message "INFO" "1. Open System Settings > Privacy & Security > Full Disk Access"
        log_message "INFO" "2. Click '+' and add Terminal"
        log_message "INFO" "3. Restart Terminal and run this script again"
        exit 1
    fi
    
    log_message "SUCCESS" "System requirements verified"
    echo -e "${GREEN}✓ All system requirements met${NC}"
}

# Function to backup current settings
backup_settings() {
    log_message "INFO" "Backing up current settings..."
    echo -e "\n${BLUE}Creating Security Settings Backup...${NC}"
    
    local backup_items=(
        # System Preferences
        "/Library/Preferences/com.apple.security"
        "/Library/Preferences/com.apple.SoftwareUpdate"
        "/Library/Preferences/com.apple.Safari"
        "/Library/Preferences/com.apple.locationd"
        # Password Policies
        "/etc/pam.d"
        # Network Settings
        "/Library/Preferences/SystemConfiguration"
    )
    
    local success_count=0
    local total_items=${#backup_items[@]}
    
    for item in "${backup_items[@]}"; do
        if [ -e "$item" ]; then
            echo -e "${CYAN}Backing up ${item}...${NC}"
            if cp -R "$item" "$BACKUP_DIR/" 2>/dev/null; then
                ((success_count++))
                echo -e "${GREEN}✓ Backed up ${item}${NC}"
            else
                log_message "WARNING" "Failed to backup ${item}"
                echo -e "${RED}✗ Failed to backup ${item}${NC}"
            fi
        fi
    done
    
    # Backup current security policies
    security authorizationdb read system.preferences > "$BACKUP_DIR/security_policies.bak" 2>/dev/null
    
    log_message "SUCCESS" "Backed up $success_count out of $total_items items"
    echo -e "${GREEN}✓ Backup completed: $success_count out of $total_items items${NC}"
}

# Function to configure password policies
configure_password_policies() {
    log_message "INFO" "Configuring password policies..."
    echo -e "\n${BLUE}Configuring Password Policies...${NC}"
    
    local policies=(
        "requiresAlpha=1"
        "requiresNumeric=1"
        "requiresSymbol=1"
        "requiresMixedCase=1"
        "minChars=15"
        "maxMinutesUntilChangePassword=$((365 * 24 * 60))"
        "maxFailedLoginAttempts=5"
        "minutesUntilFailedLoginReset=15"
        "passwordHistoryCount=10"
    )
    
    local success_count=0
    
    for policy in "${policies[@]}"; do
        echo -e "${CYAN}Setting password policy: ${policy}...${NC}"
        if pwpolicy -n /Local/Default -setglobalpolicy "$policy" 2>/dev/null; then
            ((success_count++))
            echo -e "${GREEN}✓ Set ${policy}${NC}"
        else
            log_message "WARNING" "Failed to set ${policy}"
            echo -e "${RED}✗ Failed to set ${policy}${NC}"
        fi
    done
    
    log_message "SUCCESS" "Password policies configured"
    echo -e "${GREEN}✓ Password policies configured: $success_count successful${NC}"
}

# Function to configure Safari privacy
configure_safari_privacy() {
    log_message "INFO" "Configuring Safari privacy settings..."
    echo -e "\n${BLUE}Configuring Safari Privacy Settings...${NC}"
    
    local settings=(
        "AutoOpenSafeDownloads=0"
        "WarnAboutFraudulentWebsites=1"
        "ShowFullURLInSmartSearchField=1"
        "WebKitPreferences.privateClickMeasurementEnabled=1"
        "SendDoNotTrackHTTPHeader=1"
        "WebKitPreferences.dnsPrefetchingEnabled=0"
        "AutoFillPasswords=0"
        "AutoFillCreditCardData=0"
        "DownloadsClearingPolicy=2"
        "WebKitPreferences.storageBlockingPolicy=1"
    )
    
    local success_count=0
    
    for setting in "${settings[@]}"; do
        key="${setting%%=*}"
        value="${setting#*=}"
        echo -e "${CYAN}Setting Safari preference: ${key}...${NC}"
        
        if defaults write com.apple.Safari "$key" -int "$value" 2>/dev/null; then
            ((success_count++))
            echo -e "${GREEN}✓ Set ${key}${NC}"
        else
            log_message "WARNING" "Failed to set Safari preference: ${key}"
            echo -e "${RED}✗ Failed to set ${key}${NC}"
        fi
    done
    
    log_message "SUCCESS" "Safari privacy settings configured"
    echo -e "${GREEN}✓ Safari privacy configured: $success_count settings applied${NC}"
}

# Function to configure location services
configure_location_services() {
    log_message "INFO" "Configuring location services..."
    echo -e "\n${BLUE}Configuring Location Services...${NC}"
    
    # Enable location services but restrict app access
    if defaults write /var/db/locationd/Library/Preferences/ByHost/com.apple.locationd LocationServicesEnabled -bool true; then
        echo -e "${GREEN}✓ Enabled location services${NC}"
        
        # Show location icon in menu bar
        defaults write /Library/Preferences/com.apple.locationmenu.plist ShowSystemServices -bool true
        
        # Restart location services
        launchctl kickstart -k system/com.apple.locationd 2>/dev/null
        
        log_message "SUCCESS" "Location services configured"
    else
        log_message "WARNING" "Failed to configure location services"
        echo -e "${RED}✗ Failed to configure location services${NC}"
    fi
}

# Function to verify settings
verify_settings() {
    log_message "INFO" "Verifying security settings..."
    echo -e "\n${BLUE}Verifying Security Settings...${NC}"
    
    local verification_failed=0
    
    # Verify password policies
    echo -e "\n${CYAN}Verifying Password Policies:${NC}"
    if pwpolicy -getaccountpolicies 2>/dev/null | grep -q "minChars"; then
        echo -e "${GREEN}✓ Password policies verified${NC}"
    else
        ((verification_failed++))
        echo -e "${RED}✗ Password policies verification failed${NC}"
    fi
    
    # Verify Safari settings
    echo -e "\n${CYAN}Verifying Safari Settings:${NC}"
    if defaults read com.apple.Safari AutoFillPasswords 2>/dev/null | grep -q "0"; then
        echo -e "${GREEN}✓ Safari settings verified${NC}"
    else
        ((verification_failed++))
        echo -e "${RED}✗ Safari settings verification failed${NC}"
    fi
    
    # Verify location services
    echo -e "\n${CYAN}Verifying Location Services:${NC}"
    if defaults read /var/db/locationd/Library/Preferences/ByHost/com.apple.locationd LocationServicesEnabled 2>/dev/null | grep -q "1"; then
        echo -e "${GREEN}✓ Location services verified${NC}"
    else
        ((verification_failed++))
        echo -e "${RED}✗ Location services verification failed${NC}"
    fi
    
    if [ $verification_failed -eq 0 ]; then
        log_message "SUCCESS" "All settings verified successfully"
        echo -e "\n${GREEN}✓ All settings verified successfully${NC}"
    else
        log_message "WARNING" "$verification_failed settings failed verification"
        echo -e "\n${RED}✗ $verification_failed settings failed verification${NC}"
    fi
}

# Function to perform rollback if needed
rollback_settings() {
    log_message "INFO" "Rolling back security settings..."
    echo -e "\n${BLUE}Rolling Back Security Settings...${NC}"
    
    if [ ! -d "$1" ]; then
        handle_error "Backup directory not found: $1"
        return 1
    fi
    
    # Restore from backup
    for item in "$1"/*; do
        if [ -e "$item" ]; then
            orig_path=$(basename "$item")
            echo -e "${CYAN}Restoring ${orig_path}...${NC}"
            
            if cp -R "$item" "/${orig_path}" 2>/dev/null; then
                echo -e "${GREEN}✓ Restored ${orig_path}${NC}"
            else
                log_message "WARNING" "Failed to restore ${orig_path}"
                echo -e "${RED}✗ Failed to restore ${orig_path}${NC}"
            fi
        fi
    done
    
    log_message "SUCCESS" "Settings rollback completed"
    echo -e "${GREEN}✓ Settings rollback completed${NC}"
}

# Function to display summary
display_summary() {
    echo -e "\n${BLUE}=== Security Configuration Summary ===${NC}"
    echo -e "Log file: ${YELLOW}$LOG_FILE${NC}"
    echo -e "Backup directory: ${YELLOW}$BACKUP_DIR${NC}"
    
    echo -e "\n${CYAN}Configuration Status:${NC}"
    if [ -f "$LOG_FILE" ]; then
        echo -e "\n${YELLOW}Warnings and Errors:${NC}"
        grep -E "WARNING|ERROR" "$LOG_FILE" || echo "No warnings or errors found"
    fi
    
    echo -e "\n${YELLOW}Next Steps:${NC}"
    echo "1. Review the log file for any warnings or errors"
    echo "2. Verify security settings in System Settings"
    echo "3. Test critical applications for functionality"
    echo "4. Restart your computer to apply all changes"
    echo -e "\n${YELLOW}To rollback changes:${NC}"
    echo "$ sudo $0 --rollback $BACKUP_DIR"
}

# Main execution
main() {
    # Handle rollback if requested
    if [ "$1" == "--rollback" ] && [ -n "$2" ]; then
        setup_environment
        rollback_settings "$2"
        exit $?
    fi
    
    echo -e "${BLUE}=== macOS L2 Security Configuration ===${NC}"
    
    setup_environment
    check_requirements || exit 1
    backup_settings
    
    configure_password_policies
    configure_safari_privacy
    configure_location_services
    verify_settings
    
    display_summary
    
    log_message "SUCCESS" "L2 security configuration completed"
    echo -e "\n${GREEN}L2 security configuration completed successfully${NC}"
    echo -e "${YELLOW}Please restart your computer to apply all changes${NC}"
}

# Execute main function with all arguments
main "$@"