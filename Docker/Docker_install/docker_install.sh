#!/bin/bash

# Function to install Docker
install_docker() {
    sudo apt-get update
    sudo apt-get install -y ca-certificates curl
    sudo mkdir -p /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo tee /etc/apt/keyrings/docker.asc > /dev/null
    sudo chmod a+r /etc/apt/keyrings/docker.asc
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
}

# Function to check if Docker is installed and install it if not
installation_docker_client() {
    if ! command -v docker &>/dev/null; then
        echo "Docker wird installiert"
        install_docker
    else
        echo "Docker ist bereits installiert"
    fi
}

# Function to fix dpkg configuration issues
fix_dpkg() {
    sudo rm /var/lib/dpkg/updates/*
    sudo dpkg --configure -a
}

# Function to handle the installation process on a slave
installation_slave() {
    echo "Gib die IP des Slaves an"
    read -r ip_slave
    
    echo "Gib den Benutzernamen an"
    read -r user_slave

    echo "Gib das Passwort ein"
    read -s pw_slave

    # Create a temporary script file
    temp_script=$(mktemp)
    declare -f install_docker installation_docker_client fix_dpkg > "$temp_script"
    echo 'fix_dpkg' >> "$temp_script"
    echo 'installation_docker_client' >> "$temp_script"

    # Copy the script to the remote machine and execute it
    sshpass -p "$pw_slave" scp "$temp_script" "$user_slave@$ip_slave:/tmp/install_docker.sh"
    sshpass -p "$pw_slave" ssh -t "$user_slave@$ip_slave" "sudo bash /tmp/install_docker.sh"
    
    # Remove the temporary script file
    rm -f "$temp_script"
}

# Main function to install Docker on multiple clients
main() {
    while true; do
        installation_slave
        echo "Möchten Sie Docker auf einem weiteren Client installieren? (ja/nein)"
        read -r answer
        if [[ $answer != "ja" ]]; then
            break
        fi
    done
}

# Run the main function
main
