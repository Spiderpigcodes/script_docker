#!/bin/bash

# Function to uninstall Docker
uninstall_docker() {
    echo "Docker wird deinstalliert"

    # Stop Docker services
    sudo systemctl stop docker
    sudo systemctl stop docker.socket

    # Remove Docker packages
    sudo apt-get purge -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    # Remove Docker dependencies
    sudo apt-get autoremove -y --purge docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    # Remove Docker configuration files
    sudo rm -rf /var/lib/docker
    sudo rm -rf /etc/docker
    sudo rm /etc/apparmor.d/docker
    sudo groupdel docker
    sudo rm -rf /var/run/docker.sock

    echo "Docker wurde erfolgreich deinstalliert"
}

# Function to handle the uninstallation process on a remote machine
uninstallation_slave() {
    echo "Gib die IP des Slaves an"
    read -r ip_slave
    
    echo "Gib den Benutzernamen an"
    read -r user_slave

    echo "Gib das Passwort ein"
    read -s pw_slave

    # Create a temporary script file
    temp_script=$(mktemp)
    declare -f uninstall_docker > "$temp_script"
    echo 'uninstall_docker' >> "$temp_script"

    # Copy the script to the remote machine and execute it
    sshpass -p "$pw_slave" scp "$temp_script" "$user_slave@$ip_slave:/tmp/uninstall_docker.sh"
    sshpass -p "$pw_slave" ssh -t "$user_slave@$ip_slave" "sudo bash /tmp/uninstall_docker.sh"
    
    # Remove the temporary script file
    rm -f "$temp_script"
}

# Main function to uninstall Docker on multiple clients
main() {
    while true; do
        uninstallation_slave
        echo "Möchten Sie Docker auf einem weiteren Client deinstallieren? (ja/nein)"
        read -r answer
        if [[ $answer != "ja" ]]; then
            break
        fi
    done
}

# Run the main function
uninstall_docker
main
