#!/bin/bash

# Ensure the script is run as root
if [[ "$EUID" -ne 0 ]]; then
    echo "This script must be run as root. Please use sudo or log in as root."
    exit 1
fi

# Define Wazuh installation and password tool URLs
WAZUH_INSTALL_URL="https://packages.wazuh.com/4.7/wazuh-install.sh"
PASSWORD_TOOL_URL="https://packages.wazuh.com/4.7/wazuh-passwords-tool.sh"

# Check if Wazuh is already installed
is_wazuh_installed() {
    systemctl is-active --quiet wazuh-manager && return 0 || return 1
}

# Function to change the admin password
change_admin_password() {
    echo -e "\nChanging the admin account password..."
    NEW_PASSWORD=${1:-""}

    if [[ -z "$NEW_PASSWORD" ]]; then
        echo -n "Enter the new password for the admin account: "
        read -s NEW_PASSWORD
        echo
    fi

    # Ensure the password is not empty
    if [[ -z "$NEW_PASSWORD" ]]; then
        echo "Password cannot be empty. Exiting..."
        exit 1
    fi
    
    # Change the admin password
    ./wazuh-passwords-tool.sh -u admin -p "$NEW_PASSWORD"
    if [[ $? -eq 0 ]]; then
        echo "Password changed successfully!"
        echo "Restarting Filebeat and Wazuh-dashboard services..."
        systemctl restart filebeat
        systemctl restart wazuh-dashboard
        echo "Services restarted successfully!"
    else
        echo "Failed to change password. Please check the tool and try again."
    fi
}

# Install Wazuh if not already installed
if is_wazuh_installed; then
    echo "Wazuh is already installed. Skipping installation."
else
    echo "Downloading and installing Wazuh..."
    curl -sO "$WAZUH_INSTALL_URL"
    if [[ -f "./wazuh-install.sh" ]]; then
        bash ./wazuh-install.sh -a
        if [[ $? -ne 0 ]]; then
            echo "Wazuh installation failed. Exiting..."
            exit 1
        fi
        echo "Wazuh installation completed successfully!"
    else
        echo "Failed to download Wazuh installer. Exiting..."
        exit 1
    fi
fi

# Download the Wazuh passwords tool
echo "Downloading the Wazuh passwords tool..."
curl -so wazuh-passwords-tool.sh "$PASSWORD_TOOL_URL"
if [[ -f "./wazuh-passwords-tool.sh" ]]; then
    chmod +x wazuh-passwords-tool.sh
    echo "Wazuh passwords tool downloaded successfully."
else
    echo "Failed to download the Wazuh passwords tool. Exiting..."
    exit 1
fi

# Prompt for admin password change
if [[ "$1" == "--auto-password" && -n "$2" ]]; then
    # Automatically change password if argument is provided
    change_admin_password "$2"
else
    echo -n "Do you want to change the admin account password? (Y/N): "
    read CHANGE_PASSWORD
    if [[ "$CHANGE_PASSWORD" =~ ^[Yy]$ ]]; then
        change_admin_password
    else
        echo "Admin password change skipped."
    fi
fi

echo "Script execution completed."
