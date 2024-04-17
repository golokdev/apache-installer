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

# Function to get the root path of a website from its configuration file
get_website_root_path() {
    domain="$1"
    if [ -f "/etc/apache2/sites-available/$domain.conf" ]; then
        root_path=$(awk '/DocumentRoot/ {print $2}' "/etc/apache2/sites-available/$domain.conf" | tr -d '\r')
        echo "$root_path"
    else
        echo "Website configuration file not found."
    fi
}

# Function to create a Let's Encrypt SSL certificate
create_letsencrypt_certificate() {
    domain="$1"
    email="$2"
    root_path="$3"

    # Create certificate using certbot
    certbot certonly --webroot -w "$root_path" -d "$domain" -d "*.$domain" --email "$email" --agree-tos
}

# Ask user for domain name and email
read -p "Enter domain name: " domain
read -p "Enter your email address: " email

# Check if the website exists and is enabled
if check_website_enabled "$domain"; then
    root_path=$(get_website_root_path "$domain")
    echo "Root path of $domain: $root_path"
    # Create Let's Encrypt certificate
    create_letsencrypt_certificate "$domain" "$email" "$root_path"
    if [ $? -eq 0 ]; then
        echo "Let's Encrypt certificate for $domain and *.$domain created successfully."
    else
        echo "Failed to create Let's Encrypt certificate for $domain and *.$domain."
    fi
else
    echo "The website $domain either does not exist or is not enabled."
fi
