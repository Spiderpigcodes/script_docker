#!/bin/bash

# Variablen
NVME_DEVICE="/dev/nvme0n1"
MOUNT_POINT="/mnt/shared_nvme"
NFS_EXPORT_DIR="$MOUNT_POINT"
NFS_CLIENT_MOUNT_POINT="$MOUNT_POINT"
NFS_SERVER_IP=$(hostname -I | awk '{print $1}')
FSTAB_ENTRY="$NVME_DEVICE $MOUNT_POINT ext4 defaults 0 0"

# Benutzer nach Passwort fragen
read -s -p "Bitte geben Sie das sudo Passwort ein: " USER_PASSWORD
echo

# Temporäre Sudoers-Datei erstellen
create_sudoers_temp() {
    local temp_sudoers
    temp_sudoers=$(mktemp)
    printf "Defaults:$(whoami) !requiretty\n$(whoami) ALL=(ALL) NOPASSWD: ALL\n" > "$temp_sudoers"
    echo "$USER_PASSWORD" | sudo -S cp "$temp_sudoers" /etc/sudoers.d/temporary_sudoers
    rm "$temp_sudoers"
}

# Temporäre Sudoers-Datei entfernen
remove_sudoers_temp() {
    echo "$USER_PASSWORD" | sudo -S rm /etc/sudoers.d/temporary_sudoers
}

# Funktion zur Konfiguration eines Remote-Clients
configure_remote_client() {
    local client_ip=$1
    local client_user=$2
    local client_password=$3

    if ! command -v sshpass &> /dev/null; then
        echo "sshpass wird installiert..."
        echo "$USER_PASSWORD" | sudo -S apt-get install -y sshpass
    fi

    sshpass -p "$client_password" ssh -o StrictHostKeyChecking=no "$client_user@$client_ip" <<EOF
echo "$client_password" | sudo -S bash -c "printf 'Defaults:$client_user !requiretty\n$client_user ALL=(ALL) NOPASSWD: ALL\n' | sudo tee /etc/sudoers.d/temporary_sudoers"
if ! dpkg -l | grep -q nfs-common; then
    sudo apt-get update
    sudo apt-get install -y nfs-common
fi
sudo mkdir -p "$MOUNT_POINT"
sudo mount -t nfs $NFS_SERVER_IP:"$NFS_EXPORT_DIR" "$MOUNT_POINT"
sudo rm /etc/sudoers.d/temporary_sudoers

# Eintrag in fstab auf dem Remote-Client hinzufügen
sudo bash -c "echo '$NFS_SERVER_IP:$NFS_EXPORT_DIR $MOUNT_POINT nfs defaults 0 0' >> /etc/fstab"

# Bash-Skript auf dem Remote-Client erstellen
sudo bash -c "cat <<'EOL' > /usr/local/bin/remount_nfs.sh
#!/bin/bash

MOUNT_POINT='/mnt/shared_nvme'
NFS_SERVER_IP='10.10.1.253'
NFS_EXPORT_DIR='/mnt/shared_nvme'

if ! mountpoint -q "\$MOUNT_POINT"; then
    echo 'NFS mount not found, attempting to remount...'
    sudo mount -t nfs "\$NFS_SERVER_IP:\$NFS_EXPORT_DIR" "\$MOUNT_POINT"
    if mountpoint -q "\$MOUNT_POINT"; then
        echo 'NFS successfully remounted.'
    else
        echo 'Failed to remount NFS.'
    fi
else
    echo 'NFS is already mounted.'
fi
EOL"

# Skript ausführbar machen
sudo chmod +x /usr/local/bin/remount_nfs.sh

# Systemd-Dienst auf dem Remote-Client erstellen
sudo bash -c "cat <<'EOL' > /etc/systemd/system/remount_nfs.service
[Unit]
Description=Remount NFS if disconnected
After=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/remount_nfs.sh
User=root
EOL"

# Systemd-Timer auf dem Remote-Client erstellen
sudo bash -c "cat <<'EOL' > /etc/systemd/system/remount_nfs.timer
[Unit]
Description=Run remount_nfs.service every minute

[Timer]
OnBootSec=1min
OnUnitActiveSec=1min
Unit=remount_nfs.service

[Install]
WantedBy=timers.target
EOL"

# Systemd-Dienst und Timer auf dem Remote-Client aktivieren und starten
sudo systemctl daemon-reload
sudo systemctl enable remount_nfs.timer
sudo systemctl start remount_nfs.timer
EOF
    if [ $? -eq 0 ]; then
        echo "Remote-Client erfolgreich konfiguriert und NFS gemountet."
    else
        echo "Verbindung fehlgeschlagen."
    fi
}

# Sudoers für Host temporär konfigurieren
create_sudoers_temp

# Abfrage, ob das Laufwerk formatiert werden soll
read -p "Soll das Laufwerk $NVME_DEVICE formatiert werden? (ja/nein): " format_drive
if [[ $format_drive == "ja" || $format_drive == "Ja" ]]; then
    echo "Formatiere NVMe..."
    echo "$USER_PASSWORD" | sudo -S mkfs.ext4 "$NVME_DEVICE"
fi

# NFS-Freigabe zur /etc/fstab hinzufügen auf dem Host
if ! grep -qs "$FSTAB_ENTRY" /etc/fstab; then
    echo "Füge NVMe-Freigabe zur /etc/fstab hinzu..."
    echo "$FSTAB_ENTRY" | sudo tee -a /etc/fstab > /dev/null
fi

# NVMe mounten
echo "Mounten der NVMe..."
sudo mkdir -p "$MOUNT_POINT"
echo "$USER_PASSWORD" | sudo -S mount "$NVME_DEVICE" "$MOUNT_POINT"

# NFS Export-Verzeichnis konfigurieren
echo "Konfigurieren des NFS-Exports..."
if ! dpkg -l | grep -q nfs-kernel-server; then
    echo "$USER_PASSWORD" | sudo -S apt-get update
    echo "$USER_PASSWORD" | sudo -S apt-get install -y nfs-kernel-server
fi
echo "$NFS_EXPORT_DIR *(rw,sync,no_subtree_check)" | sudo tee -a /etc/exports

# Verzeichnisberechtigungen setzen
echo "Setze Verzeichnisberechtigungen..."
sudo chown -R nobody:nogroup "$NFS_EXPORT_DIR"
sudo chmod -R 777 "$NFS_EXPORT_DIR"

# NFS Dienst aktivieren und starten
echo "NFS-Dienst aktivieren und starten..."
echo "$USER_PASSWORD" | sudo -S systemctl enable nfs-kernel-server
echo "$USER_PASSWORD" | sudo -S systemctl start nfs-kernel-server
echo "$USER_PASSWORD" | sudo -S exportfs -a

# Überprüfung des NFS-Dienststatus und Neustart falls nötig
if ! systemctl is-active --quiet nfs-kernel-server; then
    echo "NFS-Dienst läuft nicht, versuche Neustart..."
    echo "$USER_PASSWORD" | sudo -S systemctl restart nfs-kernel-server
    if [ $? -ne 0 ]; then
        echo "NFS-Dienst konnte nicht neu gestartet werden."
        remove_sudoers_temp
        exit 1
    else
        echo "NFS-Dienst erfolgreich neu gestartet."
    fi
else
    echo "NFS-Dienst läuft."
fi

# Firewall konfigurieren
echo "Konfigurieren der Firewall..."
echo "$USER_PASSWORD" | sudo -S ufw allow from any to any port nfs
echo "$USER_PASSWORD" | sudo -S ufw allow from any to any port 2049

# Abfrage, ob ein weiterer Remote-Client eingerichtet werden soll
while true; do
    read -p "Möchten Sie einen weiteren Remote-Client einrichten? (ja/nein): " yn
    case $yn in
        [Jj]* )
            read -p "Geben Sie die IP-Adresse des weiteren Remote-Clients ein: " NFS_CLIENT_IP
            read -p "Geben Sie den Benutzernamen des weiteren Remote-Clients ein: " NFS_CLIENT_USER
            read -s -p "Geben Sie das Passwort des weiteren Remote-Clients ein: " NFS_CLIENT_PASSWORD
            echo
            echo "$NFS_EXPORT_DIR $NFS_CLIENT_IP(rw,sync,no_subtree_check)" | sudo tee -a /etc/exports
            echo "$USER_PASSWORD" | sudo -S exportfs -a
            echo "$USER_PASSWORD" | sudo -S ufw allow from "$NFS_CLIENT_IP" to any port nfs
            echo "$USER_PASSWORD" | sudo -S ufw allow from "$NFS_CLIENT_IP" to any port 2049
            configure_remote_client "$NFS_CLIENT_IP" "$NFS_CLIENT_USER" "$NFS_CLIENT_PASSWORD"
            ;;
        [Nn]* ) break;;
        * ) echo "Bitte antworten Sie mit ja oder nein.";;
    esac
done

# Temporäre Sudoers-Datei entfernen
remove_sudoers_temp

echo "NFS-Konfiguration abgeschlossen. Überprüfen Sie die Mounts auf den Remote-Clients."
