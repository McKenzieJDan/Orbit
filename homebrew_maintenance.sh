#!/bin/bash

# Name: homebrew_maintenance.sh
# Description: Maintains and secures Homebrew packages and casks
# 
# Features:
# - Updates Homebrew and all packages
# - Performs security audits
# - Cleans up old versions and cache
# - Checks system for issues
# - Detailed logging and reporting
#
# Usage:
#   chmod +x homebrew_maintenance.sh
#   ./homebrew_maintenance.sh
#   ./homebrew_maintenance.sh --quick (skip cleanup)
#   ./homebrew_maintenance.sh --help (show help)
#
# Requirements:
# - macOS (tested on Sonoma 14.0+)
# - Homebrew installed
# - Internet connection
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
LOG_FILE="$LOG_DIR/homebrew_maintenance_$TIMESTAMP.log"

# Configuration
TIMEOUT_DURATION=300  # 5 minutes timeout for brew operations
DISK_SPACE_THRESHOLD=5  # GB

# Function to log messages
log_message() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${timestamp}: [${level}] ${message}"
    echo "${timestamp}: [${level}] ${message}" >> "$LOG_FILE"
}

# Function to handle errors
handle_error() {
    log_message "ERROR" "$1"
    echo -e "${RED}Error: $1${NC}"
    return 1
}

# Function to set up logging
setup_logging() {
    mkdir -p "$LOG_DIR" || handle_error "Failed to create log directory"
    touch "$LOG_FILE" || handle_error "Failed to create log file"
    log_message "INFO" "Starting Homebrew maintenance..."
}

# Function to display help
display_help() {
    echo -e "${BLUE}=== Homebrew Maintenance Script ===${NC}"
    echo -e "A tool to maintain and secure your Homebrew installation"
    echo
    echo -e "${YELLOW}Usage:${NC}"
    echo -e "  ./homebrew_maintenance.sh             - Run full maintenance"
    echo -e "  ./homebrew_maintenance.sh --quick     - Skip cleanup operations"
    echo -e "  ./homebrew_maintenance.sh --help      - Display this help message"
    echo
    echo -e "${YELLOW}Features:${NC}"
    echo -e "  - Updates Homebrew and all packages"
    echo -e "  - Performs security checks"
    echo -e "  - Cleans up old versions and cache"
    echo -e "  - Provides detailed statistics and reports"
    echo
    echo -e "${YELLOW}Log File:${NC}"
    echo -e "  $LOG_DIR/homebrew_maintenance_YYYYMMDD_HHMMSS.log"
    exit 0
}

# Function to check system requirements
check_requirements() {
    log_message "INFO" "Checking system requirements..."
    echo -e "\n${BLUE}Checking System Requirements...${NC}"
    
    # Check if Homebrew is installed
    if ! command -v brew &> /dev/null; then
        handle_error "Homebrew is not installed"
        echo -e "Install Homebrew first: ${YELLOW}https://brew.sh${NC}"
        exit 1
    fi
    
    # Check internet connection
    if ! ping -c 1 github.com &> /dev/null; then
        handle_error "No internet connection"
        exit 1
    fi
    
    # Check available disk space
    available_space=$(df -h /usr/local 2>/dev/null | awk 'NR==2 {gsub(/[A-Za-z]/,"",$4); print $4}')
    if [[ $available_space =~ ^[0-9]+(\.[0-9]+)?$ ]] && (( $(echo "$available_space < $DISK_SPACE_THRESHOLD" | bc -l) )); then
        log_message "WARNING" "Low disk space: ${available_space}GB available"
        echo -e "${YELLOW}Warning: Low disk space. Some operations may fail.${NC}"
    fi
    
    log_message "SUCCESS" "System requirements verified"
    echo -e "${GREEN}✓ System requirements met${NC}"
}

# Function to run command with timeout
run_with_timeout() {
    local cmd="$1"
    local timeout_msg="$2"
    local success_msg="$3"
    local warning_msg="$4"
    
    echo -e "${CYAN}$timeout_msg${NC}"
    
    # Use timeout command if available
    if command -v timeout &>/dev/null; then
        if timeout $TIMEOUT_DURATION $cmd; then
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
        if $cmd; then
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

# Function to check Homebrew status
check_brew_status() {
    log_message "INFO" "Checking Homebrew status..."
    echo -e "\n${BLUE}Checking Homebrew Status...${NC}"
    
    # Run Homebrew diagnostic check
    echo -e "${CYAN}Running diagnostic check...${NC}"
    if brew doctor; then
        log_message "SUCCESS" "Homebrew is healthy"
        echo -e "${GREEN}✓ Homebrew is healthy${NC}"
    else
        log_message "WARNING" "Homebrew has some issues"
        echo -e "${YELLOW}! Some issues found. Review the output above.${NC}"
    fi
    
    # Check for stale formulae
    local stale_formulae=$(brew list --formula -l | wc -l | tr -d ' ')
    echo -e "Installed formulae: ${CYAN}$stale_formulae${NC}"
}

# Function to update Homebrew and packages
update_homebrew() {
    log_message "INFO" "Updating Homebrew..."
    echo -e "\n${BLUE}Updating Homebrew and Packages...${NC}"
    
    # Update Homebrew - with lock check
    echo -e "${CYAN}Updating Homebrew...${NC}"
    if brew update-reset 2>/dev/null; then
        # Try update after reset
        if brew update; then
            log_message "SUCCESS" "Homebrew updated"
            echo -e "${GREEN}✓ Homebrew updated${NC}"
        else
            log_message "WARNING" "Failed to update Homebrew"
            echo -e "${YELLOW}! Failed to update Homebrew${NC}"
        fi
    else
        log_message "WARNING" "Could not reset Homebrew update lock"
        echo -e "${YELLOW}! Could not reset Homebrew update lock${NC}"
    fi
    
    # Upgrade all packages
    run_with_timeout "brew upgrade" "Upgrading packages..." "Packages upgraded" "Some packages failed to upgrade"
    
    # Upgrade casks
    run_with_timeout "brew upgrade --cask" "Upgrading casks..." "Casks upgraded" "Some casks failed to upgrade"
}

# Function to perform security audit
security_audit() {
    log_message "INFO" "Performing security audit..."
    echo -e "\n${BLUE}Performing Security Audit...${NC}"
    
    # Check for known vulnerabilities - using brew doctor instead of audit
    echo -e "${CYAN}Checking for vulnerabilities...${NC}"
    
    # Check for outdated packages that might have security issues
    local outdated=$(brew outdated)
    if [ -z "$outdated" ]; then
        log_message "SUCCESS" "All packages up to date"
        echo -e "${GREEN}✓ All packages up to date${NC}"
    else
        log_message "WARNING" "Outdated packages found (potential security issues)"
        echo -e "${YELLOW}! Outdated packages found:${NC}"
        echo "$outdated"
    fi
    
    # Check for packages with known issues
    echo -e "${CYAN}Checking for packages with known issues...${NC}"
    if brew doctor; then
        log_message "SUCCESS" "No issues found"
        echo -e "${GREEN}✓ No issues found${NC}"
    else
        log_message "WARNING" "Issues found with installed packages"
        echo -e "${YELLOW}! Issues found with installed packages${NC}"
    fi
}

# Function to clean up Homebrew
cleanup_homebrew() {
    log_message "INFO" "Cleaning up Homebrew..."
    echo -e "\n${BLUE}Cleaning Up Homebrew...${NC}"
    
    # Calculate space before cleanup
    local space_before=$(du -sh $(brew --cache) 2>/dev/null | cut -f1)
    
    # Clean up
    echo -e "${CYAN}Removing old versions...${NC}"
    brew cleanup -s
    
    # Remove cached downloads
    echo -e "${CYAN}Cleaning download cache...${NC}"
    rm -rf $(brew --cache)/*
    
    # Calculate space saved
    local space_after=$(du -sh $(brew --cache) 2>/dev/null | cut -f1)
    echo -e "${GREEN}✓ Cleanup complete. Cache size: ${space_before} → ${space_after}${NC}"
    
    log_message "SUCCESS" "Cleanup completed"
}

# Function to display package statistics
display_stats() {
    log_message "INFO" "Gathering statistics..."
    echo -e "\n${BLUE}Package Statistics:${NC}"
    
    local formula_count=$(brew list --formula | wc -l | tr -d ' ')
    local cask_count=$(brew list --cask | wc -l | tr -d ' ')
    local outdated_count=$(brew outdated | wc -l | tr -d ' ')
    
    echo -e "Formulae installed: ${CYAN}$formula_count${NC}"
    echo -e "Casks installed: ${CYAN}$cask_count${NC}"
    echo -e "Outdated packages: ${CYAN}$outdated_count${NC}"
    
    # Show top 5 largest packages - super optimized implementation
    echo -e "\n${CYAN}Largest Packages:${NC}"
    
    # Use a much faster approach - just check the cellar directory sizes
    echo "Top packages by installation size:"
    du -sh $(brew --cellar)/* 2>/dev/null | sort -hr | head -5 || echo "Could not determine package sizes"
    
    # Also show top casks by size if available
    if [ -d "$(brew --caskroom)" ]; then
        echo -e "\n${CYAN}Largest Casks:${NC}"
        du -sh $(brew --caskroom)/* 2>/dev/null | sort -hr | head -5 || echo "Could not determine cask sizes"
    fi
}

# Function to display summary
display_summary() {
    echo -e "\n${BLUE}=== Maintenance Summary ===${NC}"
    echo -e "Log file: ${YELLOW}$LOG_FILE${NC}"
    
    if [ -f "$LOG_FILE" ]; then
        echo -e "\n${YELLOW}Warnings and Errors:${NC}"
        grep -E "WARNING|ERROR" "$LOG_FILE" || echo "No warnings or errors found"
    fi
    
    echo -e "\n${YELLOW}Recommended Actions:${NC}"
    if grep -q "WARNING" "$LOG_FILE"; then
        echo "1. Review warnings in the log file"
        echo "2. Run 'brew doctor' for detailed diagnostics"
        echo "3. Consider upgrading outdated packages"
    else
        echo -e "${GREEN}✓ No immediate actions needed${NC}"
    fi
}

# Main execution
main() {
    # Process command line arguments
    if [[ "$1" == "--help" ]]; then
        display_help
    fi
    
    echo -e "${BLUE}=== Homebrew Maintenance ===${NC}"
    
    setup_logging
    check_requirements || exit 1
    
    check_brew_status
    update_homebrew
    security_audit
    
    # Skip cleanup if --quick flag is used
    if [[ "$1" != "--quick" ]]; then
        cleanup_homebrew
    else
        log_message "INFO" "Skipping cleanup (--quick mode)"
        echo -e "${YELLOW}Skipping cleanup (--quick mode)${NC}"
    fi
    
    display_stats
    display_summary
    
    log_message "SUCCESS" "Maintenance completed"
    echo -e "\n${GREEN}Maintenance completed successfully${NC}"
}

# Create a trap to handle script interruption
trap 'echo -e "\n${RED}Script interrupted${NC}"; log_message "WARNING" "Script interrupted"; exit 1' INT TERM

# Execute main function with all arguments
main "$@"