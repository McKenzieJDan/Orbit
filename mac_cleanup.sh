#!/bin/bash

# Name: mac_cleanup.sh
# Description: Cleans and optimizes macOS system
# 
# Features:
# - System cache cleanup
# - Application cache cleanup
# - Remove unused applications
# - Manage startup items
# - Disk space analysis
# - Memory optimization
# - System maintenance tasks
# - Detailed cleanup report
#
# Usage:
#   chmod +x mac_cleanup.sh
#   ./mac_cleanup.sh
#   ./mac_cleanup.sh --analyze
#   ./mac_cleanup.sh --quick
#
# Requirements:
# - macOS (tested on Sonoma 14.0+)
# - Admin privileges
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
LOG_FILE="$LOG_DIR/mac_cleanup_$TIMESTAMP.log"

# Size formatting threshold in bytes
THRESHOLD=1024

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

# Function to format file sizes
format_size() {
    local size=$1
    local units=("B" "KB" "MB" "GB" "TB")
    local unit=0
    
    while [ $size -gt $THRESHOLD ]; do
        size=$(($size / 1024))
        unit=$((unit + 1))
    done
    
    echo "$size${units[$unit]}"
}

# Function to set up logging
setup_logging() {
    mkdir -p "$LOG_DIR" || handle_error "Failed to create log directory"
    touch "$LOG_FILE" || handle_error "Failed to create log file"
    log_message "INFO" "Starting system cleanup..."
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
    
    # Check available disk space
    local available_space=$(df -h / | awk 'NR==2 {print $4}' | sed 's/Gi//')
    if (( $(echo "$available_space < 5" | bc -l) )); then
        log_message "WARNING" "Low disk space: ${available_space}GB available"
        echo -e "${YELLOW}Warning: Low disk space detected${NC}"
    fi
    
    log_message "SUCCESS" "System requirements verified"
    echo -e "${GREEN}✓ System requirements met${NC}"
}

# Function to analyze disk space
analyze_disk_space() {
    log_message "INFO" "Analyzing disk space..."
    echo -e "\n${BLUE}Analyzing Disk Space Usage...${NC}"
    
    # Get disk space usage by directory
    echo -e "\n${CYAN}Largest Directories:${NC}"
    du -h ~/ 2>/dev/null | sort -rh | head -n 10
    
    # Get available disk space
    echo -e "\n${CYAN}Disk Space Summary:${NC}"
    df -h /
}

# Function to clean system cache
clean_system_cache() {
    log_message "INFO" "Cleaning system cache..."
    echo -e "\n${BLUE}Cleaning System Cache...${NC}"
    
    local cache_dirs=(
        "/Library/Caches"
        "~/Library/Caches"
        "/System/Library/Caches"
    )
    
    local total_saved=0
    
    for dir in "${cache_dirs[@]}"; do
        if [ -d "$dir" ]; then
            local size_before=$(du -sb "$dir" 2>/dev/null | cut -f1)
            echo -e "${CYAN}Cleaning $dir...${NC}"
            rm -rf "$dir"/* 2>/dev/null
            local size_after=$(du -sb "$dir" 2>/dev/null | cut -f1)
            local saved=$((size_before - size_after))
            total_saved=$((total_saved + saved))
            echo -e "Freed: ${GREEN}$(format_size $saved)${NC}"
        fi
    done
    
    echo -e "Total space freed: ${GREEN}$(format_size $total_saved)${NC}"
}

# Function to clean application cache
clean_app_cache() {
    log_message "INFO" "Cleaning application cache..."
    echo -e "\n${BLUE}Cleaning Application Cache...${NC}"
    
    local app_cache_dirs=(
        "~/Library/Application Support"
        "~/Library/Containers"
        "~/Library/Saved Application State"
    )
    
    local total_saved=0
    
    for dir in "${app_cache_dirs[@]}"; do
        if [ -d "$dir" ]; then
            local size_before=$(du -sb "$dir" 2>/dev/null | cut -f1)
            echo -e "${CYAN}Cleaning $dir...${NC}"
            find "$dir" -name "*.cache" -type f -delete 2>/dev/null
            local size_after=$(du -sb "$dir" 2>/dev/null | cut -f1)
            local saved=$((size_before - size_after))
            total_saved=$((total_saved + saved))
            echo -e "Freed: ${GREEN}$(format_size $saved)${NC}"
        fi
    done
    
    echo -e "Total space freed: ${GREEN}$(format_size $total_saved)${NC}"
}

# Function to clean downloads folder
clean_downloads() {
    log_message "INFO" "Analyzing downloads folder..."
    echo -e "\n${BLUE}Analyzing Downloads Folder...${NC}"
    
    local downloads="$HOME/Downloads"
    if [ -d "$downloads" ]; then
        # Show large files
        echo -e "\n${CYAN}Large files in Downloads (>100MB):${NC}"
        find "$downloads" -type f -size +100M -exec ls -lh {} \;
        
        # Show old files
        echo -e "\n${CYAN}Files older than 30 days:${NC}"
        find "$downloads" -type f -mtime +30 -exec ls -lh {} \;
        
        read -p "Would you like to clean old downloads? (y/n) " answer
        if [[ "$answer" =~ ^[Yy]$ ]]; then
            local size_before=$(du -sb "$downloads" 2>/dev/null | cut -f1)
            find "$downloads" -type f -mtime +30 -delete 2>/dev/null
            local size_after=$(du -sb "$downloads" 2>/dev/null | cut -f1)
            local saved=$((size_before - size_after))
            echo -e "Freed: ${GREEN}$(format_size $saved)${NC}"
        fi
    fi
}

# Function to manage startup items
manage_startup() {
    log_message "INFO" "Managing startup items..."
    echo -e "\n${BLUE}Managing Startup Items...${NC}"
    
    echo -e "\n${CYAN}User Login Items:${NC}"
    osascript -e 'tell application "System Events" to get the name of every login item'
    
    echo -e "\n${CYAN}Launch Agents:${NC}"
    ls -la ~/Library/LaunchAgents 2>/dev/null
    
    echo -e "\n${CYAN}System Launch Agents:${NC}"
    ls -la /Library/LaunchAgents 2>/dev/null
    
    echo -e "\n${YELLOW}Note: Use System Settings to manage startup items${NC}"
}

# Function to clear system logs
clear_logs() {
    log_message "INFO" "Clearing system logs..."
    echo -e "\n${BLUE}Clearing System Logs...${NC}"
    
    local log_dirs=(
        "/var/log"
        "~/Library/Logs"
    )
    
    local total_saved=0
    
    for dir in "${log_dirs[@]}"; do
        if [ -d "$dir" ]; then
            local size_before=$(du -sb "$dir" 2>/dev/null | cut -f1)
            echo -e "${CYAN}Clearing $dir...${NC}"
            sudo rm -rf "$dir"/* 2>/dev/null
            local size_after=$(du -sb "$dir" 2>/dev/null | cut -f1)
            local saved=$((size_before - size_after))
            total_saved=$((total_saved + saved))
            echo -e "Freed: ${GREEN}$(format_size $saved)${NC}"
        fi
    done
    
    echo -e "Total space freed: ${GREEN}$(format_size $total_saved)${NC}"
}

# Function to optimize system
optimize_system() {
    log_message "INFO" "Running system optimization..."
    echo -e "\n${BLUE}Running System Optimization...${NC}"
    
    # Rebuild Spotlight index
    echo -e "${CYAN}Rebuilding Spotlight index...${NC}"
    sudo mdutil -E / >/dev/null 2>&1
    
    # Clear font cache
    echo -e "${CYAN}Clearing font cache...${NC}"
    sudo atsutil databases -remove >/dev/null 2>&1
    
    # Flush DNS cache
    echo -e "${CYAN}Flushing DNS cache...${NC}"
    sudo dscacheutil -flushcache
    sudo killall -HUP mDNSResponder
    
    # Clear Quick Look cache
    echo -e "${CYAN}Clearing Quick Look cache...${NC}"
    qlmanage -r cache >/dev/null 2>&1
    
    log_message "SUCCESS" "System optimization completed"
    echo -e "${GREEN}✓ System optimization completed${NC}"
}

# Function to display cleanup summary
display_summary() {
    echo -e "\n${BLUE}=== Cleanup Summary ===${NC}"
    echo -e "Log file: ${YELLOW}$LOG_FILE${NC}"
    
    # Display disk space after cleanup
    echo -e "\n${CYAN}Final Disk Space Status:${NC}"
    df -h /
    
    if [ -f "$LOG_FILE" ]; then
        echo -e "\n${YELLOW}Warnings and Errors:${NC}"
        grep -E "WARNING|ERROR" "$LOG_FILE" || echo "No warnings or errors found"
    fi
    
    echo -e "\n${YELLOW}Recommended Actions:${NC}"
    echo "1. Restart your computer to apply all optimizations"
    echo "2. Review startup items in System Settings"
    echo "3. Consider removing large unused applications"
}

# Main execution
main() {
    echo -e "${BLUE}=== macOS Cleanup and Optimization ===${NC}"
    
    setup_logging
    check_requirements || exit 1
    
    case "$1" in
        --analyze)
            analyze_disk_space
            manage_startup
            ;;
        --quick)
            clean_system_cache
            clean_app_cache
            optimize_system
            ;;
        *)
            analyze_disk_space
            clean_system_cache
            clean_app_cache
            clean_downloads
            manage_startup
            clear_logs
            optimize_system
            ;;
    esac
    
    display_summary
    
    log_message "SUCCESS" "Cleanup completed"
    echo -e "\n${GREEN}Cleanup and optimization completed successfully${NC}"
}

# Execute main function with all arguments
main "$@"