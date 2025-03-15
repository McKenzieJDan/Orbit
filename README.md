# Orbit

A collection of shell scripts that orbit around your Mac, keeping it secure, optimized, and properly configured.

[![Shell](https://img.shields.io/badge/Shell-Bash-4EAA25.svg)](https://www.gnu.org/software/bash/)
[![macOS](https://img.shields.io/badge/macOS-Sonoma_14.0+-999999.svg)](https://www.apple.com/macos/)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Donate](https://img.shields.io/badge/Donate-PayPal-blue.svg)](https://www.paypal.com/paypalme/mckenzio)

## Features

* 🔒 Security hardening according to CIS benchmarks
* 🧹 System maintenance and cleanup utilities
* 🍺 Homebrew package management and auditing
* 🛠️ Development environment setup and configuration
* 🔋 Battery health monitoring
* 🚀 Application installation automation
* 🔄 System update management
* 🔐 Privacy protection tools

## Scripts Overview

### Security
* `macos_security_init.sh` - Initial security configuration according to CIS benchmarks
* `macos_l2_security_config.sh` - Advanced (Level 2) security configurations
* `network_security.sh` - Network-specific security configurations
* `privacy_manager.sh` - Enhanced privacy protection settings
* `configure_chrome_security_personal.sh` - Chrome browser security hardening

### Maintenance
* `homebrew_maintenance.sh` - Keeps Homebrew packages updated and secure
* `mac_cleanup.sh` - System cleanup and optimization
* `daily_maintenance.sh` - Routine maintenance tasks
* `update_macos.sh` - Manages macOS updates
* `update_notifier.sh` - Notifications for available updates

### Tools & Utilities
* `battery_monitor.sh` - Monitors and alerts on battery health
* `install_mac_apps.sh` - Automated installation of common applications

### Development
* `setup_dev_environment.sh` - Complete development environment configuration

## Installation

1. Clone this repository:
   ```
   git clone https://github.com/McKenzieJDan/orbit.git
   ```

2. Navigate to the repository directory:
   ```
   cd orbit
   ```

3. Make scripts executable:
   ```
   chmod +x *.sh
   ```

4. Run the desired script:
   ```
   ./script_name.sh
   ```

## Usage Examples

### Security Hardening

To apply baseline security configurations:
```
./macos_security_init.sh
```

For advanced security settings:
```
./macos_l2_security_config.sh
```

### System Maintenance

For routine system maintenance:
```
./daily_maintenance.sh
```

To perform a thorough system cleanup:
```
./mac_cleanup.sh
```

For Homebrew maintenance:
```
./homebrew_maintenance.sh
```

To perform a quick Homebrew update (skipping cleanup):
```
./homebrew_maintenance.sh --quick
```

### Development Setup

To configure a complete development environment:
```
./setup_dev_environment.sh
```

## Requirements

- macOS Sonoma 14.0 or higher
- Administrator privileges
- Internet connection (for scripts that require downloads)
- Homebrew (for scripts that manage packages)
- Full Disk Access permission for Terminal (for some security scripts)

## Compatibility

These scripts are primarily tested on macOS Sonoma 14.0+, but most should work on recent macOS versions with minimal modifications.

## Security Considerations

Many of these scripts modify system settings and require administrator privileges. Review each script before running to ensure you understand the changes that will be made to your system.

Scripts that modify security settings will create backups of original configurations where possible.

## Support

If you find Orbit helpful, consider [buying me a coffee](https://www.paypal.com/paypalme/mckenzio) ☕

## License

[MIT License](LICENSE)

Made with ❤️ by [McKenzieJDan](https://github.com/McKenzieJDan)