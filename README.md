# Scripts for Website Management

This repository contains a collection of scripts for managing websites, including creating and deleting sites, as well as obtaining SSL certificates.

## Scripts Overview

- `create-site.sh`: Script to create a new website with Apache configuration and SSL certificate.
- `delete-site.sh`: Script to delete an existing website along with its configuration and files.
- `get-ssl.sh`: Script to obtain SSL certificates for existing websites using Let's Encrypt.
- `install.sh`: Script to install dependencies and set up the environment for website management.

## Usage
1. Switch to root user
```
sudo su root
```
1. Clone this repository to your local machine.
```
git clone https://github.com/golokdev/apache-installer.git
```
2. Navigate to the directory containing the scripts.
```
cd apache-installer
```
3. Make all .sh files executable
```
chmod +x *.sh
```
4. Install all required packages
```
./install.sh
```
5. To create a new website
```
./create-site.sh
```
6. To setup Let's Encrypt certificate
```
./get-ssl.sh
```
7. To delete a site
```
./delete-site.sh
```

## Requirements
- These scripts are designed to be run on Ubuntu 22.04 or similar Debian-based distributions.
- Root access is required to execute some of the operations, so ensure that you have appropriate permissions.

## Author

[Golok Mallick]

## License

This project is licensed under the [MIT License](LICENSE).

