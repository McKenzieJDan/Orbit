#!/bin/bash

# Name: update_macos.sh
# Description: Automates checking and installing macOS software updates
# Version: 1.2
# License: MIT

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Log setup
LOG_DIR="$HOME/.logs"
LOG_FILE="$LOG_DIR/macos_update_$(date +%Y%m%d_%H%M%S).log"

# Function to log messages
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

# Function to set up logging
setup_logging() {
    mkdir -p "$LOG_DIR" || handle_error "Failed to create log directory"
    touch "$LOG_FILE" || handle_error "Failed to create log file"
    log_message "INFO" "Starting macOS update check..."
}

# Function to check system requirements
check_requirements() {
    log_message "PROCESS" "Checking system requirements..."
    
    # Check if running as root
    if [ "$EUID" -ne 0 ]; then
        handle_error "This script must be run with sudo privileges"
        echo -e "${YELLOW}Please run: sudo $0${NC}"
        exit 1
    fi
    
    # Check internet connectivity
    if ! ping -c 1 apple.com &> /dev/null; then
        handle_error "No internet connection detected"
        exit 1
    fi
    
    # Check available disk space (minimum 20GB recommended for updates)
    local available_space
    available_space=$(df -h / | awk 'NR==2 {gsub(/[A-Za-z]/,"",$4); print $4}')
    if [[ $available_space =~ ^[0-9]+(\.[0-9]+)?$ ]] && (( $(echo "$available_space < 20" | bc -l) )); then
        log_message "WARNING" "Low disk space. Less than 20GB available"
        echo -e "${YELLOW}Warning: Low disk space detected. Updates may require more space.${NC}"
    fi
    
    log_message "SUCCESS" "System requirements verified"
}

# Function to check last update date
check_last_update() {
    log_message "INFO" "Checking last update date..."
    echo -e "\n${BLUE}Checking Last Update Date...${NC}"
    
    local last_update
    if last_update=$(defaults read /Library/Preferences/com.apple.SoftwareUpdate LastFullSuccessfulDate 2>/dev/null); then
        echo -e "Last successful update: ${GREEN}$last_update${NC}"
        log_message "INFO" "Last update: $last_update"
        
        # Calculate days since last update
        local last_update_seconds current_seconds days_since_update
        last_update_seconds=$(date -j -f "%Y-%m-%d %H:%M:%S %z" "$last_update" "+%s")
        current_seconds=$(date "+%s")
        days_since_update=$(( (current_seconds - last_update_seconds) / 86400 ))
        
        echo "Days since last update: $days_since_update"
        
        if [ $days_since_update -gt 30 ]; then
            log_message "WARNING" "System not updated for over 30 days"
            echo -e "${YELLOW}Warning: It has been more than 30 days since the last update${NC}"
        fi
    else
        log_message "WARNING" "Could not determine last update date"
        echo -e "${YELLOW}Warning: Could not determine last update date${NC}"
    fi
}

# Function to check available updates
check_updates() {
    log_message "INFO" "Checking for available updates..."
    echo -e "\n${BLUE}Checking for Available Updates...${NC}"
    
    local update_list
    if ! update_list=$(softwareupdate -l 2>&1); then
        handle_error "Failed to check for updates"
        return 1
    fi
    
    if echo "$update_list" | grep -q "No new software available"; then
        log_message "SUCCESS" "System is up to date"
        echo -e "${GREEN}✓ System is up to date${NC}"
        return 0
    else
        echo -e "\n${YELLOW}Available Updates:${NC}"
        echo "$update_list"
        log_message "INFO" "Updates available"
        UPDATE_LIST="$update_list"  # Store for use in install_updates
        return 2
    fi
}

# Function to install updates
install_updates() {
    log_message "INFO" "Starting update installation..."
    echo -e "\n${BLUE}Installing Updates...${NC}"
    
    # Check if restart is required
    if echo "$UPDATE_LIST" | grep -qi "restart"; then
        log_message "WARNING" "Updates require system restart"
        echo -e "${YELLOW}Warning: Some updates require a system restart${NC}"
        
        read -p "Do you want to proceed with installation and restart if necessary? (y/n) " -r answer
        if [[ "$answer" =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}Installing updates and preparing for restart...${NC}"
            log_message "INFO" "Installing updates with restart"
            
            if softwareupdate -i -a -R; then
                log_message "SUCCESS" "Updates installed successfully"
                echo -e "${GREEN}✓ Updates installed successfully${NC}"
                echo -e "${YELLOW}System will restart shortly...${NC}"
                return 0
            else
                handle_error "Failed to install updates"
                return 1
            fi
        else
            log_message "INFO" "Update cancelled by user"
            echo -e "${YELLOW}Update cancelled by user${NC}"
            return 0
        fi
    else
        read -p "Do you want to install available updates? (y/n) " -r answer
        if [[ "$answer" =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}Installing updates...${NC}"
            log_message "INFO" "Installing updates without restart"
            
            if softwareupdate -i -a; then
                log_message "SUCCESS" "Updates installed successfully"
                echo -e "${GREEN}✓ Updates installed successfully${NC}"
                return 0
            else
                handle_error "Failed to install updates"
                return 1
            fi
        else
            log_message "INFO" "Update cancelled by user"
            echo -e "${YELLOW}Update cancelled by user${NC}"
            return 0
        fi
    fi
}

# Function to display summary
display_summary() {
    echo -e "\n${BLUE}=== Update Summary ===${NC}"
    echo -e "Log file: ${YELLOW}$LOG_FILE${NC}"
    
    if [ -f "$LOG_FILE" ]; then
        echo -e "\n${YELLOW}Warnings and Errors:${NC}"
        grep -E "WARNING|ERROR" "$LOG_FILE" || echo "No warnings or errors found"
    fi
}

# Main execution
main() {
    echo -e "${BLUE}=== macOS Software Update ===${NC}"
    
    setup_logging || exit 1
    check_requirements || exit 1
    check_last_update
    
    local update_status
    check_updates
    update_status=$?
    
    if [ $update_status -eq 2 ]; then
        install_updates
    fi
    
    display_summary
    
    log_message "SUCCESS" "Update process completed"
    echo -e "\n${GREEN}Update process completed${NC}"
}

# Ensure script only runs once
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi