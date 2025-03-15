#!/bin/bash

# Name: setup_dev_environment.sh
# Description: Sets up a secure development environment with Git configuration
# 
# Features:
# - Git installation and configuration
# - GPG key generation for signed commits
# - SSH key generation
# - Git global settings
# - Git hooks setup
# - Development tools installation
#
# Usage:
#   chmod +x setup_dev_environment.sh
#   ./setup_dev_environment.sh
#
# Requirements:
# - macOS (tested on Sonoma 14.0+)
# - Admin privileges for some installations
#
# Version: 1.2
# License: MIT

# Exit on error, undefined variables, and pipe failures
set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Log setup
LOG_DIR="$HOME/.logs"
LOG_FILE="$LOG_DIR/dev_setup_$(date +%Y%m%d_%H%M%S).log"

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
    log_message "INFO" "Starting development environment setup..."
}

# Function to check system requirements
check_requirements() {
    log_message "PROCESS" "Checking system requirements..."
    
    # Check OS
    if [[ "$(uname)" != "Darwin" ]]; then
        handle_error "This script is designed for macOS only"
        exit 1
    fi
    
    # Check internet connectivity
    if ! ping -c 1 github.com &> /dev/null; then
        handle_error "No internet connection detected"
        exit 1
    fi
    
    # Check for admin privileges
    if ! sudo -n true 2>/dev/null; then
        log_message "WARNING" "Some operations may require admin privileges"
    fi
    
    log_message "SUCCESS" "System requirements verified"
    echo -e "${GREEN}✓ System requirements met${NC}"
}

# Function to validate email format
validate_email() {
    local email=$1
    local email_regex="^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"
    
    if [[ ! $email =~ $email_regex ]]; then
        return 1
    fi
    return 0
}

# Function to install required tools
install_tools() {
    log_message "INFO" "Installing development tools..."
    echo -e "\n${BLUE}Installing Development Tools...${NC}"
    
    # Check if Homebrew is installed
    if ! command -v brew &> /dev/null; then
        echo -e "${YELLOW}Installing Homebrew...${NC}"
        
        # Ask for confirmation before installing Homebrew
        read -p "Do you want to install Homebrew? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_message "WARNING" "Homebrew installation skipped by user"
            echo -e "${YELLOW}Homebrew installation skipped. Some features may not work.${NC}"
            return 0
        fi
        
        # Download Homebrew installation script to a temporary file for inspection
        local brew_install_script=$(mktemp)
        curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh -o "$brew_install_script"
        
        # Verify the script (basic check)
        if ! grep -q "Homebrew" "$brew_install_script"; then
            handle_error "Downloaded Homebrew script appears invalid"
            rm "$brew_install_script"
            exit 1
        fi
        
        # Execute the script
        /bin/bash "$brew_install_script" || {
            handle_error "Failed to install Homebrew"
            rm "$brew_install_script"
            exit 1
        }
        
        # Clean up
        rm "$brew_install_script"
        
        # Add Homebrew to PATH for Apple Silicon Macs
        if [[ $(uname -m) == 'arm64' ]]; then
            echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
            eval "$(/opt/homebrew/bin/brew shellenv)"
        fi
    fi
    
    # Install required packages
    local packages=(
        "git"
        "gpg"
        "pinentry-mac"
        "git-lfs"
        "wget"
        "curl"
    )
    
    # Ask for confirmation before installing packages
    echo -e "${YELLOW}The following packages will be installed:${NC}"
    printf "  %s\n" "${packages[@]}"
    read -p "Do you want to continue? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_message "WARNING" "Package installation skipped by user"
        echo -e "${YELLOW}Package installation skipped. Some features may not work.${NC}"
        return 0
    fi
    
    for package in "${packages[@]}"; do
        echo -e "Installing ${package}..."
        if brew install "$package" 2>/dev/null; then
            log_message "SUCCESS" "Installed ${package}"
            echo -e "${GREEN}✓ Installed ${package}${NC}"
        else
            log_message "WARNING" "Failed to install ${package}"
            echo -e "${RED}✗ Failed to install ${package}${NC}"
        fi
    done
}

# Function to configure Git
configure_git() {
    log_message "INFO" "Configuring Git..."
    echo -e "\n${BLUE}Configuring Git...${NC}"
    
    # Check if Git is installed
    if ! command -v git &> /dev/null; then
        handle_error "Git is not installed. Please run the install_tools function first."
        return 1
    fi
    
    # Prompt for user information with validation
    local git_name=""
    local git_email=""
    
    while [[ -z "$git_name" ]]; do
        read -p "Enter your name for Git commits: " git_name
        if [[ -z "$git_name" ]]; then
            echo -e "${RED}Name cannot be empty${NC}"
        fi
    done
    
    while [[ -z "$git_email" ]]; do
        read -p "Enter your email for Git commits: " git_email
        if ! validate_email "$git_email"; then
            echo -e "${RED}Invalid email format${NC}"
            git_email=""
        fi
    done
    
    # Configure Git globals
    git config --global user.name "$git_name"
    git config --global user.email "$git_email"
    
    # Configure Git defaults
    git config --global init.defaultBranch main
    git config --global core.editor "vim"
    git config --global pull.rebase true
    git config --global fetch.prune true
    
    # Configure Git security settings
    git config --global transfer.fsckObjects true
    git config --global fetch.fsckObjects true
    git config --global receive.fsckObjects true
    
    # Configure Git to cache credentials
    git config --global credential.helper osxkeychain
    
    # Enable Git LFS if installed
    if command -v git-lfs &> /dev/null; then
        git lfs install
    else
        log_message "WARNING" "git-lfs not found, skipping LFS setup"
        echo -e "${YELLOW}git-lfs not found, skipping LFS setup${NC}"
    fi
    
    log_message "SUCCESS" "Git configured successfully"
    echo -e "${GREEN}✓ Git configured successfully${NC}"
}

# Function to set up GPG for signed commits
setup_gpg() {
    log_message "INFO" "Setting up GPG..."
    echo -e "\n${BLUE}Setting up GPG for Signed Commits...${NC}"
    
    # Check if GPG is installed
    if ! command -v gpg &> /dev/null; then
        handle_error "GPG is not installed. Please run the install_tools function first."
        return 1
    fi
    
    # Check if pinentry-mac is installed
    if ! command -v pinentry-mac &> /dev/null; then
        handle_error "pinentry-mac is not installed. Please run the install_tools function first."
        return 1
    fi
    
    # Configure GPG to use pinentry-mac
    mkdir -p ~/.gnupg
    chmod 700 ~/.gnupg
    
    # Configure GPG agent with proper pinentry path
    cat > ~/.gnupg/gpg-agent.conf << EOF
pinentry-program $(which pinentry-mac)
default-cache-ttl 3600
max-cache-ttl 7200
EOF
    
    # Configure GPG with proper preferences
    cat > ~/.gnupg/gpg.conf << EOF
use-agent
personal-cipher-preferences AES256 AES192 AES
personal-digest-preferences SHA512 SHA384 SHA256
default-preference-list SHA512 SHA384 SHA256 AES256 AES192 AES ZLIB BZIP2 ZIP Uncompressed
cert-digest-algo SHA512
s2k-cipher-algo AES256
s2k-digest-algo SHA512
charset utf-8
fixed-list-mode
no-comments
no-emit-version
keyid-format LONG
with-fingerprint
EOF
    
    # Set proper permissions
    chmod 600 ~/.gnupg/*
    
    # Restart GPG agent
    gpgconf --kill gpg-agent
    gpg-agent --daemon
    
    # Generate entropy (safer method)
    echo -e "${YELLOW}Generating system entropy for GPG key creation...${NC}"
    dd if=/dev/urandom of=/dev/null bs=1024 count=1024 &
    ENTROPY_PID=$!
    sleep 2
    kill $ENTROPY_PID 2>/dev/null || true
    
    # Create batch file for unattended GPG key generation
    echo -e "${YELLOW}Please provide information for your GPG key:${NC}"
    
    # Collect and validate input
    local real_name=""
    local email=""
    local passphrase=""
    local passphrase_confirm=""
    
    while [[ -z "$real_name" ]]; do
        read -p "Enter your real name: " real_name
        if [[ -z "$real_name" ]]; then
            echo -e "${RED}Name cannot be empty${NC}"
        fi
    done
    
    while [[ -z "$email" ]]; do
        read -p "Enter your email address: " email
        if ! validate_email "$email"; then
            echo -e "${RED}Invalid email format${NC}"
            email=""
        fi
    done
    
    # Ensure passphrase is strong enough
    while true; do
        read -s -p "Enter a secure passphrase for your GPG key (min 8 chars): " passphrase
        echo
        if [[ ${#passphrase} -lt 8 ]]; then
            echo -e "${RED}Passphrase must be at least 8 characters${NC}"
            continue
        fi
        
        read -s -p "Confirm passphrase: " passphrase_confirm
        echo
        if [[ "$passphrase" != "$passphrase_confirm" ]]; then
            echo -e "${RED}Passphrases do not match${NC}"
            continue
        fi
        
        break
    done
    
    # Create temporary batch file with secure permissions
    BATCH_FILE=$(mktemp)
    chmod 600 "$BATCH_FILE"
    
    cat > "$BATCH_FILE" << EOF
%echo Generating GPG key
Key-Type: RSA
Key-Length: 4096
Subkey-Type: RSA
Subkey-Length: 4096
Name-Real: $real_name
Name-Email: $email
Expire-Date: 2y
Passphrase: $passphrase
%commit
%echo Key generation completed
EOF
    
    # Generate the GPG key
    echo -e "${YELLOW}Generating GPG key (this may take a while)...${NC}"
    gpg --batch --generate-key "$BATCH_FILE"
    
    # Secure cleanup (using rm since shred isn't available on macOS by default)
    rm -P "$BATCH_FILE"
    
    # Get the GPG key ID
    key_id=$(gpg --list-secret-keys --keyid-format LONG | grep sec | head -n 1 | awk '{print $2}' | awk -F'/' '{print $2}')
    
    if [ -z "$key_id" ]; then
        handle_error "Failed to generate GPG key"
        return 1
    fi
    
    # Configure Git to use GPG key
    git config --global user.signingkey "$key_id"
    git config --global commit.gpgsign true
    git config --global gpg.program $(which gpg)
    
    # Export public key
    echo -e "\n${YELLOW}Your GPG public key:${NC}"
    gpg --armor --export "$key_id"
    
    # Save public key to a file
    gpg --armor --export "$key_id" > ~/.gnupg/public-key.gpg
    echo -e "\n${GREEN}✓ Public key saved to ~/.gnupg/public-key.gpg${NC}"
    
    # Add GPG environment variables to shell configuration
    if [[ "$SHELL" == */zsh ]]; then
        shell_rc="$HOME/.zshrc"
    else
        shell_rc="$HOME/.bashrc"
    fi
    
    # Check if GPG configuration already exists in shell config
    if ! grep -q "GPG configuration" "$shell_rc"; then
        cat >> "$shell_rc" << 'EOF'

# GPG configuration
export GPG_TTY=$(tty)
gpgconf --launch gpg-agent
EOF
    fi
    
    log_message "SUCCESS" "GPG setup completed"
    
    echo -e "\n${YELLOW}Important:${NC}"
    echo "1. Restart your terminal or run: source $shell_rc"
    echo "2. If you have issues with GPG signing, run: echo 'test' | gpg --clearsign"
}

# Function to set up SSH key
setup_ssh() {
    log_message "INFO" "Setting up SSH key..."
    echo -e "\n${BLUE}Setting up SSH Key...${NC}"
    
    # Check if SSH is installed
    if ! command -v ssh-keygen &> /dev/null; then
        handle_error "SSH tools are not installed"
        return 1
    fi
    
    # Generate SSH key with better entropy
    local ssh_email=""
    
    while [[ -z "$ssh_email" ]]; do
        read -p "Enter your email for SSH key: " ssh_email
        if ! validate_email "$ssh_email"; then
            echo -e "${RED}Invalid email format${NC}"
            ssh_email=""
        fi
    done
    
    # Check if SSH key already exists
    if [[ -f ~/.ssh/id_ed25519 ]]; then
        echo -e "${YELLOW}SSH key already exists at ~/.ssh/id_ed25519${NC}"
        read -p "Do you want to overwrite it? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_message "INFO" "SSH key generation skipped by user"
            echo -e "${YELLOW}SSH key generation skipped${NC}"
        else
            ssh-keygen -t ed25519 -C "$ssh_email" -f ~/.ssh/id_ed25519 -a 100
        fi
    else
        ssh-keygen -t ed25519 -C "$ssh_email" -f ~/.ssh/id_ed25519 -a 100
    fi
    
    # Configure SSH
    mkdir -p ~/.ssh
    chmod 700 ~/.ssh
    
    # Create SSH config file if it doesn't exist
    if [[ ! -f ~/.ssh/config ]]; then
        cat > ~/.ssh/config << EOF
Host *
    UseKeychain yes
    AddKeysToAgent yes
    IdentityFile ~/.ssh/id_ed25519
EOF
        chmod 600 ~/.ssh/config
    else
        # Check if our configuration is already in the file
        if ! grep -q "UseKeychain yes" ~/.ssh/config || ! grep -q "AddKeysToAgent yes" ~/.ssh/config || ! grep -q "IdentityFile ~/.ssh/id_ed25519" ~/.ssh/config; then
            echo -e "${YELLOW}Updating SSH config...${NC}"
            # Backup existing config
            cp ~/.ssh/config ~/.ssh/config.bak
            # Append our configuration
            cat >> ~/.ssh/config << EOF

# Added by setup_dev_environment.sh
Host *
    UseKeychain yes
    AddKeysToAgent yes
    IdentityFile ~/.ssh/id_ed25519
EOF
        fi
    fi
    
    # Start SSH agent
    eval "$(ssh-agent -s)"
    
    # Add SSH key to agent and keychain
    ssh-add --apple-use-keychain ~/.ssh/id_ed25519
    
    # Display public key
    echo -e "\n${YELLOW}Your SSH public key:${NC}"
    cat ~/.ssh/id_ed25519.pub
    
    # Save SSH key to clipboard
    pbcopy < ~/.ssh/id_ed25519.pub
    echo -e "\n${GREEN}✓ SSH public key copied to clipboard${NC}"
    
    log_message "SUCCESS" "SSH setup completed"
}

# Function to set up Git hooks
setup_git_hooks() {
    log_message "INFO" "Setting up Git hooks..."
    echo -e "\n${BLUE}Setting up Git Hooks...${NC}"
    
    # Check if Git is installed
    if ! command -v git &> /dev/null; then
        handle_error "Git is not installed. Please run the install_tools function first."
        return 1
    fi
    
    # Create global Git hooks directory
    mkdir -p ~/.git-hooks
    git config --global core.hooksPath ~/.git-hooks
    
    # Create pre-commit hook
    cat > ~/.git-hooks/pre-commit << 'EOF'
#!/bin/bash
set -euo pipefail

# Check for unresolved merge conflicts
if grep -r "^<<<<<<< HEAD" .; then
    echo "Error: Unresolved merge conflicts found"
    exit 1
fi

# Check for large files
if git diff --cached --name-only | xargs ls -l 2>/dev/null | awk '{if($5>5242880) print $9}' | grep -q .; then
    echo "Warning: Files larger than 5MB detected"
    read -p "Do you want to continue with the commit? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Verify GPG signing is configured
if ! git config --get user.signingkey > /dev/null; then
    echo "Error: GPG signing key not configured"
    exit 1
fi

exit 0
EOF
    
    chmod +x ~/.git-hooks/pre-commit
    
    # Create a prepare-commit-msg hook for better commit messages
    cat > ~/.git-hooks/prepare-commit-msg << 'EOF'
#!/bin/bash
set -euo pipefail

# This hook adds the branch name to the commit message
# if the commit message doesn't already contain it

COMMIT_MSG_FILE=$1
COMMIT_SOURCE=$2

# Only add branch name if this is not an amended commit or a merge commit
if [ -z "${COMMIT_SOURCE}" ]; then
    BRANCH_NAME=$(git symbolic-ref --short HEAD 2>/dev/null)
    
    # Extract ticket number from branch name (e.g., feature/ABC-123-description)
    TICKET=$(echo "$BRANCH_NAME" | grep -o -E '[A-Z]+-[0-9]+' | head -1)
    
    if [ -n "$TICKET" ] && ! grep -q "$TICKET" "$COMMIT_MSG_FILE"; then
        # Prepend the ticket number to the commit message
        sed -i.bak -e "1s/^/[$TICKET] /" "$COMMIT_MSG_FILE"
    fi
fi
EOF
    
    chmod +x ~/.git-hooks/prepare-commit-msg
    
    log_message "SUCCESS" "Git hooks configured"
    echo -e "${GREEN}✓ Git hooks configured${NC}"
}

# Function to verify installation
verify_installation() {
    log_message "INFO" "Verifying installation..."
    echo -e "\n${BLUE}Verifying Installation...${NC}"
    
    local verification_failed=0
    
    # Check Git
    if ! git --version > /dev/null 2>&1; then
        echo -e "${RED}✗ Git installation failed${NC}"
        ((verification_failed++))
    else
        echo -e "${GREEN}✓ Git installed${NC}"
    fi
    
    # Check GPG
    if ! gpg --version > /dev/null 2>&1; then
        echo -e "${RED}✗ GPG installation failed${NC}"
        ((verification_failed++))
    else
        echo -e "${GREEN}✓ GPG installed${NC}"
    fi
    
    # Check Git configuration
    if ! git config --global user.name > /dev/null 2>&1; then
        echo -e "${RED}✗ Git configuration incomplete${NC}"
        ((verification_failed++))
    else
        echo -e "${GREEN}✓ Git configured${NC}"
    fi
    
    # Check GPG key
    if ! gpg --list-secret-keys > /dev/null 2>&1; then
        echo -e "${RED}✗ GPG key not found${NC}"
        ((verification_failed++))
    else
        echo -e "${GREEN}✓ GPG key found${NC}"
    fi
    
    # Check SSH key
    if [[ ! -f ~/.ssh/id_ed25519 ]]; then
        echo -e "${RED}✗ SSH key not found${NC}"
        ((verification_failed++))
    else
        echo -e "${GREEN}✓ SSH key found${NC}"
    fi
    
    if [ $verification_failed -eq 0 ]; then
        echo -e "${GREEN}✓ All components verified successfully${NC}"
    else
        echo -e "${RED}✗ $verification_failed components failed verification${NC}"
    fi
}

# Function to display summary and next steps
display_summary() {
    echo -e "\n${BLUE}=== Setup Summary ===${NC}"
    echo -e "Log file: ${YELLOW}$LOG_FILE${NC}"
    
    echo -e "\n${YELLOW}Next Steps:${NC}"
    echo "1. Add your GPG key to GitHub:"
    echo "   - Go to GitHub Settings > SSH and GPG keys"
    echo "   - Click 'New GPG key' and paste the content from ~/.gnupg/public-key.gpg"
    
    echo -e "\n2. Add your SSH key to GitHub:"
    echo "   - The SSH key is already in your clipboard"
    echo "   - Go to GitHub Settings > SSH and GPG keys"
    echo "   - Click 'New SSH key' and paste your key"
    
    echo -e "\n3. Restart your terminal or run:"
    echo "   source ~/.zshrc (if using zsh)"
    echo "   source ~/.bashrc (if using bash)"
    
    echo -e "\n4. Test your setup:"
    echo "   git clone git@github.com:username/repo.git"
    echo "   cd repo"
    echo "   echo 'test' > test.txt"
    echo "   git add test.txt"
    echo "   git commit -S -m 'test signed commit'"
    echo "   git push"
    
    log_message "SUCCESS" "Setup completed successfully"
}

# Function to show help
show_help() {
    echo -e "${BLUE}=== Development Environment Setup Help ===${NC}"
    echo "Usage: ./setup_dev_environment.sh [OPTIONS]"
    echo
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  --skip-tools   Skip tools installation"
    echo "  --skip-gpg     Skip GPG setup"
    echo "  --skip-ssh     Skip SSH setup"
    echo "  --skip-hooks   Skip Git hooks setup"
    echo
    echo "Example:"
    echo "  ./setup_dev_environment.sh --skip-gpg"
}

# Parse command line arguments
parse_args() {
    SKIP_TOOLS=false
    SKIP_GPG=false
    SKIP_SSH=false
    SKIP_HOOKS=false
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_help
                exit 0
                ;;
            --skip-tools)
                SKIP_TOOLS=true
                shift
                ;;
            --skip-gpg)
                SKIP_GPG=true
                shift
                ;;
            --skip-ssh)
                SKIP_SSH=true
                shift
                ;;
            --skip-hooks)
                SKIP_HOOKS=true
                shift
                ;;
            *)
                echo -e "${RED}Unknown option: $1${NC}"
                show_help
                exit 1
                ;;
        esac
    done
}

# Main execution
main() {
    echo -e "${BLUE}=== Development Environment Setup ===${NC}"
    
    # Parse command line arguments
    parse_args "$@"
    
    setup_logging
    check_requirements || exit 1
    
    if [ "$SKIP_TOOLS" = false ]; then
        install_tools
    else
        log_message "INFO" "Skipping tools installation"
        echo -e "${YELLOW}Skipping tools installation${NC}"
    fi
    
    configure_git
    
    if [ "$SKIP_GPG" = false ]; then
        setup_gpg
    else
        log_message "INFO" "Skipping GPG setup"
        echo -e "${YELLOW}Skipping GPG setup${NC}"
    fi
    
    if [ "$SKIP_SSH" = false ]; then
        setup_ssh
    else
        log_message "INFO" "Skipping SSH setup"
        echo -e "${YELLOW}Skipping SSH setup${NC}"
    fi
    
    if [ "$SKIP_HOOKS" = false ]; then
        setup_git_hooks
    else
        log_message "INFO" "Skipping Git hooks setup"
        echo -e "${YELLOW}Skipping Git hooks setup${NC}"
    fi
    
    verify_installation
    display_summary
    
    echo -e "\n${GREEN}Development environment setup completed successfully${NC}"
}

# Execute main function
main "$@"