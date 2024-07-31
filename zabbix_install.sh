#!/bin/bash

# Function to detect OS version
detect_os_version() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
    else
        echo "Cannot detect the OS version."
        exit 1
    fi
}

# Function to check if Zabbix agent is installed
check_zabbix_agent_installed() {
    if dpkg -l | grep -q zabbix-agent2; then
        return 0
    else
        return 1
    fi
}

# Function to get installed Zabbix agent version
get_zabbix_agent_version() {
    # Attempt to get the version using the command
    if zabbix_agent2 -V &> /dev/null; then
        zabbix_agent_version=$(zabbix_agent2 -V | grep "Zabbix Agent" | awk '{print $3}')
    else
        # Fallback to package manager if command version info is not available
        zabbix_agent_version=$(dpkg -l | grep zabbix-agent2 | awk '{print $3}')
    fi
}

# Function to install Zabbix repository
install_zabbix_repo() {
    if [[ "$VER" == "22.04" ]]; then
        if [ -f zabbix-release_7.0-2+ubuntu22.04_all.deb ]; then
            rm zabbix-release_7.0-2+ubuntu22.04_all.deb
        fi
        wget -q https://repo.zabbix.com/zabbix/7.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_7.0-2+ubuntu22.04_all.deb
        dpkg -i zabbix-release_7.0-2+ubuntu22.04_all.deb
        rm zabbix-release_7.0-2+ubuntu22.04_all.deb
    elif [[ "$VER" == "24.04" ]]; then
        if [ -f zabbix-release_7.0-2+ubuntu24.04_all.deb ]; then
            rm zabbix-release_7.0-2+ubuntu24.04_all.deb
        fi
        wget -q https://repo.zabbix.com/zabbix/7.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_7.0-2+ubuntu24.04_all.deb
        dpkg -i zabbix-release_7.0-2+ubuntu24.04_all.deb
        rm zabbix-release_7.0-2+ubuntu24.04_all.deb
    else
        echo "Unsupported Ubuntu version: $VER"
        exit 1
    fi
    apt update
}

# Function to install and configure Zabbix agent2
install_and_configure_zabbix_agent() {
    apt install -y zabbix-agent2 zabbix-agent2-plugin-*
    systemctl restart zabbix-agent2
    systemctl enable zabbix-agent2
}

# Function to update zabbix_agent2.conf with the server address
update_zabbix_config() {
    local server_address=$1
    sed -i "s/^Server=.*/Server=$server_address/" /etc/zabbix/zabbix_agent2.conf
    systemctl restart zabbix-agent2
}

# Main script
read -p "Enter the Zabbix server address: " server_address

detect_os_version
echo "Detected OS: $OS $VER"

if check_zabbix_agent_installed; then
    echo "Zabbix Agent2 is already installed. Updating configuration..."
else
    echo "Zabbix Agent2 is not installed. Installing..."
    install_zabbix_repo
    install_and_configure_zabbix_agent
fi

update_zabbix_config $server_address

# Retrieve and display additional information
host_ip=$(hostname -I | awk '{print $1}')
system_info=$(uname -a)
if check_zabbix_agent_installed; then
    get_zabbix_agent_version
    echo "Zabbix Agent2 version: $zabbix_agent_version"
else
    echo "Failed to detect Zabbix Agent2 version."
fi

echo "OS: $OS $VER"
echo "Zabbix Server: $server_address"
echo "Host IP: $host_ip"
echo "System Information: $system_info"
echo "Zabbix Agent2 installation and configuration complete."
