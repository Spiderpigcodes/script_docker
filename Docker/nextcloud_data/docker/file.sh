#!/bin/bash

# Verzeichnisse erstellen
sudo mkdir -p /mnt/shared_nvme/nextcloud_data
sudo mkdir -p /mnt/shared_nvme/nextcloud_data/docker
sudo mkdir -p /mnt/shared_nvme/nextcloud_data/config

# Berechtigungen setzen
sudo chown -R www-data:www-data /mnt/shared_nvme/nextcloud_data
sudo chmod -R 755 /mnt/shared_nvme/nextcloud_data

# Statusmeldung
echo "Verzeichnisse erstellt und Berechtigungen gesetzt."
