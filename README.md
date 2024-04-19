# Scripts for Website Management

This repository contains a collection of scripts for managing websites, including creating and deleting sites, as well as obtaining SSL certificates.

## Scripts Overview

- `create-site.sh`: Script to create a new website with Apache configuration and SSL certificate.
- `delete-site.sh`: Script to delete an existing website along with its configuration and files.
- `get-ssl.sh`: Script to obtain SSL certificates for existing websites using Let's Encrypt.
- `install.sh`: Script to install dependencies and set up the environment for website management.

## Usage

1. Clone this repository to your local machine.
2. Navigate to the directory containing the scripts.
3. Run the desired script using `bash script_name.sh`.

## Requirements

- These scripts are designed to be run on Linux systems, particularly Debian-based distributions.
- The `sudo` command may be required for certain operations, so ensure that the user has appropriate permissions.
- For `create-site.sh`, Apache web server must be installed and configured properly.

## Notes

- Ensure that you have backups of important data before using the deletion script (`delete-site.sh`).
- It's recommended to test these scripts in a development environment before using them in a production environment.
- Feel free to modify and customize these scripts according to your specific requirements.

## Author

[Your Name]

## License

This project is licensed under the [MIT License](LICENSE).

```
$ npm install --save @github/clipboard-copy-element
```
