#!/bin/bash

# Bluetooth Device Manager Uninstaller
# Removes all files and services created by install.sh

set -e

echo "Uninstalling Bluetooth Device Manager..."

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   echo "This script should not be run as root"
   exit 1
fi

# Stop and disable the service
echo "Stopping bluetooth-manager service..."
sudo systemctl stop bluetooth-manager.service 2>/dev/null || true
sudo systemctl disable bluetooth-manager.service 2>/dev/null || true

# Remove systemd service file
echo "Removing systemd service..."
sudo rm -f /etc/systemd/system/bluetooth-manager.service

# Reload systemd daemon
sudo systemctl daemon-reload

# Remove scripts
echo "Removing scripts..."
sudo rm -f /usr/local/bin/bluetooth-device-tracker
sudo rm -f /usr/local/bin/bluetooth-reconnect
sudo rm -f /usr/local/bin/bluetooth-monitor
sudo rm -f /usr/local/bin/bluetooth-startup-reconnect

# Remove data directory and files
echo "Removing data files..."
sudo rm -rf /var/lib/bluetooth-manager

# Remove log file
echo "Removing log files..."
sudo rm -f /var/log/bluetooth-monitor.log

echo ""
echo "Bluetooth Device Manager has been completely uninstalled!"
echo ""
echo "All files, services, and data have been removed from the system."