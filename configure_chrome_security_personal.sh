#!/bin/bash

# Name: configure_chrome_security_personal.sh
# Description: Configures essential Chrome security settings for personal MacBook
# With modified security levels to prevent access issues while maintaining security
# 
# Features:
# - Configures balanced security settings
# - Sets privacy preferences
# - Optimizes performance settings
# - Logs all changes
# - Provides visual feedback
# - Includes backup and restore capabilities
#
# Usage:
#   chmod +x configure_chrome_security_personal.sh
#   ./configure_chrome_security_personal.sh
#   ./configure_chrome_security_personal.sh --restore [backup_dir] # To restore backup
#   ./configure_chrome_security_personal.sh --dry-run # To preview changes without applying
#   ./configure_chrome_security_personal.sh --help # Show help
#
# Requirements:
# - macOS (tested on Sonoma 14.0+)
# - Google Chrome installed
#
# Version: 1.3
# License: MIT

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Log and backup setup
LOG_DIR="$HOME/.logs/chrome_security"
BACKUP_DIR="$LOG_DIR/chrome_backup_$(date +%Y%m%d_%H%M%S)"
LOG_FILE="$LOG_DIR/chrome_security_$(date +%Y%m%d_%H%M%S).log"
DRY_RUN=false

# Function to show help
show_help() {
    echo -e "${BLUE}=== Chrome Security Configuration Tool ===${NC}"
    echo ""
    echo -e "${YELLOW}Usage:${NC}"
    echo "  ./configure_chrome_security_personal.sh             - Configure Chrome security settings"
    echo "  ./configure_chrome_security_personal.sh --restore [backup_dir] - Restore from backup"
    echo "  ./configure_chrome_security_personal.sh --dry-run   - Preview changes without applying"
    echo "  ./configure_chrome_security_personal.sh --help      - Show this help message"
    echo ""
    echo -e "${YELLOW}Log Files:${NC}"
    echo "  $LOG_DIR"
    echo "  Backups are stored in $LOG_DIR/chrome_backup_*"
    echo ""
    echo "Note: This script requires macOS and Google Chrome to be installed."
}

# Function to log messages
log_message() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Write to log file
    echo "${timestamp}: [${level}] ${message}" >> "$LOG_FILE"
    
    # Only output to terminal if not in dry run mode or if it's an error/warning
    if [ "$DRY_RUN" = false ] || [ "$level" = "ERROR" ] || [ "$level" = "WARNING" ]; then
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
    fi
}

# Function to handle errors
handle_error() {
    log_message "ERROR" "$1"
    return 1
}

# Function to check if running on macOS
check_macos() {
    if [[ "$(uname)" != "Darwin" ]]; then
        handle_error "This script is designed for macOS only."
        exit 1
    fi
    log_message "INFO" "macOS detected: $(sw_vers -productVersion)"
}

# Function to set up logging and backup
setup_environment() {
    mkdir -p "$LOG_DIR" "$BACKUP_DIR" || handle_error "Failed to create log/backup directories"
    touch "$LOG_FILE" || handle_error "Failed to create log file"
    log_message "INFO" "Starting Chrome security configuration..."
    
    if [ "$DRY_RUN" = true ]; then
        log_message "INFO" "Running in DRY RUN mode - no changes will be applied"
        echo -e "${YELLOW}DRY RUN MODE: No changes will be applied${NC}"
    fi
}

# Function to verify Chrome installation and version
check_chrome() {
    if [ ! -d "/Applications/Google Chrome.app" ]; then
        handle_error "Google Chrome is not installed"
        exit 1
    fi
    
    # Get Chrome version
    local chrome_version=$(/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome --version 2>/dev/null | cut -d ' ' -f 3)
    
    if [[ -z "$chrome_version" ]]; then
        log_message "WARNING" "Could not determine Chrome version"
        echo -e "${YELLOW}Warning: Could not determine Chrome version${NC}"
    else
        log_message "INFO" "Chrome version: $chrome_version"
        echo -e "${GREEN}Chrome version: $chrome_version${NC}"
        
        # Check if Chrome is running
        if pgrep "Google Chrome" > /dev/null; then
            log_message "WARNING" "Chrome is currently running. Some settings may not apply until restart."
            echo -e "${YELLOW}Warning: Chrome is currently running. Some settings may not apply until restart.${NC}"
        fi
    fi
}

# Function to list available backups
list_backups() {
    echo -e "\n${BLUE}Available Backups:${NC}"
    local backups=$(find "$LOG_DIR" -type d -name "chrome_backup_*" | sort -r)
    
    if [[ -z "$backups" ]]; then
        echo -e "${YELLOW}No backups found${NC}"
        return 1
    fi
    
    local count=1
    while IFS= read -r backup; do
        local backup_date=$(echo "$backup" | grep -o "chrome_backup_[0-9_]*" | sed 's/chrome_backup_//')
        local formatted_date=$(echo "$backup_date" | sed 's/\([0-9]\{8\}\)_\([0-9]\{2\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)/\1 \2:\3:\4/')
        
        if [ -f "$backup/chrome_preferences.bak" ]; then
            echo -e "${GREEN}$count. $formatted_date${NC} - $backup"
        else
            echo -e "${RED}$count. $formatted_date${NC} - $backup (incomplete)"
        fi
        ((count++))
    done <<< "$backups"
}

# Function to backup current Chrome settings
backup_settings() {
    log_message "INFO" "Backing up current Chrome settings..."
    echo -e "\n${BLUE}Backing Up Current Settings...${NC}"
    
    # Backup Chrome preferences
    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}DRY RUN: Would backup Chrome preferences to $BACKUP_DIR/chrome_preferences.bak${NC}"
        log_message "INFO" "DRY RUN: Would backup Chrome preferences"
    else
        if defaults read com.google.Chrome > "$BACKUP_DIR/chrome_preferences.bak" 2>/dev/null; then
            log_message "SUCCESS" "Chrome preferences backed up"
            echo -e "${GREEN}✓ Chrome preferences backed up${NC}"
            
            # Also backup Chrome profile data location
            echo "$(defaults read com.google.Chrome 'UserDataDir' 2>/dev/null || echo "$HOME/Library/Application Support/Google/Chrome")" > "$BACKUP_DIR/profile_location.txt"
            
            # Save backup timestamp
            date +"%Y-%m-%d %H:%M:%S" > "$BACKUP_DIR/backup_timestamp.txt"
        else
            log_message "WARNING" "Failed to backup Chrome preferences"
            echo -e "${RED}✗ Failed to backup Chrome preferences${NC}"
        fi
    fi
}

# Function to restore settings from backup
restore_settings() {
    local backup_dir="$1"
    
    # Check if backup directory exists
    if [ ! -d "$backup_dir" ]; then
        handle_error "Backup directory not found: $backup_dir"
        return 1
    fi
    
    # Check if backup file exists
    if [ ! -f "$backup_dir/chrome_preferences.bak" ]; then
        handle_error "Backup file not found in $backup_dir"
        return 1
    fi
    
    echo -e "\n${BLUE}Restoring Chrome Settings from $(basename "$backup_dir")...${NC}"
    
    # Check if Chrome is running
    if pgrep "Google Chrome" > /dev/null; then
        echo -e "${YELLOW}Chrome is currently running. It will be closed to restore settings.${NC}"
        read -p "Continue? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_message "INFO" "Restore cancelled by user"
            echo -e "${RED}Restore cancelled${NC}"
            return 1
        fi
    fi
    
    # Kill Chrome before restore
    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}DRY RUN: Would close Chrome and restore settings from $backup_dir/chrome_preferences.bak${NC}"
        log_message "INFO" "DRY RUN: Would restore Chrome settings"
    else
        killall "Google Chrome" 2>/dev/null
        sleep 1
        
        # Restore from backup
        if defaults import com.google.Chrome "$backup_dir/chrome_preferences.bak" 2>/dev/null; then
            log_message "SUCCESS" "Chrome settings restored from $backup_dir"
            echo -e "${GREEN}✓ Chrome settings restored successfully${NC}"
            
            # Display backup timestamp if available
            if [ -f "$backup_dir/backup_timestamp.txt" ]; then
                local backup_time=$(cat "$backup_dir/backup_timestamp.txt")
                echo -e "${GREEN}Restored settings from backup created on: $backup_time${NC}"
            fi
        else
            log_message "ERROR" "Failed to restore Chrome settings from $backup_dir"
            echo -e "${RED}✗ Failed to restore Chrome settings${NC}"
            return 1
        fi
    fi
    
    return 0
}

# Function to configure security settings
configure_security_settings() {
    log_message "INFO" "Configuring security settings..."
    echo -e "\n${BLUE}Configuring Security Settings...${NC}"
    
    # Define settings with their types, values, and descriptions using regular arrays
    # Format: "key|type|value|description"
    local settings=(
        "SafeBrowsingProtectionLevel|int|0|Standard protection level"
        "DownloadRestrictions|int|1|Allow downloads with warnings"
        "SitePerProcess|int|1|Keep site isolation enabled"
        "BlockExternalExtensions|int|1|Block external extensions"
        "BlockThirdPartyCookies|int|0|Allow third-party cookies"
        "AutofillCreditCardEnabled|int|0|Disable credit card autofill"
        "DefaultGeolocationSetting|int|2|Ask for location permission"
        "PasswordManagerEnabled|int|1|Enable password manager"
        "AutofillAddressEnabled|int|0|Disable address autofill"
        "BackgroundModeEnabled|int|0|Disable background apps"
        "DiskCacheSize|int|250609664|250MB cache size"
        "TranslateEnabled|int|1|Enable translate feature"
        "CloudPrintSubmitEnabled|int|0|Disable cloud print"
        "DeviceMetricsReportingEnabled|int|0|Disable device metrics"
        "AlternateErrorPagesEnabled|int|0|Disable Google-hosted error pages"
    )
    
    local success_count=0
    local total_settings=${#settings[@]}
    
    for setting in "${settings[@]}"; do
        # Parse the setting string
        local key=$(echo "$setting" | cut -d'|' -f1)
        local type=$(echo "$setting" | cut -d'|' -f2)
        local value=$(echo "$setting" | cut -d'|' -f3)
        local description=$(echo "$setting" | cut -d'|' -f4)
        
        echo -e "${YELLOW}Setting $key: $description...${NC}"
        
        if [ "$DRY_RUN" = true ]; then
            echo -e "${YELLOW}DRY RUN: Would set $key to $value ($type)${NC}"
            log_message "INFO" "DRY RUN: Would set $key to $value"
            ((success_count++))
        else
            case "$type" in
                int)
                    if defaults write com.google.Chrome "$key" -int "$value" 2>/dev/null; then
                        log_message "SUCCESS" "Set $key to $value ($description)"
                        ((success_count++))
                        echo -e "${GREEN}✓ Successfully set $key${NC}"
                    else
                        log_message "WARNING" "Failed to set $key to $value"
                        echo -e "${RED}✗ Failed to set $key${NC}"
                    fi
                    ;;
                bool)
                    if defaults write com.google.Chrome "$key" -bool "$value" 2>/dev/null; then
                        log_message "SUCCESS" "Set $key to $value ($description)"
                        ((success_count++))
                        echo -e "${GREEN}✓ Successfully set $key${NC}"
                    else
                        log_message "WARNING" "Failed to set $key to $value"
                        echo -e "${RED}✗ Failed to set $key${NC}"
                    fi
                    ;;
                string)
                    if defaults write com.google.Chrome "$key" -string "$value" 2>/dev/null; then
                        log_message "SUCCESS" "Set $key to $value ($description)"
                        ((success_count++))
                        echo -e "${GREEN}✓ Successfully set $key${NC}"
                    else
                        log_message "WARNING" "Failed to set $key to $value"
                        echo -e "${RED}✗ Failed to set $key${NC}"
                    fi
                    ;;
                *)
                    log_message "ERROR" "Unknown type $type for setting $key"
                    echo -e "${RED}✗ Unknown type for $key${NC}"
                    ;;
            esac
        fi
    done
    
    echo -e "\n${GREEN}Successfully configured $success_count out of $total_settings settings${NC}"
}

# Function to set Chrome as default browser
set_chrome_default() {
    log_message "INFO" "Setting Chrome as default browser..."
    echo -e "\n${BLUE}Setting Chrome as Default Browser...${NC}"
    
    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}DRY RUN: Would set Chrome as default browser${NC}"
        log_message "INFO" "DRY RUN: Would set Chrome as default browser"
    else
        open -a "Google Chrome" --args --make-default-browser
        log_message "SUCCESS" "Chrome default browser setup initiated"
        echo -e "${YELLOW}Note: You may need to confirm this change in System Settings${NC}"
    fi
}

# Function to verify settings
verify_settings() {
    log_message "INFO" "Verifying settings..."
    echo -e "\n${BLUE}Verifying Settings...${NC}"
    
    local critical_settings=(
        "SafeBrowsingProtectionLevel"
        "DownloadRestrictions"
        "BlockThirdPartyCookies"
        "SitePerProcess"
    )
    
    local verification_failed=0
    
    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}DRY RUN: Would verify critical settings${NC}"
        log_message "INFO" "DRY RUN: Would verify critical settings"
        return 0
    fi
    
    for setting in "${critical_settings[@]}"; do
        local value=$(defaults read com.google.Chrome "$setting" 2>/dev/null)
        if [[ -n "$value" ]]; then
            echo -e "${GREEN}✓ Verified $setting = $value${NC}"
            log_message "SUCCESS" "Verified $setting = $value"
        else
            echo -e "${RED}✗ Failed to verify $setting${NC}"
            log_message "WARNING" "Failed to verify $setting"
            ((verification_failed++))
        fi
    done
    
    if [ $verification_failed -eq 0 ]; then
        log_message "SUCCESS" "All critical settings verified"
        echo -e "\n${GREEN}✓ All settings verified successfully${NC}"
        return 0
    else
        log_message "WARNING" "Some settings could not be verified"
        echo -e "\n${RED}✗ $verification_failed settings failed verification${NC}"
        return 1
    fi
}

# Function to display security recommendations
display_recommendations() {
    echo -e "\n${BLUE}=== Security Recommendations ===${NC}"
    echo -e "${YELLOW}1. Keep Chrome updated at all times${NC}"
    echo -e "${YELLOW}2. Use a password manager for secure credential storage${NC}"
    echo -e "${YELLOW}3. Enable two-factor authentication for your Google account${NC}"
    echo -e "${YELLOW}4. Review installed extensions regularly and remove unused ones${NC}"
    echo -e "${YELLOW}5. Consider using uBlock Origin for ad blocking${NC}"
    echo -e "${YELLOW}6. Regularly clear browsing data (especially on public networks)${NC}"
    echo -e "${YELLOW}7. Check chrome://settings/security regularly for additional options${NC}"
    echo -e "${YELLOW}8. Consider using a VPN when on public Wi-Fi networks${NC}"
    
    log_message "INFO" "Displayed security recommendations"
}

# Function to display summary
display_summary() {
    echo -e "\n${BLUE}=== Configuration Summary ===${NC}"
    echo -e "Log file: ${YELLOW}$LOG_FILE${NC}"
    
    if [ "$DRY_RUN" = false ]; then
        echo -e "Backup directory: ${YELLOW}$BACKUP_DIR${NC}"
    fi
    
    if [ -f "$LOG_FILE" ]; then
        echo -e "\n${YELLOW}Warnings and Errors:${NC}"
        grep -E "WARNING|ERROR" "$LOG_FILE" || echo "No warnings or errors found"
    fi
    
    if [ "$DRY_RUN" = false ]; then
        echo -e "\n${YELLOW}Next Steps:${NC}"
        echo "1. Restart Chrome to apply all changes"
        echo "2. Visit chrome://settings/security to verify settings"
        echo "3. Test access to previously blocked websites"
        echo -e "\n${YELLOW}To restore previous settings:${NC}"
        echo "$ $0 --restore $BACKUP_DIR"
    else
        echo -e "\n${YELLOW}To apply these changes, run without --dry-run:${NC}"
        echo "$ $0"
    fi
}

# Main execution
main() {
    # Process command line arguments
    case "$1" in
        --help|-h)
            show_help
            exit 0
            ;;
        --dry-run)
            DRY_RUN=true
            ;;
        --restore)
            if [ -n "$2" ]; then
                setup_environment
                restore_settings "$2"
                exit $?
            else
                echo -e "${YELLOW}Available backups:${NC}"
                list_backups
                echo -e "\n${YELLOW}To restore a backup:${NC}"
                echo "$ $0 --restore [backup_directory]"
                exit 0
            fi
            ;;
        --list-backups)
            list_backups
            exit 0
            ;;
    esac
    
    echo -e "${BLUE}=== Chrome Security Configuration ===${NC}"
    
    check_macos
    setup_environment || exit 1
    check_chrome || exit 1
    
    backup_settings
    configure_security_settings
    
    if [ "$DRY_RUN" = false ]; then
        set_chrome_default
        verify_settings
    fi
    
    display_recommendations
    display_summary
    
    if [ "$DRY_RUN" = false ]; then
        log_message "SUCCESS" "Chrome security configuration completed"
        echo -e "\n${GREEN}Configuration complete. Please restart Chrome for all settings to take effect.${NC}"
    else
        log_message "INFO" "Dry run completed - no changes were made"
        echo -e "\n${YELLOW}Dry run completed - no changes were made.${NC}"
    fi
}

# Execute main function with all arguments
main "$@"