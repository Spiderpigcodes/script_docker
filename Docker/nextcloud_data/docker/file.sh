#!/bin/bash

# Verzeichnisse erstellen
sudo mkdir -p /mnt/shared_nvme/nextcloud_data/db
sudo mkdir -p /mnt/shared_nvme/nextcloud_data/config
sudo mkdir -p /mnt/shared_nvme/nextcloud_data/data
sudo mkdir -p /mnt/shared_nvme/nextcloud_data/certs
sudo mkdir -p /mnt/shared_nvme/nextcloud_data/docker

# Berechtigungen setzen
sudo chown -R 999:999 /mnt/shared_nvme/nextcloud_data/db
sudo chown -R www-data:www-data /mnt/shared_nvme/nextcloud_data/config
sudo chown -R www-data:www-data /mnt/shared_nvme/nextcloud_data/data
sudo chown -R root:root /mnt/shared_nvme/nextcloud_data/certs
sudo chmod -R 755 /mnt/shared_nvme/nextcloud_data/db
sudo chmod -R 755 /mnt/shared_nvme/nextcloud_data/config
sudo chmod -R 755 /mnt/shared_nvme/nextcloud_data/data
sudo chmod -R 755 /mnt/shared_nvme/nextcloud_data/certs

# Selbstsigniertes SSL-Zertifikat erstellen
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /mnt/shared_nvme/nextcloud_data/certs/privkey.pem -out /mnt/shared_nvme/nextcloud_data/certs/fullchain.pem -subj "/C=DE/ST=Berlin/L=Berlin/O=Example-Corp/OU=IT/CN=example.com"

# Berechtigungen für Zertifikate setzen
sudo chmod 600 /mnt/shared_nvme/nextcloud_data/certs/privkey.pem
sudo chmod 644 /mnt/shared_nvme/nextcloud_data/certs/fullchain.pem

echo "Verzeichnisse erstellt und Berechtigungen gesetzt."
