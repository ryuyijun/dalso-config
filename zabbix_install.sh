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

# Function to install Zabbix repository
install_zabbix_repo() {
    if [[ "$VER" == "22.04" ]]; then
        wget https://repo.zabbix.com/zabbix/7.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_7.0-2+ubuntu22.04_all.deb
        dpkg -i zabbix-release_7.0-2+ubuntu22.04_all.deb
    elif [[ "$VER" == "24.04" ]]; then
        wget https://repo.zabbix.com/zabbix/7.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_7.0-2+ubuntu24.04_all.deb
        dpkg -i zabbix-release_7.0-2+ubuntu24.04_all.deb
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
detect_os_version
echo "Detected OS: $OS $VER"
install_zabbix_repo
install_and_configure_zabbix_agent

read -p "Enter the Zabbix server address: " server_address
update_zabbix_config $server_address

echo "Zabbix Agent2 installation and configuration complete."
