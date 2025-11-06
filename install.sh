#!/bin/bash

# Bluetooth Device Manager for Fedora 43
# Installs all necessary components

set -e

echo "Installing Bluetooth Device Manager..."

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   echo "This script should not be run as root"
   exit 1
fi

# Check if system has required dependencies
if ! command -v bluetoothctl &> /dev/null; then
    echo "Error: bluetoothctl not found. Please install bluez package."
    exit 1
fi

if ! command -v dbus-monitor &> /dev/null; then
    echo "Error: dbus-monitor not found. Please install dbus package."
    exit 1
fi

# Create necessary directories
sudo mkdir -p /usr/local/bin
sudo mkdir -p /etc/systemd/system
sudo mkdir -p /var/lib/bluetooth-manager

# Create the device tracker script
sudo tee /usr/local/bin/bluetooth-device-tracker > /dev/null << 'EOF'
#!/bin/bash

# Bluetooth Device Tracker
# Tracks last connected devices by type

DEVICE_FILE="/var/lib/bluetooth-manager/last_devices.conf"

# Function to get device type based on UUID and Icon
get_device_type() {
    local mac="$1"
    local info=$(bluetoothctl info "$mac" 2>/dev/null)
    
    if echo "$info" | grep -q "Icon: input-keyboard"; then
        echo "keyboard"
    elif echo "$info" | grep -q "Icon: input-mouse"; then
        echo "mouse"
    elif echo "$info" | grep -q "Icon: audio-headset\|Icon: audio-card\|UUID: Audio Sink"; then
        echo "audio"
    else
        # Fallback to UUID analysis
        if echo "$info" | grep -q "UUID: Human Interface Device"; then
            if echo "$info" | grep -q "UUID: Battery Service"; then
                echo "keyboard"  # Most HID devices with battery are keyboards
            else
                echo "mouse"     # HID without battery usually mouse
            fi
        elif echo "$info" | grep -q "UUID: Audio Sink\|UUID: Headset\|UUID: A/V Remote Control"; then
            echo "audio"
        else
            echo "unknown"
        fi
    fi
}

# Function to save device
save_device() {
    local mac="$1"
    local name="$2"
    local device_type=$(get_device_type "$mac")
    
    if [[ "$device_type" == "unknown" ]]; then
        return
    fi
    
    # Create config file if it doesn't exist
    sudo touch "$DEVICE_FILE"
    sudo chmod 644 "$DEVICE_FILE"
    
    # Remove old entry of the same type
    sudo sed -i "/^${device_type}=/d" "$DEVICE_FILE"
    
    # Add new entry
    echo "${device_type}=${mac}|${name}" | sudo tee -a "$DEVICE_FILE" > /dev/null
    
    echo "Saved ${device_type} device: ${name} (${mac})"
}

# Function to get connected devices and save them
update_connected_devices() {
    bluetoothctl devices Connected | while read -r line; do
        if [[ $line =~ Device\ ([0-9A-F:]{17})\ (.+) ]]; then
            mac="${BASH_REMATCH[1]}"
            name="${BASH_REMATCH[2]}"
            save_device "$mac" "$name"
        fi
    done
}

# Main execution
case "${1:-update}" in
    "update")
        update_connected_devices
        ;;
    "save")
        if [[ -n "$2" && -n "$3" ]]; then
            save_device "$2" "$3"
        else
            echo "Usage: $0 save <mac_address> <device_name>"
            exit 1
        fi
        ;;
    "list")
        if [[ -f "$DEVICE_FILE" ]]; then
            cat "$DEVICE_FILE"
        else
            echo "No devices recorded yet"
        fi
        ;;
    *)
        echo "Usage: $0 [update|save <mac> <name>|list]"
        exit 1
        ;;
esac
EOF

sudo chmod +x /usr/local/bin/bluetooth-device-tracker

# Create the reconnection script
sudo tee /usr/local/bin/bluetooth-reconnect > /dev/null << 'EOF'
#!/bin/bash

# Bluetooth Device Reconnector
# Reconnects to last known devices when Bluetooth turns on

DEVICE_FILE="/var/lib/bluetooth-manager/last_devices.conf"
LOCK_FILE="/tmp/bluetooth-reconnect.lock"

# Prevent multiple instances
if [[ -f "$LOCK_FILE" ]]; then
    exit 0
fi
touch "$LOCK_FILE"
trap "rm -f $LOCK_FILE" EXIT

# Wait for Bluetooth to be fully ready
sleep 3

if [[ ! -f "$DEVICE_FILE" ]]; then
    echo "No devices to reconnect"
    exit 0
fi

echo "Attempting to reconnect to saved devices..."

while IFS='=' read -r device_type device_info; do
    if [[ -n "$device_type" && -n "$device_info" ]]; then
        mac=$(echo "$device_info" | cut -d'|' -f1)
        name=$(echo "$device_info" | cut -d'|' -f2)
        
        echo "Trying to connect to ${device_type}: ${name} (${mac})"
        
        # Try to connect
        timeout 10 bluetoothctl connect "$mac" &>/dev/null
        
        # Check if connection was successful
        if bluetoothctl info "$mac" 2>/dev/null | grep -q "Connected: yes"; then
            echo "Successfully connected to ${name}"
        else
            echo "Failed to connect to ${name}"
        fi
        
        sleep 1
    fi
done < "$DEVICE_FILE"

echo "Reconnection attempts completed"
EOF

sudo chmod +x /usr/local/bin/bluetooth-reconnect

# Create the Bluetooth monitor script
sudo tee /usr/local/bin/bluetooth-monitor > /dev/null << 'EOF'
#!/bin/bash

# Bluetooth State Monitor
# Monitors Bluetooth state changes and handles device tracking/reconnection

LOG_FILE="/var/log/bluetooth-monitor.log"

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | sudo tee -a "$LOG_FILE" > /dev/null
}

# Function to check if Bluetooth is powered on
is_bluetooth_on() {
    bluetoothctl show 2>/dev/null | grep -q "Powered: yes"
}

# Monitor D-Bus for Bluetooth power state changes
monitor_bluetooth() {
    log_message "Starting Bluetooth monitor"
    
    local last_state=""
    if is_bluetooth_on; then
        last_state="on"
        log_message "Initial state: Bluetooth ON"
    else
        last_state="off"
        log_message "Initial state: Bluetooth OFF"
    fi
    
    # Monitor D-Bus signals for Bluetooth adapter property changes
    dbus-monitor --system "type='signal',interface='org.freedesktop.DBus.Properties',member='PropertiesChanged',path='/org/bluez/hci0'" 2>/dev/null | while read -r line; do
        if echo "$line" | grep -q "Powered"; then
            # Small delay to ensure the change has taken effect
            sleep 1
            
            if is_bluetooth_on; then
                if [[ "$last_state" != "on" ]]; then
                    log_message "Bluetooth turned ON - initiating reconnection"
                    /usr/local/bin/bluetooth-reconnect &
                    last_state="on"
                fi
            else
                if [[ "$last_state" != "off" ]]; then
                    log_message "Bluetooth turned OFF"
                    last_state="off"
                fi
            fi
        fi
    done
}

# Monitor for device connections to update saved devices
monitor_connections() {
    dbus-monitor --system "type='signal',interface='org.freedesktop.DBus.Properties',member='PropertiesChanged',path_namespace='/org/bluez/hci0'" 2>/dev/null | while read -r line; do
        if echo "$line" | grep -q "Connected.*true"; then
            # Device connected, update our records
            sleep 2  # Give some time for the connection to stabilize
            /usr/local/bin/bluetooth-device-tracker update &
        fi
    done
}

# Start both monitors in background
monitor_bluetooth &
MONITOR_PID=$!

monitor_connections &
CONNECTION_PID=$!

# Handle cleanup on exit
cleanup() {
    log_message "Stopping Bluetooth monitor"
    kill $MONITOR_PID $CONNECTION_PID 2>/dev/null
    exit 0
}

trap cleanup SIGTERM SIGINT

# Wait for monitors
wait $MONITOR_PID $CONNECTION_PID
EOF

sudo chmod +x /usr/local/bin/bluetooth-monitor

# Create systemd service
sudo tee /etc/systemd/system/bluetooth-manager.service > /dev/null << 'EOF'
[Unit]
Description=Bluetooth Device Manager
After=bluetooth.service
Wants=bluetooth.service

[Service]
Type=simple
ExecStart=/usr/local/bin/bluetooth-monitor
Restart=always
RestartSec=5
User=root
Group=root

[Install]
WantedBy=multi-user.target
EOF

# Create log file
sudo touch /var/log/bluetooth-monitor.log
sudo chmod 644 /var/log/bluetooth-monitor.log

# Enable and start the service
sudo systemctl daemon-reload
sudo systemctl enable bluetooth-manager.service
sudo systemctl start bluetooth-manager.service

# Update current connected devices
/usr/local/bin/bluetooth-device-tracker update

echo ""
echo "Bluetooth Device Manager installed successfully!"
echo ""
echo "The system will now:"
echo "1. Track the last connected keyboard, mouse, and audio devices"
echo "2. Automatically reconnect to them when Bluetooth is turned on"
echo "3. Log all activities to /var/log/bluetooth-monitor.log"
echo ""
echo "Service status:"
sudo systemctl status bluetooth-manager.service --no-pager -l
echo ""
echo "To view current saved devices:"
echo "  sudo /usr/local/bin/bluetooth-device-tracker list"
echo ""
echo "To view logs:"
echo "  sudo tail -f /var/log/bluetooth-monitor.log"
echo ""
echo "To uninstall, run: ./delete.sh"