# Debian Secure Configuration

This script is intended to be used on a fresh Debian 10 installation. His main purpose is to easy secure the OS.

## What does the script do ?

- Restore the sources.list file with the default mirrors
- Update & upgrade
- Install sudo
- Secure SSH
- Disable IPv6
- Install UFW firewall
- Install Unattended Upgrades

## How to use it ?

```sh
$ su root
# cd /tmp
# wget https://raw.githubusercontent.com/Ph4ntom01/Debian-Secure-Config/main/debian_secure_config.sh
# chmod +x debian_secure_config.sh
# bash debian_secure_config.sh
```

## SSH key

Use a FTP software (ex: FileZilla) to get the *id_rsa* file (the private key, located at */home/[user]/.ssh/id_rsa*).

To stop bots connection attemps (if you use a VPS), set **PasswordAuthentication no** into */etc/ssh/sshd_config*.
