#!/bin/bash


# Function to check if a website exists
check_website_exists() {
    domain="$1"
    if [ -f "/etc/apache2/sites-available/$domain.conf" ]; then
        return 0
    else
        return 1
    fi
}

# Function to get the username associated with a website
get_site_owner() {
    config_file="$1"
    path=$(awk '/DocumentRoot/ { print $2; exit }' "$config_file" | sed 's/"//g')
    owner=$(stat -c '%U' "$path")
    echo "$owner"
}

# Function to check if the given site owner has other sites
check_other_sites() {
    owner="$1"
    
    # Get the list of all configuration files except for the provided site
    site_configs=$(ls /etc/apache2/sites-available/)

    # Iterate over each configuration file
    for config_file in $site_configs; do
        # Get the owner of the site from the configuration file
        site_owner=$(get_site_owner "$domain")
        
        # If the owner matches the provided owner, return true
        if [ "$site_owner" = "$owner" ]; then
            return 0
        fi
    done
    
    # If no other sites were found for the owner, return false
    return 1
}

# Function to delete a user
delete_user() {
    username="$1"
    # Get the home directory of the user
    home_directory=$(getent passwd "$username" | cut -d: -f6)
    # Delete the user
    userdel -r "$username"
    # Delete the group
    groupdel "$username"
    # Delete home directory
    rm -r "$home_directory"
    echo "User $username deleted."
}










# Check if script is run as root
if [ "$(id -u)" != "0" ]; then
    echo "This script must be run as root. Please use \"sudo su root\" then run this."
    exit 1
fi

# Ask user for domain name and username
read -p "Enter domain name: " domain

config_file="/etc/apache2/sites-available/$domain.conf"
# Check if the website exists
if ! check_website_exists "$config_file"; then
    echo "Site \"$domain\" does not exist."
    exit 1
fi

# Get the owner of the site
owner=$(get_site_owner "$domain")

# Confirm if the user wants to remove the user account
if confirm "Do you want to remove the user account \"$owner\" associated with this site?"; then
    if check_other_sites "$owner"; then
        echo "This user \"$owner\" has other sites. Can not be deleted"
    else
        delete_user "$owner"
    fi
fi

# Removing home directory
echo "Removing site directory: $site_path"
rm -r "$site_path"

# Removing Apache configs
echo "Removing Apache configuration files"
rm -f "/etc/apache2/sites-available/$domain.conf"
rm -f "/etc/apache2/sites-enabled/$domain.conf"

# Removing Certificates
echo "Removing SSL certificates"
rm -f "/etc/ssl/certs/apache2/$domain.crt"
rm -f "/etc/ssl/certs/apache2/$domain.key"

# Closing File browser service
echo "Stopping File browser service: filebrowser-$domain"
systemctl stop "filebrowser-$domain"
echo "Disabling File browser service: filebrowser-$domain"
systemctl disable "filebrowser-$domain"

# Getting File browser port
echo "Getting File browser port"
fb_port=$(awk -F '[:,]' '/"port"/{gsub(/[[:space:]]/, "", $2); print $2; exit}' "/etc/filebrowser/config/$domain.json")

# Removing File browser files
echo "Removing File browser files"
rm -f "/etc/systemd/system/filebrowser-$domain.service"
rm -f "/etc/filebrowser/database/$domain.db"
rm -f "/etc/filebrowser/config/$domain.json"

# Deleting File Browser Port
echo "Deleting File Browser port: $fb_port"
ufw delete allow $fb_port/tcp
ufw reload

echo "Reloading server"
# Reloading Apache2
systemctl reload apache2
# Reloading Ftp
systemctl reload vsftpd

echo "Site $domain Delete Successfully"

