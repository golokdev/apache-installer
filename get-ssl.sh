#!/bin/bash

cert_dir="/etc/ssl/certs/apache2"

# Function to check if a package is installed
check_package() {
    package="$1"
    if dpkg -l | grep -q "^ii\s*$package"; then
        return 0
    else
        if [ "$package" == "filebrowser" ]; then
            if command -v filebrowser &>/dev/null; then
                return 0
            else
                echo "FileBrowser is not installed."
                return 1
            fi
        else
            echo "Package $package is not installed."
            return 1
        fi
    fi
}

# Function to check if all required packages are installed
check_all_packages() {
    required_packages=("apache2" "php8.2-fpm" "mysql-server" "phpmyadmin" "vsftpd" "certbot" "filebrowser" "ufw")
    for package in "${required_packages[@]}"; do
        check_package "$package" || return 1
    done
    return 0
}

# Function to check if a website exists and is enabled
check_website_enabled() {
    domain="$1"
    if [ -f "/etc/apache2/sites-available/$domain.conf" ] && [ -h "/etc/apache2/sites-enabled/$domain.conf" ]; then
        return 0
    else
        return 1
    fi
}

# Function to create a Let's Encrypt SSL certificate
create_letsencrypt_certificate() {
    domain="$1"
    email="$2"

    # Create certificate using certbot
    sudo certbot certonly --manual --preferred-challenges dns -d "$domain" -d "*.$domain" -m "$email"
}

# Check if script is run as root
if [ "$(id -u)" != "0" ]; then
    echo "This script must be run as root. Please use \"sudo su root\" then run this."
    exit 1
fi

# Check if all required packages are installed
if ! check_all_packages; then
    echo "Some required packages are not installed. Please run install.sh script to install them."
    exit 1
fi


# Ask user for domain name and email
read -p "Enter domain name: " domain
read -p "Enter your email address: " email

# Check if the website exists and is enabled
if check_website_enabled "$domain"; then
    # Create Let's Encrypt certificate
    create_letsencrypt_certificate "$domain" "$email"
    if [ $? -eq 0 ]; then
        # Copy the certificate files to your destination directory
        cp "/etc/letsencrypt/live/$domain/fullchain.pem" "$cert_dir/$domain.crt"
        cp "/etc/letsencrypt/live/$domain/privkey.pem" "$cert_dir/$domain.key"
        systemctl reload apache2
        echo "Let's Encrypt certificate for $domain and *.$domain created successfully."
    else
        echo "Failed to create Let's Encrypt certificate for $domain and *.$domain."
    fi
else
    echo "The website $domain either does not exist or is not enabled."
fi
