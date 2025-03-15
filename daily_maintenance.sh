#!/bin/bash

# Name: daily_maintenance.sh
# Description: Daily system maintenance and security checks for macOS
# 
# Features:
# - System cache cleaning
# - Old downloads cleanup
# - Software updates
# - Security audits
# - Backup verification
# - Disk space monitoring
# - Notification capabilities
#
# Usage:
#   chmod +x daily_maintenance.sh
#   ./daily_maintenance.sh
#   ./daily_maintenance.sh --quiet    # Run without terminal output
#   ./daily_maintenance.sh --notify   # Send notifications for warnings
#   ./daily_maintenance.sh --no-sudo  # Run without sudo operations
#
# Schedule: 
#   Run daily at 3 AM using crontab:
#   0 3 * * * /path/to/daily_maintenance.sh --quiet --notify
#
# Requirements:
# - macOS (tested on Sonoma 14.0+)
# - Homebrew (optional)
# - bc command
#
# Version: 1.2
# License: MIT

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
LOG_DIR="$HOME/.logs/maintenance"
LOG_FILE="$LOG_DIR/daily_maintenance_$(date +%Y%m%d).log"
QUIET_MODE=false
NOTIFY_MODE=false
NO_SUDO_MODE=false
DISK_SPACE_THRESHOLD=20 # GB
DOWNLOADS_AGE=30 # days
CACHE_CLEAN_EXCLUDE=("CrashPlan" "Adobe" "Microsoft" "Google" "Dropbox" "Firefox" "Slack" "Spotify")

# Process command line arguments
for arg in "$@"; do
    case "$arg" in
        --quiet)
            QUIET_MODE=true
            ;;
        --notify)
            NOTIFY_MODE=true
            ;;
        --no-sudo)
            NO_SUDO_MODE=true
            ;;
        --help)
            echo -e "${BLUE}=== Daily Maintenance Script ===${NC}"
            echo ""
            echo -e "${YELLOW}Usage:${NC}"
            echo "  ./daily_maintenance.sh             - Run maintenance with terminal output"
            echo "  ./daily_maintenance.sh --quiet     - Run without terminal output"
            echo "  ./daily_maintenance.sh --notify    - Send notifications for warnings"
            echo "  ./daily_maintenance.sh --no-sudo   - Run without sudo operations"
            echo "  ./daily_maintenance.sh --help      - Show this help message"
            echo ""
            echo -e "${YELLOW}Log File:${NC}"
            echo "  $LOG_FILE"
            exit 0
            ;;
    esac
done

# Create log directory if it doesn't exist
mkdir -p "$LOG_DIR"

# Function to log messages
log_message() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Write to log file
    echo "${timestamp}: [${level}] ${message}" >> "$LOG_FILE"
    
    # Output to terminal if not in quiet mode
    if [ "$QUIET_MODE" = false ]; then
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
    
    # Send notification if in notify mode and level is WARNING or ERROR
    if [ "$NOTIFY_MODE" = true ] && [ "$level" = "WARNING" -o "$level" = "ERROR" ]; then
        osascript -e "display notification \"${message}\" with title \"Maintenance ${level}\""
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
    log_message "INFO" "Running on macOS $(sw_vers -productVersion)"
}

# Function to check if we have sudo access without prompting for password
check_sudo_access() {
    if [ "$NO_SUDO_MODE" = true ]; then
        log_message "INFO" "Running in no-sudo mode, skipping sudo check"
        return 1
    fi
    
    # Try to get sudo timestamp without actually running a command
    if sudo -n true 2>/dev/null; then
        log_message "SUCCESS" "Sudo access available"
        return 0
    else
        log_message "INFO" "Sudo access requires password"
        echo -e "${YELLOW}! Some operations require sudo access. You may be prompted for your password.${NC}"
        # We don't return 1 here because we want to try sudo operations
        return 0
    fi
}

# Function to safely clean caches
clean_caches() {
    log_message "PROCESS" "Cleaning system caches..."
    
    # System caches that are safe to clean
    local system_cache_dirs=(
        "$HOME/Library/Caches"
    )
    
    # System caches that require sudo
    local sudo_cache_dirs=(
        "/Library/Caches"
    )
    
    # Process user caches first (no sudo required)
    for dir in "${system_cache_dirs[@]}"; do
        if [ -d "$dir" ]; then
            # Get list of directories to clean
            local cache_dirs=$(find "$dir" -type d -depth 1 2>/dev/null)
            
            for cache in $cache_dirs; do
                # Check if directory should be excluded
                local should_exclude=false
                for exclude in "${CACHE_CLEAN_EXCLUDE[@]}"; do
                    if [[ "$(basename "$cache")" == *"$exclude"* ]]; then
                        should_exclude=true
                        break
                    fi
                done
                
                if [ "$should_exclude" = false ]; then
                    # Clean the cache directory
                    if rm -rf "$cache"/* 2>/dev/null; then
                        log_message "SUCCESS" "Cleaned cache: $cache"
                    else
                        log_message "WARNING" "Failed to clean cache: $cache"
                    fi
                else
                    log_message "INFO" "Skipped excluded cache: $cache"
                fi
            done
        fi
    done
    
    # Process system caches (sudo required)
    if [ "$NO_SUDO_MODE" = false ]; then
        for dir in "${sudo_cache_dirs[@]}"; do
            if [ -d "$dir" ]; then
                # Get list of directories to clean
                local cache_dirs=$(find "$dir" -type d -depth 1 2>/dev/null)
                
                for cache in $cache_dirs; do
                    # Check if directory should be excluded
                    local should_exclude=false
                    for exclude in "${CACHE_CLEAN_EXCLUDE[@]}"; do
                        if [[ "$(basename "$cache")" == *"$exclude"* ]]; then
                            should_exclude=true
                            break
                        fi
                    done
                    
                    if [ "$should_exclude" = false ]; then
                        # Clean the cache directory
                        if sudo rm -rf "$cache"/* 2>/dev/null; then
                            log_message "SUCCESS" "Cleaned cache: $cache"
                        else
                            log_message "WARNING" "Failed to clean cache: $cache"
                        fi
                    else
                        log_message "INFO" "Skipped excluded cache: $cache"
                    fi
                done
            fi
        done
    else
        log_message "INFO" "Skipping system caches that require sudo"
    fi
}

# Function to clean old downloads
clean_downloads() {
    log_message "INFO" "Cleaning downloads older than $DOWNLOADS_AGE days"
    
    local downloads_dir="$HOME/Downloads"
    if [ -d "$downloads_dir" ]; then
        # Count files to be deleted - with better error handling
        local files_count=$(find "$downloads_dir" -mtime +$DOWNLOADS_AGE -type f 2>/dev/null | wc -l | tr -d ' ')
        
        if [ "$files_count" -gt 0 ]; then
            # Create a list of files to be deleted
            local files_list=$(mktemp)
            find "$downloads_dir" -mtime +$DOWNLOADS_AGE -type f -print 2>/dev/null > "$files_list"
            
            # Delete the files
            if xargs rm -f < "$files_list" 2>/dev/null; then
                log_message "SUCCESS" "Removed $files_count old files from Downloads"
            else
                log_message "WARNING" "Failed to remove some old files from Downloads"
            fi
            
            # Clean up temp file
            rm -f "$files_list"
        else
            log_message "INFO" "No old files found in Downloads"
        fi
    else
        log_message "WARNING" "Downloads directory not found"
    fi
}

# Function to update software
update_software() {
    # Update Homebrew and packages
    if command -v brew &>/dev/null; then
        log_message "INFO" "Updating Homebrew packages"
        
        # Update Homebrew itself
        if brew update &>/dev/null; then
            log_message "SUCCESS" "Homebrew updated"
        else
            log_message "WARNING" "Failed to update Homebrew"
        fi
        
        # Upgrade outdated packages
        local outdated=$(brew outdated --quiet)
        if [ -n "$outdated" ]; then
            if brew upgrade &>/dev/null; then
                log_message "SUCCESS" "Homebrew packages upgraded"
            else
                log_message "WARNING" "Failed to upgrade some Homebrew packages"
            fi
        else
            log_message "INFO" "No Homebrew packages need upgrading"
        fi
        
        # Clean up old versions
        if brew cleanup --prune=7 &>/dev/null; then
            log_message "SUCCESS" "Homebrew cleanup completed"
        else
            log_message "WARNING" "Homebrew cleanup failed"
        fi
    else
        log_message "INFO" "Homebrew not installed, skipping package updates"
    fi
    
    # Check for macOS updates
    log_message "INFO" "Checking for macOS updates"
    local updates=$(softwareupdate -l 2>&1)
    
    if [[ "$updates" == *"No new software available"* ]]; then
        log_message "INFO" "macOS is up to date"
    else
        local update_count=$(echo "$updates" | grep -c "Label:")
        if [ "$update_count" -gt 0 ]; then
            log_message "WARNING" "$update_count macOS updates available"
            if [ "$NOTIFY_MODE" = true ]; then
                osascript -e "display notification \"$update_count updates available\" with title \"macOS Updates\""
            fi
        fi
    fi
}

# Function to run security checks
run_security_checks() {
    log_message "INFO" "Running security checks"
    local warnings=0
    
    # Check firewall status - multiple methods to handle different macOS versions
    local firewall_status="Unknown"
    
    # Method 1: Using defaults command
    if [ "$NO_SUDO_MODE" = false ]; then
        firewall_status=$(sudo defaults read /Library/Preferences/com.apple.alf globalstate 2>/dev/null || echo "Unknown")
    fi
    
    # Method 2: Using system_profiler if Method 1 failed
    if [ "$firewall_status" = "Unknown" ]; then
        if system_profiler SPFirewallDataType 2>/dev/null | grep -q "Firewall Settings: On"; then
            firewall_status="1"
        elif system_profiler SPFirewallDataType 2>/dev/null | grep -q "Firewall Settings: Off"; then
            firewall_status="0"
        fi
    fi
    
    # Method 3: Using socketfilterfw command
    if [ "$firewall_status" = "Unknown" ] && [ "$NO_SUDO_MODE" = false ]; then
        if sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate 2>/dev/null | grep -q "enabled"; then
            firewall_status="1"
        elif sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate 2>/dev/null | grep -q "disabled"; then
            firewall_status="0"
        fi
    fi
    
    if [ "$firewall_status" = "0" ]; then
        log_message "WARNING" "Firewall is disabled"
        ((warnings++))
    elif [ "$firewall_status" = "Unknown" ]; then
        log_message "WARNING" "Could not determine firewall status"
        ((warnings++))
    else
        log_message "SUCCESS" "Firewall is enabled"
    fi
    
    # Check SIP status
    if ! csrutil status 2>/dev/null | grep -q "enabled"; then
        log_message "WARNING" "System Integrity Protection is disabled"
        ((warnings++))
    else
        log_message "SUCCESS" "System Integrity Protection is enabled"
    fi
    
    # Check FileVault status
    if ! fdesetup status 2>/dev/null | grep -q "FileVault is On"; then
        log_message "WARNING" "FileVault is not enabled"
        ((warnings++))
    else
        log_message "SUCCESS" "FileVault is enabled"
    fi
    
    # Check for software updates
    if softwareupdate -l 2>&1 | grep -q "recommended"; then
        log_message "WARNING" "Software updates are available"
        ((warnings++))
    fi
    
    # Check for automatic updates
    local auto_update=$(defaults read /Library/Preferences/com.apple.SoftwareUpdate AutomaticCheckEnabled 2>/dev/null || echo "Unknown")
    if [ "$auto_update" = "0" ]; then
        log_message "WARNING" "Automatic software updates are disabled"
        ((warnings++))
    fi
    
    # Check for Gatekeeper
    if ! spctl --status 2>/dev/null | grep -q "enabled"; then
        log_message "WARNING" "Gatekeeper is disabled"
        ((warnings++))
    else
        log_message "SUCCESS" "Gatekeeper is enabled"
    fi
    
    # Check for root user - with more context
    if dscl . -read /Users/root AuthenticationAuthority &>/dev/null; then
        log_message "WARNING" "Root user is enabled (this is a security risk unless specifically needed)"
        log_message "INFO" "To disable root user: sudo dsenableroot -d"
        ((warnings++))
    else
        log_message "SUCCESS" "Root user is disabled"
    fi
    
    # Check for guest user
    if defaults read /Library/Preferences/com.apple.loginwindow GuestEnabled 2>/dev/null | grep -q "1"; then
        log_message "WARNING" "Guest user account is enabled"
        ((warnings++))
    else
        log_message "SUCCESS" "Guest user account is disabled"
    fi
    
    # Check for automatic login
    if defaults read /Library/Preferences/com.apple.loginwindow autoLoginUser 2>/dev/null | grep -q "."; then
        log_message "WARNING" "Automatic login is enabled"
        ((warnings++))
    else
        log_message "SUCCESS" "Automatic login is disabled"
    fi
    
    # Summary
    if [ "$warnings" -eq 0 ]; then
        log_message "SUCCESS" "All security checks passed"
    else
        log_message "WARNING" "$warnings security issues found"
    fi
}

# Function to verify backup status
verify_backup() {
    log_message "INFO" "Verifying backup status"
    
    # Check Time Machine
    if ! tmutil status &>/dev/null; then
        log_message "WARNING" "Time Machine not configured"
        log_message "INFO" "Consider setting up Time Machine for automatic backups"
    else
        local last_backup=$(tmutil latestbackup 2>/dev/null)
        if [ -z "$last_backup" ]; then
            log_message "WARNING" "No Time Machine backups found"
            log_message "INFO" "Make sure your backup disk is connected and Time Machine is properly configured"
        else
            local backup_date=$(stat -f "%Sm" -t "%Y-%m-%d" "$last_backup" 2>/dev/null)
            local today=$(date +%Y-%m-%d)
            local yesterday=$(date -v-1d +%Y-%m-%d)
            
            if [ "$backup_date" = "$today" ]; then
                log_message "SUCCESS" "Time Machine backup completed today"
            elif [ "$backup_date" = "$yesterday" ]; then
                log_message "INFO" "Last Time Machine backup was yesterday"
            else
                log_message "WARNING" "Last Time Machine backup was on $backup_date (more than a day ago)"
            fi
        fi
    fi
    
    # Check for other backup solutions
    if [ -d "$HOME/Library/Mobile Documents/com~apple~CloudDocs" ]; then
        log_message "INFO" "iCloud Drive is configured"
    fi
}

# Function to check disk space
check_disk_space() {
    log_message "INFO" "Checking disk space"
    
    # Get available space
    local available_space=$(df -h / | awk 'NR==2 {print $4}' | sed 's/Gi//')
    
    # Check if it's a number
    if [[ "$available_space" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
        log_message "INFO" "Available disk space: ${available_space}GB"
        
        # Check if space is below threshold
        if (( $(echo "$available_space < $DISK_SPACE_THRESHOLD" | bc -l) )); then
            log_message "WARNING" "Low disk space: ${available_space}GB available (threshold: ${DISK_SPACE_THRESHOLD}GB)"
            
            # List largest directories
            log_message "INFO" "Largest directories in home folder:"
            du -h -d 1 $HOME | sort -hr | head -n 5 >> "$LOG_FILE"
            
            # Suggest cleanup options
            log_message "INFO" "Consider running: brew cleanup --prune=all"
            log_message "INFO" "Consider emptying trash: rm -rf ~/.Trash/*"
            log_message "INFO" "Consider clearing system logs: sudo rm -rf /var/log/*"
        else
            log_message "SUCCESS" "Disk space is adequate"
        fi
    else
        log_message "ERROR" "Could not determine available disk space"
    fi
}

# Function to check system performance
check_performance() {
    log_message "INFO" "Checking system performance"
    
    # Set a start time to limit how long this function runs
    local start_time=$(date +%s)
    local time_limit=10  # Maximum seconds to run
    
    # Check CPU load
    local load=$(sysctl -n vm.loadavg 2>/dev/null | awk '{print $2}' || echo "Unknown")
    if [ "$load" != "Unknown" ]; then
        log_message "INFO" "Current CPU load: $load"
        
        # Check if load is high
        if (( $(echo "$load > 3.0" | bc -l 2>/dev/null) )); then
            log_message "WARNING" "High CPU load detected"
        fi
    else
        log_message "WARNING" "Could not determine CPU load"
    fi
    
    # Check if we've exceeded the time limit
    if (( $(date +%s) - start_time >= time_limit )); then
        log_message "WARNING" "Performance check taking too long, skipping remaining checks"
        return
    fi
    
    # Check memory usage
    local total_mem=$(sysctl -n hw.memsize 2>/dev/null | awk '{print $1 / 1024 / 1024 / 1024}' || echo "Unknown")
    if [ "$total_mem" != "Unknown" ]; then
        local vm_stat_output=$(vm_stat 2>/dev/null)
        local used_mem=$(echo "$vm_stat_output" | grep "Pages active" | awk '{print $3}' | sed 's/\.//' || echo "Unknown")
        local page_size=$(echo "$vm_stat_output" | grep "page size" | awk '{print $8}' || echo "Unknown")
        
        if [[ "$used_mem" =~ ^[0-9]+$ ]] && [[ "$page_size" =~ ^[0-9]+$ ]]; then
            local used_mem_gb=$(echo "scale=2; $used_mem * $page_size / 1024 / 1024 / 1024" | bc 2>/dev/null || echo "Unknown")
            
            if [ "$used_mem_gb" != "Unknown" ]; then
                local mem_percent=$(echo "scale=2; $used_mem_gb / $total_mem * 100" | bc 2>/dev/null || echo "Unknown")
                
                if [ "$mem_percent" != "Unknown" ]; then
                    log_message "INFO" "Memory usage: ${used_mem_gb}GB of ${total_mem}GB (${mem_percent}%)"
                    
                    if (( $(echo "$mem_percent > 80" | bc -l 2>/dev/null) )); then
                        log_message "WARNING" "High memory usage detected"
                    fi
                else
                    log_message "WARNING" "Could not calculate memory percentage"
                fi
            else
                log_message "WARNING" "Could not calculate used memory"
            fi
        else
            log_message "WARNING" "Could not parse memory information"
        fi
    else
        log_message "WARNING" "Could not determine total memory"
    fi
    
    # Check if we've exceeded the time limit
    if (( $(date +%s) - start_time >= time_limit )); then
        log_message "WARNING" "Performance check taking too long, skipping remaining checks"
        return
    fi
    
    # Check for high CPU processes - simplified to avoid hanging
    log_message "INFO" "Top CPU-intensive processes:"
    ps -eo pcpu,pid,user,comm 2>/dev/null | sort -k 1 -r | head -5 >> "$LOG_FILE" || log_message "WARNING" "Could not get process information"
    
    # Check if we've exceeded the time limit
    if (( $(date +%s) - start_time >= time_limit )); then
        log_message "WARNING" "Performance check taking too long, skipping remaining checks"
        return
    fi
    
    # Check disk I/O - only if we have time left
    if command -v iostat &>/dev/null; then
        log_message "INFO" "Disk I/O statistics:"
        # Check if timeout command is available
        if command -v timeout &>/dev/null; then
            # Use timeout to prevent hanging
            timeout 3 iostat -d 1 1 2>/dev/null >> "$LOG_FILE" || log_message "WARNING" "Could not get disk I/O statistics"
        else
            # Fallback to a simpler command that won't hang
            iostat -d 1 1 2>/dev/null | head -n 5 >> "$LOG_FILE" || log_message "WARNING" "Could not get disk I/O statistics"
        fi
    fi
}

# Main function
main() {
    log_message "INFO" "Starting daily maintenance"
    
    # Create a trap to handle script interruption
    trap 'log_message "WARNING" "Script interrupted"; exit 1' INT TERM
    
    # Check if running on macOS
    check_macos
    
    # Check sudo access
    check_sudo_access
    
    # Run maintenance tasks
    clean_caches
    clean_downloads
    update_software
    run_security_checks
    verify_backup
    check_disk_space
    check_performance
    
    log_message "SUCCESS" "Daily maintenance completed"
    
    # Show summary if not in quiet mode
    if [ "$QUIET_MODE" = false ]; then
        echo -e "\n${GREEN}Maintenance completed. Log file: $LOG_FILE${NC}"
        
        # Show warnings and errors
        echo -e "\n${YELLOW}Warnings and Errors:${NC}"
        grep -E "\[WARNING\]|\[ERROR\]" "$LOG_FILE" | tail -n 10 || echo "No warnings or errors found"
    fi
    
    # Remove the trap
    trap - INT TERM
}

# Execute main function
main