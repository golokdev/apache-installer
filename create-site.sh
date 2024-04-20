#!/bin/bash

cert_dir="/etc/ssl/certs/apache2"

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

# Function to check if a website exists
check_website_exists() {
    domain="$1"
    if [ -f "/etc/apache2/sites-available/$domain.conf" ]; then
        return 0
    else
        return 1
    fi
}

# Function to check if a user exists
check_user_exists() {
    username="$1"
    if id "$username" &>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Function to create a new user
create_user() {
    username="$1"

     # Create a new group with the same name as the username
    groupadd "$username"
    usermod -a -G "$username" www-data
    # Create a new user and set the group
    useradd -m -s /bin/bash -g "$username" "$username"
    
    mkdir -p  "/var/www/$username"
    usermod -d /var/www/$username $username
    systemctl restart vsftpd
    # Ask for password and confirm password
    while true; do
        read -s -p "Enter password for user $username: " password
        echo ""
        read -s -p "Confirm password for user $username: " confirm_password
        echo ""
        if [ "$password" = "$confirm_password" ]; then
            echo "$username:$password" | chpasswd
            echo "User $username created successfully."
            break
        else
            echo "Passwords do not match. Please try again."
        fi
    done
}

# Function to find the next available port starting from 8080
find_next_available_port() {
    port=8081
    while ss -tln | grep -q ":$port"; do
        ((port++))
    done
    echo "$port"
}

# Function to create a wildcard SSL certificate
create_certificate() {
    domain="$1"

    # Check if the SSL certificate directory exists, if not, create it
    mkdir -p "$cert_dir"
    

    # Check if the SSL certificate and key already exist
    if [ ! -f "$cert_dir/$domain.crt" ] || [ ! -f "$cert_dir/$domain.key" ]; then
        # Wildcard certificate for all subdomains
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout "$cert_dir/$domain.key" -out "$cert_dir/$domain.crt" -subj "/CN=*.$domain"
    else
        # Certificate and key already exist, delete them and create new ones
        echo "Certificate and key already exist for $domain. Overwriting..."
        rm -f "$cert_dir/$domain.crt" "$cert_dir/$domain.key"
        create_certificate "$domain"  # Call the function recursively to create new certificate and key
    fi
}

create_website() {
    domain="$1"
    username="$2"
    fb_port="$3"

    # Create site directory
    mkdir -p "/var/www/$username/$domain/public_html"
    echo "<?php echo 'Your website $domain working :)'; ?>" > "/var/www/$username/$domain/public_html/index.php"
    chmod -R 755 /var/www/$username
    chmod -R g+w /var/www/$username
    chown -R $username:$username /var/www/$username

    cp src/site.txt /etc/apache2/sites-available/$domain.conf
    sed -i \
        -e "s/{{domain}}/$domain/g" \
        -e "s/{{username}}/$username/g" \
        -e "s|{{cert_dir}}|$cert_dir|g" \
        -e "s/{{fb_port}}/$fb_port/g" \
        /etc/apache2/sites-available/$domain.conf


    a2enmod proxy
    a2enmod proxy_http
    a2enmod ssl
    a2enmod rewrite
    a2ensite "$domain.conf"
    systemctl restart apache2
    echo "Website $domain created successfully!"
}

# Function to create Filebrowser service
create_filebrowser_service() {
    domain="$1"
    fb_service_file="/etc/systemd/system/filebrowser-$domain.service"
    fb_database_file="/etc/filebrowser/database/$domain.db"
    fb_config_file="/etc/filebrowser/config/$domain.json"
    fb_home_dir="/var/www/$username/$domain/public_html"
    # Create directories if not exist
    mkdir -p "/etc/filebrowser/database"
    mkdir -p "/etc/filebrowser/config"

    # Find the next available port
    fb_port=$(find_next_available_port)

    # Create Filebrowser service file
    cp src/fb-service.txt "$fb_service_file"
    sed -i -e "s/username/$username/g" -e "s|config_file|$fb_config_file|g" "$fb_service_file"
    
    # Create Filebrowser configuration file
    cp src/fb-json.txt "$fb_config_file"
    sed -i -e "s/fb_port/$fb_port/g" -e "s|fb_database_file|$fb_database_file|g" -e "s|fb_home_dir|$fb_home_dir|g" "$fb_config_file"

    
    # Initialize Filebrowser database in the background
    filebrowser -d "$fb_database_file" &
    
    # Capture the process ID of the background process
    filebrowser_pid=$!
    
    # Wait for a moment to ensure that Filebrowser has initialized the database
    sleep 1
    
    # Stop Filebrowser using its process ID
    kill "$filebrowser_pid"

    # Set permissions to the database file
    chown $username:$username "$fb_database_file"
    
    # Reload daemon and start Filebrowser service
    systemctl daemon-reload
    systemctl enable "filebrowser-$domain"
    systemctl start "filebrowser-$domain"

    #opening the port
    ufw allow $fb_port/tcp
    ufw reload
}

# Check if script is run as root
if [ "$(id -u)" != "0" ]; then
    echo "This script must be run as root. Please use \"sudo su root\" then run this."
    exit 1
fi

if ! check_all_packages; then
    echo "Some required packages are not installed. Please run ./install.sh script to install them."
    exit 1
fi

# Ask user for domain name and username
read -p "Enter domain name: " domain
read -p "Enter username: " username

# Check if the website already exists
if check_website_exists "$domain"; then
    echo "A site with the domain $domain already exists. Aborting."
    exit 1
fi

# Check if the username already exists
if check_user_exists "$username"; then
    read -p "Do you want to proceed with user $username? [Y/n]: " choice
    case "$choice" in
        [Yy]*)
            ;;
        *)
            read -p "Enter a different username: " username
            ;;
    esac
else
    create_user "$username"
fi

# Create Filebrowser service for the subdomain files.domain
create_filebrowser_service "$domain"

# Create wildcard SSL certificate
create_certificate "$domain"

# Create website in the virtual host
create_website "$domain" "$username" "$fb_port"
