#!/bin/bash

# Name: install_mac_apps.sh
# Description: Installs and configures essential applications for macOS using Homebrew
# 
# Features:
# - Verifies and installs Homebrew if needed
# - Installs essential applications (1Password, Chrome, NordVPN)
# - Configures default browser settings
# - Visual progress indicators
# - Comprehensive logging
# - Update capability
#
# Usage:
#   chmod +x install_mac_apps.sh
#   ./install_mac_apps.sh          # For installation
#   ./install_mac_apps.sh --update # For updating installed apps
#   ./install_mac_apps.sh --help   # Show help information
#
# Requirements:
# - macOS (tested on Sonoma 14.0+)
# - Internet connection
# - User with admin privileges
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

# Log setup
LOG_DIR="$HOME/.logs"
LOG_FILE="$LOG_DIR/app_install_$(date +%Y%m%d_%H%M%S).log"

# Configuration
MIN_DISK_SPACE=5  # GB
TIMEOUT_DURATION=300  # 5 minutes timeout for long operations

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
    log_message "INFO" "Starting application installation..."
}

# Function to display help
display_help() {
    echo -e "${BLUE}=== macOS Application Installation Script ===${NC}"
    echo -e "A tool to install and configure essential applications for macOS"
    echo
    echo -e "${YELLOW}Usage:${NC}"
    echo -e "  ./install_mac_apps.sh             - Install essential applications"
    echo -e "  ./install_mac_apps.sh --update    - Update installed applications"
    echo -e "  ./install_mac_apps.sh --help      - Display this help message"
    echo
    echo -e "${YELLOW}Features:${NC}"
    echo -e "  - Installs and configures Homebrew"
    echo -e "  - Installs essential applications (1Password, Chrome, NordVPN)"
    echo -e "  - Configures default settings"
    echo -e "  - Provides detailed logging"
    echo
    echo -e "${YELLOW}Log File:${NC}"
    echo -e "  $LOG_DIR/app_install_YYYYMMDD_HHMMSS.log"
    exit 0
}

# Function to check system requirements
check_requirements() {
    log_message "INFO" "Checking system requirements..."
    
    # Check if running as root
    if [ "$EUID" -eq 0 ]; then
        handle_error "This script should not be run as root or with sudo"
        echo "Please run it as a regular user. The script will ask for sudo password when needed."
        exit 1
    fi
    
    # Check internet connectivity
    if ! ping -c 1 google.com &> /dev/null; then
        handle_error "No internet connection detected"
        exit 1
    fi
    
    # Check available disk space (minimum 5GB) - fixed bc command
    available_space=$(df -h / | awk 'NR==2 {print $4}' | sed 's/[A-Za-z]//g')
    if ! [[ "$available_space" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
        log_message "WARNING" "Could not determine available disk space"
        echo -e "${YELLOW}Warning: Could not determine available disk space${NC}"
    elif (( $(echo "$available_space < $MIN_DISK_SPACE" | bc -l 2>/dev/null) )); then
        handle_error "Insufficient disk space. At least ${MIN_DISK_SPACE}GB required, but only ${available_space}GB available"
        exit 1
    fi
    
    log_message "SUCCESS" "System requirements verified"
}

# Function to run command with timeout
run_with_timeout() {
    local cmd="$1"
    local timeout_msg="$2"
    local success_msg="$3"
    local warning_msg="$4"
    
    echo -e "${YELLOW}$timeout_msg${NC}"
    
    # Use timeout command if available
    if command -v timeout &>/dev/null; then
        if timeout $TIMEOUT_DURATION bash -c "$cmd"; then
            log_message "SUCCESS" "$success_msg"
            echo -e "${GREEN}✓ $success_msg${NC}"
            return 0
        else
            log_message "WARNING" "$warning_msg"
            echo -e "${YELLOW}! $warning_msg${NC}"
            return 1
        fi
    else
        # Fallback if timeout command is not available
        if bash -c "$cmd"; then
            log_message "SUCCESS" "$success_msg"
            echo -e "${GREEN}✓ $success_msg${NC}"
            return 0
        else
            log_message "WARNING" "$warning_msg"
            echo -e "${YELLOW}! $warning_msg${NC}"
            return 1
        fi
    fi
}

# Function to install or update Homebrew
setup_homebrew() {
    log_message "INFO" "Setting up Homebrew..."
    echo -e "\n${BLUE}Setting up Homebrew...${NC}"
    
    if ! command -v brew &> /dev/null; then
        echo -e "${YELLOW}Installing Homebrew... This may take a few minutes.${NC}"
        run_with_timeout "/bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"" \
            "Installing Homebrew..." \
            "Homebrew installed successfully" \
            "Failed to install Homebrew"
        
        if [ $? -ne 0 ]; then
            exit 1
        fi
        
        # Configure Homebrew PATH for Apple Silicon
        if [[ $(uname -m) == 'arm64' ]]; then
            echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
            eval "$(/opt/homebrew/bin/brew shellenv)"
        fi
        
        log_message "SUCCESS" "Homebrew installed successfully"
    else
        echo -e "${GREEN}Homebrew is already installed${NC}"
        
        # Update Homebrew
        echo -e "${YELLOW}Updating Homebrew...${NC}"
        run_with_timeout "brew update" \
            "Updating Homebrew..." \
            "Homebrew updated successfully" \
            "Failed to update Homebrew"
    fi
}

# Function to install applications
install_apps() {
    log_message "INFO" "Installing applications..."
    echo -e "\n${BLUE}Installing Applications...${NC}"
    
    # Define applications to install
    local apps=(
        "1password"
        "google-chrome"
        "nordvpn"
    )
    
    local success_count=0
    local total_apps=${#apps[@]}
    
    # Install each application
    for app in "${apps[@]}"; do
        echo -e "\n${YELLOW}Processing $app...${NC}"
        
        if brew list --cask "$app" &>/dev/null; then
            echo -e "${GREEN}✓ $app is already installed${NC}"
            ((success_count++))
        else
            echo -e "${YELLOW}Installing $app...${NC}"
            if run_with_timeout "brew install --cask $app" \
                "Installing $app..." \
                "$app installed successfully" \
                "Failed to install $app"; then
                ((success_count++))
            fi
        fi
    done
    
    echo -e "\n${GREEN}Successfully processed $success_count out of $total_apps applications${NC}"
}

# Function to update applications
update_apps() {
    log_message "INFO" "Updating applications..."
    echo -e "\n${BLUE}Updating Applications...${NC}"
    
    # Update Homebrew first
    run_with_timeout "brew update" \
        "Updating Homebrew..." \
        "Homebrew updated successfully" \
        "Failed to update Homebrew"
    
    # Check for outdated casks
    local outdated=$(brew outdated --cask)
    if [ -z "$outdated" ]; then
        log_message "SUCCESS" "All applications are up to date"
        echo -e "${GREEN}✓ All applications are up to date${NC}"
        return 0
    fi
    
    # Upgrade all casks
    run_with_timeout "brew upgrade --cask" \
        "Upgrading applications..." \
        "Applications updated successfully" \
        "Failed to upgrade some applications"
    
    # List updated applications
    echo -e "\n${GREEN}Updated Applications:${NC}"
    brew list --cask
}

# Function to configure applications
configure_apps() {
    log_message "INFO" "Configuring applications..."
    echo -e "\n${BLUE}Configuring Applications...${NC}"
    
    # Configure Chrome as default browser
    if [ -d "/Applications/Google Chrome.app" ]; then
        echo -e "${YELLOW}Setting up Chrome...${NC}"
        open -a "Google Chrome" --args --make-default-browser
        log_message "SUCCESS" "Chrome default browser setup initiated"
    fi
    
    # Configure 1Password if installed
    if [ -d "/Applications/1Password.app" ]; then
        echo -e "${YELLOW}1Password is installed. You should set it up manually.${NC}"
        log_message "INFO" "1Password installation detected"
    fi
    
    # Configure NordVPN if installed
    if [ -d "/Applications/NordVPN.app" ]; then
        echo -e "${YELLOW}NordVPN is installed. You should set it up manually.${NC}"
        log_message "INFO" "NordVPN installation detected"
    fi
}

# Function to display summary and next steps
display_summary() {
    echo -e "\n${BLUE}=== Installation Summary ===${NC}"
    echo -e "Log file: ${YELLOW}$LOG_FILE${NC}"
    
    echo -e "\n${GREEN}Installed Applications:${NC}"
    brew list --cask
    
    echo -e "\n${YELLOW}Next Steps:${NC}"
    echo "1. Set up 1Password and sign in to your account"
    echo "2. Configure NordVPN with your credentials"
    echo "3. Set Chrome as your default browser in System Settings > Desktop & Dock"
    
    echo -e "\n${BLUE}To update all applications in the future, run:${NC}"
    echo "$ ./install_mac_apps.sh --update"
    
    log_message "INFO" "Displayed installation summary"
}

# Main execution
main() {
    # Process command line arguments
    if [ "$1" == "--help" ]; then
        display_help
    elif [ "$1" == "--update" ]; then
        setup_logging
        setup_homebrew
        update_apps
        exit 0
    fi
    
    # Normal installation flow
    echo -e "${BLUE}=== macOS Application Installation ===${NC}"
    
    setup_logging
    check_requirements
    setup_homebrew
    install_apps
    configure_apps
    display_summary
    
    log_message "SUCCESS" "Installation completed successfully"
    echo -e "\n${GREEN}Installation completed successfully${NC}"
}

# Create a trap to handle script interruption
trap 'echo -e "\n${RED}Script interrupted${NC}"; log_message "WARNING" "Script interrupted"; exit 1' INT TERM

# Execute main function with all arguments
main "$@"