#!/bin/bash

# Default path for SSL certificates
cert_dir="/etc/ssl/certs/apache2"

# Function to create a self-signed certificate
create_certificate() {
    domain="$1"
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout "$cert_dir/$domain.key" -out "$cert_dir/$domain.crt" -subj "/CN=$domain"
}

# Function to create a new site
create_site() {
    # Parse arguments
    domain="$1"
    username="$2"

    # Check if user exists
    if id "$username" &>/dev/null; then
        read -p "User $username already exists. Do you want to proceed with this user? [y/N]: " choice
        case "$choice" in
            [Yy]*)
                ;;
            *)
                read -p "Enter a different username: " username
                ;;
        esac
    fi

    # Check if the domain already exists
    if [ -f "/etc/apache2/sites-available/$domain.conf" ]; then
        echo "A site with the domain $domain already exists. Aborting."
        exit 1
    fi

    # Create new user if not exists
    if ! id "$username" &>/dev/null; then
        useradd -m -s /bin/bash "$username"
    fi

    # Create site directory
    mkdir -p "/var/www/$username/$domain/public_html"
    chown -R "$username:$username" "/var/www/$username/$domain"

    # Create virtual host configuration
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

    CustomLog \${APACHE_LOG_DIR}/$domain_access.log combined
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

    CustomLog \${APACHE_LOG_DIR}/$domain_access.log combined
</VirtualHost>
EOF

    # Enable virtual host
    a2ensite "$domain.conf"

    # Reload Apache
    systemctl reload apache2

    echo "Site $domain created successfully!"
}

# Ask user for domain and username
read -p "Enter domain name: " domain
read -p "Enter username: " username

# Check if the domain already exists
if [ -f "/etc/apache2/sites-available/$domain.conf" ]; then
    echo "A site with the domain $domain already exists. Aborting."
    exit 1
fi

# Create the site using the provided domain and username
create_site "$domain" "$username"

# Create certificate for the domain
create_certificate "$domain"
