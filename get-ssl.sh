#!/bin/bash

cert_dir="/etc/ssl/certs/apache2"

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
