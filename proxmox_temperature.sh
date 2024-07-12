#!/bin/bash

NODES_PM="/usr/share/perl5/PVE/API2/Nodes.pm"
PVE_MANAGER_JS="/usr/share/pve-manager/js/pvemanagerlib.js"
BACKUP_DIR="/root/proxmox_backup"

function install_lm_sensors {
    echo "Installing lm-sensors..."
    apt-get update
    apt-get install -y lm-sensors
}

function modify_files {
    echo "Creating backup directory..."
    mkdir -p $BACKUP_DIR

    echo "Backing up original files..."
    cp $NODES_PM $BACKUP_DIR/Nodes.pm.bak
    cp $PVE_MANAGER_JS $BACKUP_DIR/pvemanagerlib.js.bak

    echo "Modifying /usr/share/perl5/PVE/API2/Nodes.pm..."
    if grep -q "thermalstate" "$NODES_PM"; then
        echo "Nodes.pm already modified."
    else
        sed -i "/version_text/a \
\$res->{thermalstate} = \`sensors -j\`;" "$NODES_PM"
        echo "Nodes.pm modified successfully."
    fi

    echo "Modifying /usr/share/pve-manager/js/pvemanagerlib.js..."
    if grep -q "thermal" "$PVE_MANAGER_JS"; then
        echo "pvemanagerlib.js already modified."
    else
        # Find the line number after which to insert the new code
        line_number=$(grep -n "itemId: 'version'" $PVE_MANAGER_JS | cut -d: -f1)
        line_number=$((line_number + 1))

        # Insert the new code using sed
        sed -i "${line_number}i \\
        {\
            itemId: 'thermal',\
            colspan: 2,\
            printBar: false,\
            title: gettext('CPU Thermal State'),\
            textField: 'thermalstate',\
            renderer:function(value){\
                let objValue = JSON.parse(value);\
                let cores = objValue[\"coretemp-isa-0000\"];\
                let items = Object.keys(cores).filter(item => /Core/.test(item));\
                let str = '';\
                items.forEach((x, idx) => {\
                    str += cores[x][\`temp\${idx+2}_input\`] + ' ';\
                });\
                str += '°C';\
                return str;\
            }\
        }," "$PVE_MANAGER_JS"
        echo "pvemanagerlib.js modified successfully."
    fi
}

function restore_files {
    echo "Restoring original files..."
    if [ -f $BACKUP_DIR/Nodes.pm.bak ] && [ -f $BACKUP_DIR/pvemanagerlib.js.bak ]; then
        cp $BACKUP_DIR/Nodes.pm.bak $NODES_PM
        cp $BACKUP_DIR/pvemanagerlib.js.bak $PVE_MANAGER_JS
        echo "Files restored successfully."
    else
        echo "Backup files not found. Cannot restore."
        exit 1
    fi
}

function restart_pveproxy {
    echo "Restarting pveproxy service..."
    systemctl restart pveproxy
}

echo "Choose an option:"
echo "1) Install lm-sensors, modify files, and restart pveproxy"
echo "2) Restore original files and restart pveproxy"
read -p "Enter choice [1 or 2]: " choice

case $choice in
    1)
        install_lm_sensors
        modify_files
        restart_pveproxy
        echo "Installation, modification, and service restart completed successfully."
        ;;
    2)
        restore_files
        restart_pveproxy
        echo "Restoration and service restart completed successfully."
        ;;
    *)
        echo "Invalid choice."
        exit 1
        ;;
esac
