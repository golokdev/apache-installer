#!/bin/bash

# Check if script is run as root
if [ "$(id -u)" != "0" ]; then
    echo "This script must be run as root. Please use \"sudo su root\" then run this."
    exit 1
fi

# Update package lists
apt update

# Install Apache2
apt install apache2 -y

# Add PHP PPA repository
add-apt-repository --yes ppa:ondrej/php
apt update

# Install PHP and required extensions
apt install php8.2-{fpm,cli,bz2,curl,mbstring,intl,bcmath,xml,mysql,zip,gd,imagick} libapache2-mod-php8.2 -y
a2enmod proxy_fcgi setenvif
a2enconf php8.2-fpm 
systemctl reload apache2
echo "<?php phpinfo(); ?>" | sudo tee /var/www/html/info.php

# Install MySQL
apt install mysql-server -y

mysql_secure_installation

# Install phpMyAdmin
apt install phpmyadmin -y

# Install vsftpd
apt install vsftpd -y

# Install Certbot and Apache plugin
apt install certbot python3-certbot-apache -y

# Install FileBrowser
curl -fsSL https://raw.githubusercontent.com/filebrowser/get/master/get.sh | bash

echo "Packages installation completed!"
