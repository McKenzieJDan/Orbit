#!/bin/bash

# Name: update_notifier.sh
# Description: Manages update notifications for macOS and applications
# 
# Features:
# - Checks for macOS updates
# - Checks for app updates via Homebrew
# - Sends macOS notifications
# - Configurable check intervals
# - Logs notification history
# - Can trigger update scripts
#
# Usage:
#   chmod +x update_notifier.sh
#   ./update_notifier.sh --install   # Install and schedule notifications
#   ./update_notifier.sh --uninstall # Remove scheduling
#   ./update_notifier.sh --check     # Run check immediately
#
# Requirements:
# - macOS (tested on Sonoma 14.0+)
# - Homebrew installed
# - update_macos.sh and homebrew_maintenance.sh in same directory

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Script paths and configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MACOS_UPDATE_SCRIPT="$SCRIPT_DIR/update_macos.sh"
APPS_UPDATE_SCRIPT="$SCRIPT_DIR/homebrew_maintenance.sh"
LOG_DIR="$HOME/.logs"
LOG_FILE="$LOG_DIR/update_notifier.log"
LAST_CHECK_FILE="$LOG_DIR/last_update_check"

# LaunchAgent configuration
LAUNCH_AGENT_LABEL="com.user.updatenotifier"
LAUNCH_AGENT_PLIST="$HOME/Library/LaunchAgents/${LAUNCH_AGENT_LABEL}.plist"

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

# Function to send notification
send_notification() {
    local title="$1"
    local message="$2"
    local sound="$3"
    
    osascript -e "display notification \"$message\" with title \"$title\" sound name \"$sound\""
    log_message "INFO" "Sent notification: $title - $message"
}

# Function to check for macOS updates
check_macos_updates() {
    log_message "PROCESS" "Checking for macOS updates..."
    
    local updates
    updates=$(softwareupdate -l 2>&1)
    
    if echo "$updates" | grep -q "No new software available"; then
        log_message "INFO" "No macOS updates available"
        return 1
    else
        send_notification "macOS Update Available" "New system updates are ready to install" "Submarine"
        log_message "INFO" "macOS updates found"
        
        # Ask if user wants to install updates now
        osascript <<EOD
            tell application "System Events"
                activate
                set response to display dialog "macOS updates are available. Would you like to install them now?" buttons {"Install", "Later"} default button "Install" with icon caution
                if button returned of response is "Install" then
                    do shell script "sudo $MACOS_UPDATE_SCRIPT" with administrator privileges
                end if
            end tell
EOD
        return 0
    fi
}

# Function to check for app updates
check_app_updates() {
    log_message "INFO" "Checking for app updates..."
    
    if ! command -v brew &>/dev/null; then
        log_message "ERROR" "Homebrew not installed"
        return 1
    fi
    
    brew update &>/dev/null
    local outdated
    outdated=$(brew outdated --quiet | wc -l)
    
    if [ "$outdated" -gt 0 ]; then
        send_notification "App Updates Available" "$outdated applications can be updated" "Submarine"
        log_message "INFO" "Found $outdated app updates"
        
        # Ask if user wants to update apps now
        osascript <<EOD
            tell application "System Events"
                activate
                set response to display dialog "$outdated applications can be updated. Would you like to update them now?" buttons {"Update", "Later"} default button "Update" with icon caution
                if button returned of response is "Update" then
                    do shell script "$APPS_UPDATE_SCRIPT"
                end if
            end tell
EOD
        return 0
    fi
    
    log_message "INFO" "No app updates available"
    return 1
}

# Function to create LaunchAgent
create_launch_agent() {
    local check_interval="$1" # In hours
    
    # Convert hours to seconds
    local interval_seconds=$((check_interval * 3600))
    
    cat > "$LAUNCH_AGENT_PLIST" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${LAUNCH_AGENT_LABEL}</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>$SCRIPT_DIR/update_notifier.sh</string>
        <string>--check</string>
    </array>
    <key>StartInterval</key>
    <integer>${interval_seconds}</integer>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
EOF
    
    log_message "INFO" "Created LaunchAgent with ${check_interval}h interval"
}

# Function to install notifier
install_notifier() {
    echo -e "${BLUE}Installing Update Notifier...${NC}"
    
    # Create log directory if it doesn't exist
    mkdir -p "$LOG_DIR"
    
    # Ask for check interval
    read -p "How often should updates be checked? (hours, default: 24) " check_interval
    check_interval=${check_interval:-24}
    
    # Create and load LaunchAgent
    create_launch_agent "$check_interval"
    launchctl unload "$LAUNCH_AGENT_PLIST" 2>/dev/null
    launchctl load "$LAUNCH_AGENT_PLIST"
    
    echo -e "${GREEN}✓ Update Notifier installed and scheduled${NC}"
    echo "Updates will be checked every $check_interval hours"
    log_message "SUCCESS" "Notifier installed with ${check_interval}h interval"
}

# Function to uninstall notifier
uninstall_notifier() {
    echo -e "${BLUE}Uninstalling Update Notifier...${NC}"
    
    # Unload and remove LaunchAgent
    launchctl unload "$LAUNCH_AGENT_PLIST" 2>/dev/null
    rm -f "$LAUNCH_AGENT_PLIST"
    
    echo -e "${GREEN}✓ Update Notifier uninstalled${NC}"
    log_message "INFO" "Notifier uninstalled"
}

# Main execution
main() {
    case "$1" in
        --install)
            install_notifier
            ;;
        --uninstall)
            uninstall_notifier
            ;;
        --check)
            check_macos_updates
            check_app_updates
            ;;
        *)
            echo "Usage: $0 {--install|--uninstall|--check}"
            echo "  --install   Install and schedule notifications"
            echo "  --uninstall Remove scheduling"
            echo "  --check     Run check immediately"
            exit 1
            ;;
    esac
}

# Execute main function with all arguments
main "$@"