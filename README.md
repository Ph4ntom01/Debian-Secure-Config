# Debian Secure Configuration

This script is intended to be used on a fresh Debian 10 installation. His main purpose is to easily secure the OS.

## What does the script do ?

- Restore the sources.list file with the default mirrors
- Update & upgrade
- Install sudo
- Secure SSH
- Disable IPv6
- Install UFW firewall
- Install Unattended Upgrades

## How to use it ?

```
$ su root
# cd /tmp
# wget https://raw.githubusercontent.com/Ph4ntom01/Debian-Secure-Config/main/debian_secure_config.sh
# chmod +x debian_secure_config.sh
# bash debian_secure_config.sh
```

## SSH key

To secure your server, either copy the private key to the remote client by using the script, or follow theses steps :

- First, make sure you copy you private key (located at _/home/[user]/.ssh/[user]_) to your client with a FTP software (ex: FileZilla).
- Second, uncomment and set **PasswordAuthentication** to **no** in the _/etc/ssh/sshd_config_ file.
- Third, remove the private key from the server.
