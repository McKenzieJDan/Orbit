#!/bin/bash

# Name: network_security.sh
# Description: Manages and monitors network security settings for macOS
# 
# Features:
# - Firewall configuration and verification
# - VPN connection status and security
# - Wi-Fi security audit
# - Network monitoring and logging
# - Security recommendations
#
# Usage:
#   chmod +x network_security.sh
#   ./network_security.sh
#   ./network_security.sh --audit-only
#   ./network_security.sh --configure
#
# Requirements:
# - macOS (tested on Sonoma 14.0+)
# - Admin privileges
# - NordVPN installed (optional)
#
# Version: 1.1
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
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="$LOG_DIR/network_security_$TIMESTAMP.log"

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
    log_message "INFO" "Starting network security check..."
}

# Function to check system requirements
check_requirements() {
    log_message "PROCESS" "Checking system requirements..."
    
    # Check for admin privileges
    if [ "$EUID" -ne 0 ]; then
        handle_error "Please run this script with sudo"
        exit 1
    fi
    
    # Check for required commands
    local required_commands=("networksetup" "scutil" "pfctl")
    for cmd in "${required_commands[@]}"; do
        if ! command -v $cmd &> /dev/null; then
            handle_error "Required command not found: $cmd"
            exit 1
        fi
    done
    
    log_message "SUCCESS" "System requirements verified"
}

# Function to check firewall status
check_firewall() {
    log_message "INFO" "Checking firewall status..."
    echo -e "\n${BLUE}Checking Firewall Status...${NC}"
    
    # Get firewall status
    if defaults read /Library/Preferences/com.apple.alf globalstate &>/dev/null; then
        local firewall_status=$(defaults read /Library/Preferences/com.apple.alf globalstate)
        case $firewall_status in
            0) echo -e "${RED}✗ Firewall is disabled${NC}" ;;
            1) echo -e "${GREEN}✓ Firewall is enabled (allow signed apps)${NC}" ;;
            2) echo -e "${GREEN}✓ Firewall is enabled (allow essential services only)${NC}" ;;
        esac
    else
        handle_error "Could not read firewall status"
    fi
    
    # Check stealth mode
    if defaults read /Library/Preferences/com.apple.alf stealthenabled &>/dev/null; then
        local stealth_status=$(defaults read /Library/Preferences/com.apple.alf stealthenabled)
        if [ "$stealth_status" -eq 1 ]; then
            echo -e "${GREEN}✓ Stealth mode is enabled${NC}"
        else
            echo -e "${RED}✗ Stealth mode is disabled${NC}"
        fi
    fi
}

# Function to configure firewall
configure_firewall() {
    log_message "INFO" "Configuring firewall..."
    echo -e "\n${BLUE}Configuring Firewall...${NC}"
    
    # Enable firewall
    defaults write /Library/Preferences/com.apple.alf globalstate -int 1
    
    # Enable stealth mode
    defaults write /Library/Preferences/com.apple.alf stealthenabled -int 1
    
    # Load new settings
    launchctl load /System/Library/LaunchDaemons/com.apple.alf.agent.plist 2>/dev/null
    launchctl load /System/Library/LaunchDaemons/com.apple.alf.plist 2>/dev/null
    
    log_message "SUCCESS" "Firewall configured"
    echo -e "${GREEN}✓ Firewall configured successfully${NC}"
}

# Function to check Wi-Fi security
check_wifi() {
    log_message "INFO" "Checking Wi-Fi security..."
    echo -e "\n${BLUE}Checking Wi-Fi Security...${NC}"
    
    # Get current Wi-Fi network
    local current_wifi=$(/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -I | awk '/ SSID/ {print substr($0, index($0, $2))}')
    
    if [ -n "$current_wifi" ]; then
        echo -e "Connected to: ${CYAN}$current_wifi${NC}"
        
        # Check encryption type
        local security=$(/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -I | awk '/ link auth/ {print substr($0, index($0, $3))}')
        
        case $security in
            *"wpa"*) echo -e "${GREEN}✓ Using WPA/WPA2 encryption${NC}" ;;
            *"wep"*) echo -e "${RED}✗ Using insecure WEP encryption${NC}" ;;
            *"none"*) echo -e "${RED}✗ No encryption${NC}" ;;
            *) echo -e "${YELLOW}! Unknown encryption type${NC}" ;;
        esac
    else
        echo -e "${YELLOW}! Not connected to Wi-Fi${NC}"
    fi
}

# Function to check VPN status
check_vpn() {
    log_message "INFO" "Checking VPN status..."
    echo -e "\n${BLUE}Checking VPN Status...${NC}"
    
    # Check if NordVPN is installed
    if command -v nordvpn &> /dev/null; then
        local vpn_status=$(nordvpn status)
        if echo "$vpn_status" | grep -q "Connected"; then
            echo -e "${GREEN}✓ NordVPN is connected${NC}"
            echo -e "Status: ${CYAN}$(echo "$vpn_status" | grep "Current server" | cut -d: -f2-)${NC}"
        else
            echo -e "${RED}✗ NordVPN is not connected${NC}"
        fi
    else
        echo -e "${YELLOW}! NordVPN is not installed${NC}"
    fi
    
    # Check for any active VPN connections
    if scutil --nc list | grep -q "Connected"; then
        echo -e "${GREEN}✓ System VPN is connected${NC}"
    fi
}

# Function to monitor network connections
monitor_network() {
    log_message "INFO" "Monitoring network connections..."
    echo -e "\n${BLUE}Active Network Connections:${NC}"
    
    # Show active connections
    echo -e "${CYAN}Established connections:${NC}"
    netstat -an | grep ESTABLISHED | head -n 5
    
    # Show listening ports
    echo -e "\n${CYAN}Listening ports:${NC}"
    netstat -an | grep LISTEN | head -n 5
}

# Function to display security recommendations
display_recommendations() {
    echo -e "\n${BLUE}=== Security Recommendations ===${NC}"
    
    local recommendations=()
    
    # Check firewall status
    if [ "$(defaults read /Library/Preferences/com.apple.alf globalstate)" -eq 0 ]; then
        recommendations+=("Enable the firewall for better security")
    fi
    
    # Check stealth mode
    if [ "$(defaults read /Library/Preferences/com.apple.alf stealthenabled)" -eq 0 ]; then
        recommendations+=("Enable stealth mode to prevent probe attempts")
    fi
    
    # Display recommendations
    if [ ${#recommendations[@]} -eq 0 ]; then
        echo -e "${GREEN}✓ No immediate security recommendations${NC}"
    else
        for i in "${!recommendations[@]}"; do
            echo -e "${YELLOW}$((i+1)). ${recommendations[$i]}${NC}"
        done
    fi
}

# Function to display summary
display_summary() {
    echo -e "\n${BLUE}=== Network Security Summary ===${NC}"
    echo -e "Log file: ${YELLOW}$LOG_FILE${NC}"
    
    if [ -f "$LOG_FILE" ]; then
        echo -e "\n${YELLOW}Warnings and Errors:${NC}"
        grep -E "WARNING|ERROR" "$LOG_FILE" || echo "No warnings or errors found"
    fi
}

# Main execution
main() {
    echo -e "${BLUE}=== macOS Network Security Check ===${NC}"
    
    setup_logging
    check_requirements || exit 1
    
    case "$1" in
        --audit-only)
            check_firewall
            check_wifi
            check_vpn
            monitor_network
            ;;
        --configure)
            configure_firewall
            ;;
        *)
            check_firewall
            check_wifi
            check_vpn
            monitor_network
            display_recommendations
            ;;
    esac
    
    display_summary
    
    log_message "SUCCESS" "Network security check completed"
    echo -e "\n${GREEN}Network security check completed successfully${NC}"
}

# Execute main function with all arguments
main "$@"