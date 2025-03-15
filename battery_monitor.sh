#!/bin/bash

# Name: battery_monitor.sh
# Description: Monitors and reports on MacBook battery health and usage patterns
# 
# Features:
# - Battery health status check
# - Cycle count monitoring
# - Power usage analysis
# - Charging pattern recommendations
# - Historical data tracking
# - Alert notifications
#
# Usage:
#   chmod +x battery_monitor.sh
#   ./battery_monitor.sh
#   ./battery_monitor.sh --report
#   ./battery_monitor.sh --monitor (runs continuously)
#   ./battery_monitor.sh --help
#
# Requirements:
# - macOS (tested on Sonoma 14.0+)
# - Terminal notifications enabled
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

# Configuration
LOG_DIR="$HOME/.logs/battery_monitor"
LOG_FILE="$LOG_DIR/battery_monitor_$(date +%Y%m%d_%H%M%S).log"
HISTORY_FILE="$LOG_DIR/battery_history.csv"
ALERT_THRESHOLD=20
OPTIMAL_RANGE_MIN=20
OPTIMAL_RANGE_MAX=80

# Create log directory if it doesn't exist
mkdir -p "$LOG_DIR"

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

# Function to display help
show_help() {
    echo -e "${BLUE}=== Battery Monitor - MacBook Battery Health Utility ===${NC}"
    echo ""
    echo -e "${YELLOW}Usage:${NC}"
    echo "  ./battery_monitor.sh             - Check current battery status"
    echo "  ./battery_monitor.sh --report    - Generate detailed battery report"
    echo "  ./battery_monitor.sh --monitor   - Monitor battery continuously"
    echo "  ./battery_monitor.sh --help      - Show this help message"
    echo ""
    echo -e "${YELLOW}Log File:${NC}"
    echo "  $HISTORY_FILE"
    exit 0
}

# Function to check if running on macOS
check_macos() {
    if [[ "$(uname)" != "Darwin" ]]; then
        handle_error "This script is designed for macOS only."
        exit 1
    fi
    log_message "INFO" "Running on macOS $(sw_vers -productVersion)"
}

# Function to check battery status
check_battery_status() {
    log_message "PROCESS" "Checking Battery Status..."
    
    # Get battery information using system_profiler
    local battery_info=$(system_profiler SPPowerDataType 2>/dev/null)
    
    if [[ -z "$battery_info" ]]; then
        handle_error "Unable to retrieve battery information."
        return 1
    fi
    
    # Extract key metrics with fallback values
    local cycle_count=$(echo "$battery_info" | grep "Cycle Count" | awk '{print $3}' || echo "0")
    local condition=$(echo "$battery_info" | grep "Condition" | awk '{print $2}' || echo "Unknown")
    local charging=$(echo "$battery_info" | grep -i "Charging" | awk '{print $2}' || echo "No")
    local fully_charged=$(echo "$battery_info" | grep -i "Fully Charged" | awk '{print $3}' || echo "No")
    local percentage=$(pmset -g batt | grep -o "[0-9]*%" | cut -d% -f1 || echo "0")
    local time_remaining=$(pmset -g batt | grep -o "[0-9]\+:[0-9]\+" || echo "Unknown")
    local max_capacity=$(echo "$battery_info" | grep "Maximum Capacity" | awk '{print $3}' || echo "Unknown")
    
    # Ensure numeric values are valid
    [[ "$percentage" =~ ^[0-9]+$ ]] || percentage=0
    [[ "$cycle_count" =~ ^[0-9]+$ ]] || cycle_count=0
    
    # Determine power source
    local power_source="Battery"
    if [[ "$charging" == "Yes" || "$fully_charged" == "Yes" ]]; then
        power_source="AC Power"
    fi
    
    # Display current status
    log_message "INFO" "Battery Level: ${percentage}%"
    log_message "INFO" "Power Source: ${power_source}"
    log_message "INFO" "Cycle Count: ${cycle_count}"
    log_message "INFO" "Condition: ${condition}"
    
    if [[ "$power_source" == "Battery" && "$time_remaining" != "Unknown" ]]; then
        log_message "INFO" "Time Remaining: ${time_remaining}"
    fi
    
    if [[ "$max_capacity" != "Unknown" ]]; then
        log_message "INFO" "Maximum Capacity: ${max_capacity}"
    fi
    
    # Record to history
    local timestamp=$(date +%Y-%m-%d_%H:%M:%S)
    echo "$timestamp,$percentage,$cycle_count,$condition,$charging,$power_source,$max_capacity" >> "$HISTORY_FILE"
    
    # Check for concerning conditions
    if [[ "$percentage" =~ ^[0-9]+$ ]] && [ "$percentage" -lt "$ALERT_THRESHOLD" ] && [ "$power_source" == "Battery" ]; then
        osascript -e "display notification \"Battery level is below ${ALERT_THRESHOLD}%\" with title \"Battery Alert\"" 2>/dev/null
    fi

    # Provide recommendations
    if [[ "$percentage" =~ ^[0-9]+$ ]]; then
        if [ "$percentage" -gt "$OPTIMAL_RANGE_MAX" ] && [ "$power_source" == "AC Power" ]; then
            log_message "INFO" "Recommendation: Consider unplugging to maintain optimal battery health"
        elif [ "$percentage" -lt "$OPTIMAL_RANGE_MIN" ] && [ "$power_source" == "Battery" ]; then
            log_message "INFO" "Recommendation: Connect to power to maintain optimal battery health"
        fi
    fi
    
    return 0
}

# Function to analyze usage patterns
analyze_patterns() {
    log_message "PROCESS" "Analyzing Usage Patterns..."
    
    if [ ! -f "$HISTORY_FILE" ]; then
        log_message "INFO" "No history data available yet."
        return 1
    fi
    
    # Get today's date in YYYY-MM-DD format
    local today=$(date +%Y-%m-%d)
    
    # Calculate average battery level (only for today's records)
    local avg_level=$(awk -F',' -v today="$today" '$1 ~ today {sum+=$2; count++} END {print (count > 0 ? sum/count : 0)}' "$HISTORY_FILE")
    
    # Ensure avg_level is a number and has at least one decimal place
    if [[ -n "$avg_level" && "$avg_level" != "0" ]]; then
        avg_level=$(printf "%.1f" "$avg_level")
        log_message "INFO" "Average Battery Level Today: ${avg_level}%"
    else
        log_message "INFO" "Average Battery Level Today: N/A"
    fi

    # Check charging frequency (only for today)
    local charge_count=$(grep "$today" "$HISTORY_FILE" | grep -c "Yes" || echo "0")
    log_message "INFO" "Charging Sessions Today: ${charge_count}"

    # Analyze if mostly used plugged in (only for today)
    local today_records=$(grep -c "$today" "$HISTORY_FILE" || echo "0")
    local plugged_count=$(grep "$today" "$HISTORY_FILE" | grep -c "AC Power" || echo "0")
    
    # Ensure numeric values
    [[ "$today_records" =~ ^[0-9]+$ ]] || today_records=0
    [[ "$plugged_count" =~ ^[0-9]+$ ]] || plugged_count=0
    
    # Prevent division by zero
    local plugged_percentage=0
    if [ "$today_records" -gt 0 ]; then
        plugged_percentage=$(( (plugged_count * 100) / today_records ))
    fi
    
    log_message "INFO" "Time on AC Power Today: ${plugged_percentage}%"
    
    if [ "$plugged_percentage" -gt 80 ] && [ "$today_records" -gt 5 ]; then
        log_message "INFO" "Note: Device is frequently used while plugged in"
        log_message "INFO" "Consider occasional battery-only usage to maintain battery health"
    fi
    
    # Get the latest cycle count
    local latest_cycle=$(tail -1 "$HISTORY_FILE" | cut -d',' -f3)
    
    # Calculate cycle count increase over time if we have enough data
    local record_count=$(wc -l < "$HISTORY_FILE" || echo "0")
    if [ "$record_count" -gt 10 ]; then
        local first_date=$(head -2 "$HISTORY_FILE" | tail -1 | cut -d',' -f1 | cut -d'_' -f1)
        local first_cycle=$(head -2 "$HISTORY_FILE" | tail -1 | cut -d',' -f3)
        
        # More robust date calculation that works on different macOS versions
        local today_seconds=$(date +%s)
        local first_date_seconds=$(date -j -f "%Y-%m-%d" "$first_date" +%s 2>/dev/null || echo "0")
        
        if [ "$first_date_seconds" != "0" ]; then
            local days_diff=$(( (today_seconds - first_date_seconds) / 86400 ))
            
            if [ "$days_diff" -gt 0 ] && [[ "$latest_cycle" =~ ^[0-9]+$ ]] && [[ "$first_cycle" =~ ^[0-9]+$ ]]; then
                local cycle_diff=$((latest_cycle - first_cycle))
                if [ "$cycle_diff" -ge 0 ]; then
                    local cycles_per_month=$(( (cycle_diff * 30) / days_diff ))
                    log_message "INFO" "Estimated Battery Cycles Per Month: ${cycles_per_month}"
                fi
            fi
        fi
    fi
    
    return 0
}

# Function to generate health report
generate_report() {
    log_message "PROCESS" "Generating Battery Health Report..."
    local report_file="$HOME/Desktop/battery_report_$(date +%Y%m%d).txt"
    
    {
        echo "Battery Health Report - $(date)"
        echo "================================"
        echo ""
        echo "SYSTEM INFORMATION"
        echo "-----------------"
        system_profiler SPHardwareDataType | grep -E "Model Name|Processor|Memory|Serial Number" 2>/dev/null
        echo ""
        echo "BATTERY INFORMATION"
        echo "------------------"
        system_profiler SPPowerDataType 2>/dev/null
        echo ""
        echo "CURRENT POWER CONSUMPTION"
        echo "------------------------"
        pmset -g therm 2>/dev/null
        echo ""
        echo "USAGE STATISTICS"
        echo "---------------"
        
        # Redirect stdout to the report file temporarily
        exec 3>&1
        exec 1>&3
        
        # Capture the output of analyze_patterns
        local analysis_output=$(analyze_patterns)
        echo "$analysis_output"
        
        # Add recommendations based on cycle count
        local cycle_count=$(tail -1 "$HISTORY_FILE" 2>/dev/null | cut -d',' -f3)
        if [[ "$cycle_count" =~ ^[0-9]+$ ]]; then
            echo ""
            echo "RECOMMENDATIONS"
            echo "--------------"
            if [ "$cycle_count" -lt 300 ]; then
                echo "Your battery is still relatively new. Continue with normal usage."
            elif [ "$cycle_count" -lt 500 ]; then
                echo "Your battery has moderate wear. Consider optimizing charging habits."
            elif [ "$cycle_count" -lt 800 ]; then
                echo "Your battery has significant wear. Avoid extreme temperatures and full discharges."
            else
                echo "Your battery has high wear. Consider a battery replacement in the near future."
            fi
        fi
        
    } > "$report_file"
    
    log_message "SUCCESS" "Report generated: $report_file"
    log_message "INFO" "Opening report..."
    open "$report_file" 2>/dev/null || log_message "WARNING" "Could not open the report automatically."
}

# Function to monitor continuously
monitor_battery() {
    log_message "PROCESS" "Starting Battery Monitor..."
    log_message "INFO" "Press Ctrl+C to stop monitoring"
    
    trap 'log_message "INFO" "\nBattery monitoring stopped."' INT
    
    while true; do
        clear
        log_message "INFO" "Battery Monitor - Last updated: $(date)"
        check_battery_status
        analyze_patterns
        log_message "INFO" "\nMonitoring... (refreshes every 5 minutes)"
        log_message "INFO" "Press Ctrl+C to stop"
        sleep 300  # Check every 5 minutes
    done
}

# Main execution
main() {
    # Check if running on macOS
    check_macos
    
    # Create log directory if it doesn't exist
    mkdir -p "$LOG_DIR"
    
    # Create history file if it doesn't exist
    if [ ! -f "$HISTORY_FILE" ]; then
        echo "Timestamp,Percentage,CycleCount,Condition,Charging,PowerSource,MaxCapacity" > "$HISTORY_FILE"
    fi
    
    case "$1" in
        --report)
            check_battery_status
            generate_report
            ;;
        --monitor)
            monitor_battery
            ;;
        --help)
            show_help
            ;;
        *)
            check_battery_status
            analyze_patterns
            ;;
    esac
}

# Execute main function with all arguments
main "$@"