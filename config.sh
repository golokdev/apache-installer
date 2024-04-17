#!/bin/bash

# Fetch the public IP address using a public IP address API
public_ip=$(curl -s https://api.ipify.org)

# Copy the modified configuration files to their respective locations
cat apache.txt > /etc/apache2/apache2.conf
cat php.txt > /etc/php/8.2/fpm/php.ini
cat pma.txt > /etc/phpmyadmin/config.inc.php
cat ftp.txt > /etc/vsftpd.conf

sed -i "s/your_public_ip/$public_ip/g" /etc/vsftpd.conf
