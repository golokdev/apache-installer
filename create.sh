#!/bin/bash

cert_dir="/etc/ssl/certs/apache2"

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

    # Create a new user
    useradd -m -s /bin/bash "$username"
    
    mkdir -p  "$username:$username" "/var/www/$username/$domain"
    chown -R "$username:$username" "/var/www/$username/$domain"
    
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
    

    
    cat << EOF > "/etc/apache2/sites-available/$domain.conf"
<VirtualHost *:80>
    ServerAdmin admin@$domain
    ServerName $domain
    ServerAlias www.$domain
    DocumentRoot /var/www/$username/$domain/public_html

    <Directory /var/www/$username/$domain/public_html>
        AllowOverride None
        Require all granted
        php_admin_value error_log "/var/www/$username/$domain/public_html/error_log"
    </Directory>

    CustomLog ${APACHE_LOG_DIR}/${domain}_access.log combined
    RewriteEngine on
    RewriteCond %{SERVER_NAME} =www.$domain [OR]
    RewriteCond %{SERVER_NAME} =$domain
    RewriteRule ^ https://%{SERVER_NAME}%{REQUEST_URI} [END,NE,R=permanent]
</VirtualHost>

<VirtualHost *:443>
    ServerAdmin admin@$domain
    ServerName $domain
    ServerAlias www.$domain
    DocumentRoot /var/www/$username/$domain/public_html

    <Directory /var/www/$username/$domain/public_html>
        AllowOverride None
        Require all granted
        php_admin_value error_log "/var/www/$username/$domain/public_html/error_log"
    </Directory>

    SSLEngine On
    SSLCertificateFile $cert_dir/$domain.crt
    SSLCertificateKeyFile $cert_dir/$domain.key

    CustomLog ${APACHE_LOG_DIR}/${domain}_access.log combined
</VirtualHost>

<VirtualHost *:443>
    ServerAdmin admin@files.$domain
    ServerName files.$domain
    ServerAlias www.files.$domain
    ProxyPreserveHost On
    ProxyPass / http://localhost:$fb_port/
    ProxyPassReverse / http://localhost:$fb_port/
</VirtualHost>
EOF

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

    # Create directories if not exist
    mkdir -p "/etc/filebrowser/database"
    mkdir -p "/etc/filebrowser/config"

    # Find the next available port
    fb_port=$(find_next_available_port)

    # Create Filebrowser service file
    cat << EOF > "$fb_service_file"
[Unit]
Description=File browser: $domain
After=network.target

[Service]
User=golokdev
Group=golokdev
ExecStart=/usr/local/bin/filebrowser -c $fb_config_file

[Install]
WantedBy=multi-user.target
EOF

    # Create Filebrowser configuration file
    cat << EOF > "$fb_config_file"
{
  "port": $fb_port,
  "baseURL": "",
  "address": "",
  "log": "stdout",
  "database": "$fb_database_file",
  "root": "/var/www/$username/$domain/public_html"
}
EOF

    # Initialize Filebrowser database in the background
    filebrowser -d "$fb_database_file" &
    
    # Capture the process ID of the background process
    filebrowser_pid=$!
    
    # Wait for a moment to ensure that Filebrowser has initialized the database
    sleep 1
    
    # Stop Filebrowser using its process ID
    kill "$filebrowser_pid"
    
    # Reload daemon and start Filebrowser service
    systemctl daemon-reload
    systemctl enable "filebrowser-$domain"
    systemctl start "filebrowser-$domain"
}

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
