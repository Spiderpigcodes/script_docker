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

# Function to install Docker on the host
install_docker_host() {
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
}

# Function to initialize Docker Swarm on the host
initialize_swarm() {
    echo "Docker Swarm wird initialisiert"
    sudo docker swarm init
    echo "Docker Swarm wurde erfolgreich initialisiert"
}

# Function to install Docker on a remote client
install_docker_remote() {
    echo "Gib die IP des Remote-Clients an"
    read -r ip_remote
    
    echo "Gib den Benutzernamen an"
    read -r user_remote

    echo "Gib das Passwort ein"
    read -s pw_remote

    # Create a temporary script file for Docker installation
    temp_script=$(mktemp)
    cat <<EOL > "$temp_script"
#!/bin/bash

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
EOL

    # Copy the script to the remote machine and execute it
    sshpass -p "$pw_remote" scp "$temp_script" "$user_remote@$ip_remote:/tmp/install_docker.sh"
    sshpass -p "$pw_remote" ssh -t "$user_remote@$ip_remote" "sudo bash /tmp/install_docker.sh"
    
    # Remove the temporary script file
    rm -f "$temp_script"
}

# Function to join a remote client to the Docker Swarm
join_swarm() {
    echo "Gib die IP des Remote-Clients an"
    read -r ip_remote
    
    echo "Gib den Benutzernamen an"
    read -r user_remote

    echo "Gib das Passwort ein"
    read -s pw_remote

    # Get the swarm join token
    token=$(sudo docker swarm join-token worker -q)
    manager_ip=$(hostname -I | awk '{print $1}')

    # Create a temporary script file for joining the swarm
    temp_script=$(mktemp)
    echo "sudo docker swarm join --token $token $manager_ip:2377" > "$temp_script"

    # Copy the script to the remote machine and execute it
    sshpass -p "$pw_remote" scp "$temp_script" "$user_remote@$ip_remote:/tmp/join_swarm.sh"
    sshpass -p "$pw_remote" ssh -t "$user_remote@$ip_remote" "sudo bash /tmp/join_swarm.sh"
    
    # Remove the temporary script file
    rm -f "$temp_script"
}

# Main function to handle the installation and swarm joining process on multiple clients
main() {
    while true; do
        install_docker_remote
        join_swarm
        echo "Möchten Sie Docker auf einem weiteren Remote-Client installieren und dem Swarm hinzufügen? (ja/nein)"
        read -r answer
        if [[ $answer != "ja" ]]; then
            break
        fi
    done
}

# Run the main function
install_docker_host
initialize_swarm
main
