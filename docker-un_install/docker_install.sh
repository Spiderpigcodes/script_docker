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

    # Ensure Docker is in the PATH
    if ! command -v docker &>/dev/null; then
        export PATH=$PATH:/usr/bin
    fi
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
    echo "sudo docker swarm join --token $swarm_token $manager_ip:2377" >> "$temp_script"

    # Add the remote host to known hosts and copy the script to the remote machine
    sshpass -p "$pw_slave" ssh -o StrictHostKeyChecking=no "$user_slave@$ip_slave" "mkdir -p /tmp"
    sshpass -p "$pw_slave" scp -o StrictHostKeyChecking=no "$temp_script" "$user_slave@$ip_slave:/tmp/install_docker.sh"
    sshpass -p "$pw_slave" ssh -t -o StrictHostKeyChecking=no "$user_slave@$ip_slave" "sudo bash /tmp/install_docker.sh"
    
    # Remove the temporary script file
    rm -f "$temp_script"
}

# Function to initialize Docker Swarm on the host
initialize_swarm() {
    if ! command -v docker &>/dev/null; then
        echo "Docker wird installiert"
        install_docker
    fi
    
    if ! command -v docker &>/dev/null; then
        echo "Docker ist nicht korrekt installiert, bitte überprüfen Sie die Installation."
        exit 1
    fi
    
    if ! docker info | grep -q "Swarm: active"; then
        sudo docker swarm init --advertise-addr "$(hostname -I | awk '{print $1}')"
        echo "Docker Swarm initialized on the host."
    else
        echo "Docker Swarm is already initialized."
    fi
}

# Function to get the Swarm join token
get_swarm_token() {
    swarm_token=$(sudo docker swarm join-token -q worker)
    manager_ip=$(hostname -I | awk '{print $1}')
}

# Main function to install Docker on multiple clients and manage Swarm
main() {
    # Initialize Swarm on the host
    initialize_swarm
    # Get the Swarm join token
    get_swarm_token

    while true; do
        installation_slave
        echo "Möchten Sie Docker auf einem weiteren Remote-Client installieren und dem Swarm hinzufügen? (ja/nein)"
        read -r answer
        if [[ $answer != "ja" ]]; then
            break
        fi
    done
}

# Run the main function
main
