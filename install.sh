#!/bin/bash

echo "Starting the script..."

# Check if script is run as root
if [ "$(id -u)" != "0" ]; then
    echo "This script must be run as root. Please use \"sudo su root\" then run this."
    exit 1
fi

# Update package lists
echo "Updating package lists..."
apt update

# Install Apache2
echo "Installing Apache2..."
apt install apache2 -y

# Add PHP PPA repository
echo "Adding PHP PPA repository..."
add-apt-repository --yes ppa:ondrej/php
apt update

# Install PHP and required extensions
echo "Installing PHP and required extensions..."
apt install php8.2-{fpm,cli,bz2,curl,mbstring,intl,bcmath,xml,mysql,zip,gd,imagick} libapache2-mod-php8.2 -y
a2enmod proxy_fcgi setenvif
a2enconf php8.2-fpm 
systemctl reload apache2
echo "<?php phpinfo(); ?>" | sudo tee /var/www/html/info.php

# Install MySQL
echo "Installing MySQL..."
apt install mysql-server -y

echo "Securing MySQL installation..."
mysql_secure_installation

# Install phpMyAdmin
echo "Installing phpMyAdmin..."
apt install phpmyadmin -y

# Install vsftpd
echo "Installing vsftpd..."
apt install vsftpd -y

# Install Certbot and Apache plugin
echo "Installing Certbot and Apache plugin..."
apt install certbot python3-certbot-apache -y

# Install FileBrowser
echo "Installing FileBrowser..."
curl -fsSL https://raw.githubusercontent.com/filebrowser/get/master/get.sh | bash

# Fetch the public IP address using a public IP address API
echo "Fetching public IP address..."
public_ip=$(curl -s https://api.ipify.org)

# Copy the modified configuration files to their respective locations
echo "Copying modified configuration files..."
cat apache.txt > /etc/apache2/apache2.conf
cat php.txt > /etc/php/8.2/fpm/php.ini
cat pma.txt > /etc/phpmyadmin/config.inc.php
cat ftp.txt > /etc/vsftpd.conf
sed -i "s/your_public_ip/$public_ip/g" /etc/vsftpd.conf

#Here reload or restart necessary services for applying new config
echo "Reloading or restarting necessary services..."
systemctl reload apache2
systemctl restart php8.2-fpm
systemctl restart vsftpd


# Configure UFW
echo "Configuring UFW..."
ufw allow OpenSSH
ufw allow http
ufw allow https
ufw allow 20/tcp 
ufw allow 21/tcp 
ufw allow 10090:10100/tcp
ufw enable

echo "Packages installation and configuration completed!"

