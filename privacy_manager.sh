#!/bin/bash

# Name: privacy_manager.sh
# Description: Manages and audits privacy settings and app permissions on macOS
# 
# Features:
# - Camera/Microphone permissions audit
# - Location services audit
# - App permissions review
# - Privacy settings management
# - Browser privacy settings check
# - Privacy recommendations
# - Detailed privacy report
#
# Usage:
#   chmod +x privacy_manager.sh
#   ./privacy_manager.sh
#   ./privacy_manager.sh --audit-only
#   ./privacy_manager.sh --report
#
# Requirements:
# - macOS (tested on Sonoma 14.0+)
# - Full Disk Access for Terminal
# - Admin privileges for some features
#
# Version: 1.0
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
LOG_FILE="$LOG_DIR/privacy_audit_$TIMESTAMP.log"
REPORT_FILE="$HOME/Desktop/privacy_report_$TIMESTAMP.txt"

# TCC database paths
USER_TCC_DB="$HOME/Library/Application Support/com.apple.TCC/TCC.db"
SYSTEM_TCC_DB="/Library/Application Support/com.apple.TCC/TCC.db"

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
    log_message "INFO" "Starting privacy audit..."
}

# Function to check system requirements
check_requirements() {
    log_message "INFO" "Checking system requirements..."
    echo -e "\n${BLUE}Checking System Requirements...${NC}"
    
    # Check for Full Disk Access
    if ! sqlite3 "$SYSTEM_TCC_DB" ".tables" &>/dev/null; then
        echo -e "${YELLOW}Terminal needs Full Disk Access:${NC}"
        echo "1. Open System Settings > Privacy & Security > Full Disk Access"
        echo "2. Add Terminal to the allowed applications"
        exit 1
    fi
    
    # Check for required commands
    local required_commands=("sqlite3" "tccutil" "defaults")
    for cmd in "${required_commands[@]}"; do
        if ! command -v $cmd &>/dev/null; then
            handle_error "Required command not found: $cmd"
            exit 1
        fi
    done
    
    log_message "SUCCESS" "System requirements verified"
    echo -e "${GREEN}✓ System requirements met${NC}"
}

# Function to audit camera permissions
audit_camera() {
    log_message "INFO" "Auditing camera permissions..."
    echo -e "\n${BLUE}Auditing Camera Permissions...${NC}"
    
    # Query TCC database for camera access
    echo -e "${CYAN}Applications with camera access:${NC}"
    sqlite3 "$SYSTEM_TCC_DB" \
        "SELECT client, auth_value FROM access WHERE service LIKE '%camera%'" 2>/dev/null | \
        while IFS='|' read -r app status; do
            if [ "$status" -eq 1 ]; then
                echo -e "${GREEN}✓ $app${NC}"
            else
                echo -e "${RED}✗ $app${NC}"
            fi
        done
}

# Function to audit microphone permissions
audit_microphone() {
    log_message "INFO" "Auditing microphone permissions..."
    echo -e "\n${BLUE}Auditing Microphone Permissions...${NC}"
    
    # Query TCC database for microphone access
    echo -e "${CYAN}Applications with microphone access:${NC}"
    sqlite3 "$SYSTEM_TCC_DB" \
        "SELECT client, auth_value FROM access WHERE service LIKE '%microphone%'" 2>/dev/null | \
        while IFS='|' read -r app status; do
            if [ "$status" -eq 1 ]; then
                echo -e "${GREEN}✓ $app${NC}"
            else
                echo -e "${RED}✗ $app${NC}"
            fi
        done
}

# Function to audit location services
audit_location() {
    log_message "INFO" "Auditing location services..."
    echo -e "\n${BLUE}Auditing Location Services...${NC}"
    
    # Check if location services are enabled
    if defaults read /var/db/locationd/Library/Preferences/ByHost/com.apple.locationd LocationServicesEnabled 2>/dev/null | grep -q "1"; then
        echo -e "${GREEN}✓ Location Services are enabled${NC}"
        
        # List apps with location access
        echo -e "\n${CYAN}Applications with location access:${NC}"
        sqlite3 "$SYSTEM_TCC_DB" \
            "SELECT client, auth_value FROM access WHERE service LIKE '%location%'" 2>/dev/null | \
            while IFS='|' read -r app status; do
                if [ "$status" -eq 1 ]; then
                    echo -e "${GREEN}✓ $app${NC}"
                else
                    echo -e "${RED}✗ $app${NC}"
                fi
            done
    else
        echo -e "${YELLOW}! Location Services are disabled${NC}"
    fi
}

# Function to audit contacts access
audit_contacts() {
    log_message "INFO" "Auditing contacts access..."
    echo -e "\n${BLUE}Auditing Contacts Access...${NC}"
    
    echo -e "${CYAN}Applications with contacts access:${NC}"
    sqlite3 "$SYSTEM_TCC_DB" \
        "SELECT client, auth_value FROM access WHERE service LIKE '%addressbook%'" 2>/dev/null | \
        while IFS='|' read -r app status; do
            if [ "$status" -eq 1 ]; then
                echo -e "${GREEN}✓ $app${NC}"
            else
                echo -e "${RED}✗ $app${NC}"
            fi
        done
}

# Function to audit calendar access
audit_calendar() {
    log_message "INFO" "Auditing calendar access..."
    echo -e "\n${BLUE}Auditing Calendar Access...${NC}"
    
    echo -e "${CYAN}Applications with calendar access:${NC}"
    sqlite3 "$SYSTEM_TCC_DB" \
        "SELECT client, auth_value FROM access WHERE service LIKE '%calendar%'" 2>/dev/null | \
        while IFS='|' read -r app status; do
            if [ "$status" -eq 1 ]; then
                echo -e "${GREEN}✓ $app${NC}"
            else
                echo -e "${RED}✗ $app${NC}"
            fi
        done
}

# Function to check browser privacy settings
check_browser_privacy() {
    log_message "INFO" "Checking browser privacy settings..."
    echo -e "\n${BLUE}Checking Browser Privacy Settings...${NC}"
    
    # Check Chrome settings
    if [ -d "/Applications/Google Chrome.app" ]; then
        echo -e "\n${CYAN}Chrome Privacy Settings:${NC}"
        defaults read com.google.Chrome 2>/dev/null | grep -i "privacy\|tracking\|safe" || \
            echo "No custom privacy settings found"
    fi
    
    # Check Safari settings
    echo -e "\n${CYAN}Safari Privacy Settings:${NC}"
    defaults read com.apple.Safari 2>/dev/null | grep -i "privacy\|tracking\|safe" || \
        echo "No custom privacy settings found"
}

# Function to review app permissions
review_app_permissions() {
    log_message "INFO" "Reviewing app permissions..."
    echo -e "\n${BLUE}Reviewing App Permissions...${NC}"
    
    local services=(
        "camera"
        "microphone"
        "location"
        "addressbook"
        "calendar"
        "photos"
        "reminders"
    )
    
    for service in "${services[@]}"; do
        echo -e "\n${CYAN}Apps with $service access:${NC}"
        sqlite3 "$SYSTEM_TCC_DB" \
            "SELECT client, auth_value FROM access WHERE service LIKE '%$service%'" 2>/dev/null | \
            while IFS='|' read -r app status; do
                if [ "$status" -eq 1 ]; then
                    echo -e "${GREEN}✓ $app${NC}"
                else
                    echo -e "${RED}✗ $app${NC}"
                fi
            done
    done
}

# Function to generate privacy report
generate_report() {
    log_message "INFO" "Generating privacy report..."
    echo -e "\n${BLUE}Generating Privacy Report...${NC}"
    
    {
        echo "macOS Privacy Audit Report"
        echo "Generated: $(date)"
        echo "----------------------------------------"
        
        echo -e "\nCamera Permissions:"
        sqlite3 "$SYSTEM_TCC_DB" \
            "SELECT client, auth_value FROM access WHERE service LIKE '%camera%'" 2>/dev/null
        
        echo -e "\nMicrophone Permissions:"
        sqlite3 "$SYSTEM_TCC_DB" \
            "SELECT client, auth_value FROM access WHERE service LIKE '%microphone%'" 2>/dev/null
        
        echo -e "\nLocation Services:"
        sqlite3 "$SYSTEM_TCC_DB" \
            "SELECT client, auth_value FROM access WHERE service LIKE '%location%'" 2>/dev/null
        
        echo -e "\nContacts Access:"
        sqlite3 "$SYSTEM_TCC_DB" \
            "SELECT client, auth_value FROM access WHERE service LIKE '%addressbook%'" 2>/dev/null
        
        echo -e "\nCalendar Access:"
        sqlite3 "$SYSTEM_TCC_DB" \
            "SELECT client, auth_value FROM access WHERE service LIKE '%calendar%'" 2>/dev/null
        
    } > "$REPORT_FILE"
    
    echo -e "${GREEN}✓ Report generated: $REPORT_FILE${NC}"
}

# Function to provide privacy recommendations
provide_recommendations() {
    echo -e "\n${BLUE}Privacy Recommendations:${NC}"
    
    local recommendations=()
    
    # Check Location Services
    if ! defaults read /var/db/locationd/Library/Preferences/ByHost/com.apple.locationd LocationServicesEnabled 2>/dev/null | grep -q "1"; then
        recommendations+=("Consider enabling Location Services for necessary apps only")
    fi
    
    # Check Camera permissions
    if sqlite3 "$SYSTEM_TCC_DB" "SELECT COUNT(*) FROM access WHERE service LIKE '%camera%' AND auth_value=1" 2>/dev/null | grep -q "[1-9]"; then
        recommendations+=("Review camera permissions and disable for unnecessary apps")
    fi
    
    # Check Microphone permissions
    if sqlite3 "$SYSTEM_TCC_DB" "SELECT COUNT(*) FROM access WHERE service LIKE '%microphone%' AND auth_value=1" 2>/dev/null | grep -q "[1-9]"; then
        recommendations+=("Review microphone permissions and disable for unnecessary apps")
    fi
    
    # Display recommendations
    if [ ${#recommendations[@]} -eq 0 ]; then
        echo -e "${GREEN}✓ No immediate privacy concerns found${NC}"
    else
        for i in "${!recommendations[@]}"; do
            echo -e "${YELLOW}$((i+1)). ${recommendations[$i]}${NC}"
        done
    fi
}

# Function to display summary
display_summary() {
    echo -e "\n${BLUE}=== Privacy Audit Summary ===${NC}"
    echo -e "Log file: ${YELLOW}$LOG_FILE${NC}"
    
    if [ -f "$LOG_FILE" ]; then
        echo -e "\n${YELLOW}Warnings and Errors:${NC}"
        grep -E "WARNING|ERROR" "$LOG_FILE" || echo "No warnings or errors found"
    fi
    
    echo -e "\n${YELLOW}Next Steps:${NC}"
    echo "1. Review the generated privacy report"
    echo "2. Address any privacy recommendations"
    echo "3. Regularly audit app permissions"
    echo "4. Consider disabling permissions for unused apps"
}

# Main execution
main() {
    echo -e "${BLUE}=== macOS Privacy Audit ===${NC}"
    
    setup_logging
    check_requirements || exit 1
    
    case "$1" in
        --audit-only)
            audit_camera
            audit_microphone
            audit_location
            audit_contacts
            audit_calendar
            ;;
        --report)
            generate_report
            ;;
        *)
            audit_camera
            audit_microphone
            audit_location
            audit_contacts
            audit_calendar
            check_browser_privacy
            review_app_permissions
            generate_report
            provide_recommendations
            ;;
    esac
    
    display_summary
    
    log_message "SUCCESS" "Privacy audit completed"
    echo -e "\n${GREEN}Privacy audit completed successfully${NC}"
}

# Execute main function with all arguments
main "$@"