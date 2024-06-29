#!/bin/bash

# Function to check if Docker is installed
check_docker_installed() {
    if command -v docker &> /dev/null; then
        echo "Docker ist bereits installiert"
        return 0
    else
        return 1
    fi
}

# Function to install Docker on the host
install_docker_host() {
    if check_docker_installed; then
        echo "Docker ist bereits auf dem Host installiert, überspringe die Installation"
    else
        echo "Docker wird auf dem Host installiert"
        sudo apt-get update
        sudo apt-get install -y \
            ca-certificates \
            curl \
            gnupg \
            lsb-release

        sudo mkdir -p /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

        echo \
          "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
          $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

        sudo apt-get update
        sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

        echo "Docker wurde erfolgreich auf dem Host installiert"
    fi
}

# Function to initialize Docker Swarm on the host
initialize_swarm() {
    echo "Docker Swarm wird initialisiert"
    sudo docker swarm init
    echo "Docker Swarm wurde erfolgreich initialisiert"
}

# Function to install Docker and join Swarm on a remote client
setup_remote_client() {
    echo "Gib die IP des Remote-Clients an"
    read -r ip_remote
    
    echo "Gib den Benutzernamen an"
    read -r user_remote

    echo "Gib das Passwort ein"
    read -s pw_remote

    # Get the swarm join token
    token=$(sudo docker swarm join-token worker -q)
    manager_ip=$(hostname -I | awk '{print $1}')

    # Create a temporary script file for Docker installation and Swarm join
    temp_script=$(mktemp)
    cat <<EOL > "$temp_script"
#!/bin/bash

if command -v docker &> /dev/null; then
    echo "Docker ist bereits installiert, überspringe die Installation"
else
    # Install Docker
    sudo apt-get update
    sudo apt-get install -y \
        ca-certificates \
        curl \
        gnupg \
        lsb-release

    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

    echo \
      "deb [arch=\$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      \$(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    echo "Docker wurde erfolgreich auf dem Remote-Client installiert"
fi

# Join Swarm
sudo docker swarm join --token $token $manager_ip:2377
echo "Remote-Client wurde erfolgreich dem Swarm hinzugefügt"
EOL

    # Copy the script to the remote machine and execute it
    sshpass -p "$pw_remote" scp "$temp_script" "$user_remote@$ip_remote:/tmp/setup_docker_swarm.sh"
    sshpass -p "$pw_remote" ssh -t "$user_remote@$ip_remote" "sudo bash /tmp/setup_docker_swarm.sh"
    
    # Remove the temporary script file
    rm -f "$temp_script"
}

# Main function to handle the installation and swarm joining process on multiple clients
main() {
    while true; do
        setup_remote_client
        echo "Möchten Sie Docker auf einem weiteren Remote-Client installieren und dem Swarm hinzufügen? (ja/nein)"
        read -r answer
        if [[ $answer != "ja" ]]; then
            break
        fi
    done
}

# Run the functions
install_docker_host
initialize_swarm
main
