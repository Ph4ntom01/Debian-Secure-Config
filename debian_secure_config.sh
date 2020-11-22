#!/bin/bash

SSH_CONF="/etc/ssh/sshd_config"
SYSCTL_CONF="/etc/sysctl.conf"
SOURCES_LIST="/etc/apt/sources.list"

while true; do
    read -p "Which user do you want to configure ? " user
    if id "$user" > /dev/null 2>&1; then
        cd /home/${user}
        break
    else
        echo "User does not exist."
        continue
    fi
done

echo -e "\nStarting configuration...\n"
echo -e "Updating OS...\n"
sleep 1

rm $SOURCES_LIST
cat << EOF > $SOURCES_LIST
deb http://deb.debian.org/debian buster main
deb-src http://deb.debian.org/debian buster main

deb http://deb.debian.org/debian-security/ buster/updates main
deb-src http://deb.debian.org/debian-security/ buster/updates main

deb http://deb.debian.org/debian buster-updates main
deb-src http://deb.debian.org/debian buster-updates main
EOF

apt update && apt upgrade -y
apt install openssh-server -y
apt install dnsutils -y
apt install net-tools -y

echo -e "OS updated.\n"
echo -e "******************************************************************************\n"

while true; do
    read -p "Install sudo (y/n)? " response
    if [ "$response" = "y" ]; then
        apt install sudo -y
        echo -e "\n"
        while true; do
            read -p "Disable password request (y/n)? " response
            if [ "$response" = "y" ]; then
                sed -i "s/.*\%sudo.*/\%sudo ALL=(ALL:ALL) NOPASSWD:ALL/g" /etc/sudoers
                break
            elif [ "$response" = "n" ]; then break
            fi
        done
        break
    elif [ "$response" = "n" ]; then break
    fi
done

echo -e "\n"

while true; do
    read -p "Add $user as a sudo user (y/n)? " response
    if [ "$response" = "y" ]; then
        adduser $user sudo
        break
    elif [ "$response" = "n" ]; then break
    fi
done

echo -e "\n******************************************************************************\n"

while true; do
    read -p "Modify SSH port (y/n)? " response
    if [ "$response" = "y" ]; then
        read -p "Enter port for SSH: " ssh
        sed -i "10,20 s/.*Port.*/Port="${ssh}"/g" $SSH_CONF
        break
    elif [ "$response" = "n" ]; then break
    fi
done

echo -e "\n"

while true; do
    read -p "Permit root login (y/n)? " response
    if [ "$response" = "y" ]; then
        sed -i "20,40 s/.*PermitRootLogin.*/PermitRootLogin yes/g" $SSH_CONF
        break
    elif [ "$response" = "n" ]; then
        sed -i "20,40 s/.*PermitRootLogin.*/PermitRootLogin no/g" $SSH_CONF
        break
    fi
done

echo -e "\n"

while true; do
    read -p "Use SSH key (y/n)? " response
    if [ "$response" = "y" ]; then
        mkdir -p .ssh && chown ${user}:${user} .ssh
        cd .ssh
        ssh-keygen -t rsa -b 4096 -f $user
        mv $user id_rsa
        mv ${user}.pub id_rsa.pub
        cat id_rsa.pub > authorized_keys
        chown ${user}:${user} id_rsa id_rsa.pub authorized_keys
        sed -i "s/root/${user}/g" id_rsa.pub
        sed -i "s/root/${user}/g" authorized_keys
        sed -i "s/.*PubkeyAuthentication.*/PubkeyAuthentication yes/g" $SSH_CONF
        sed -i "s/.*AuthorizedKeysFile.*/AuthorizedKeysFile .ssh\/authorized_keys/g" $SSH_CONF
        echo -e "\n"
        echo -e "After the installation, make sure you copy you private key (/home/${user}/.ssh/id_rsa) to your client with a FTP software (ex: FileZilla).\n\n"
        sleep 3
        while true; do
            read -p "Make .ssh folder immutable (y/n)? " response
            if [ "$response" = "y" ]; then
                cd ..
                chattr -R +i .ssh
                break
            elif [ "$response" = "n" ]; then break
            fi
        done
        break
    elif [ "$response" = "n" ]; then break
    fi
done

service sshd restart
sleep 1

echo -e "\n******************************************************************************\n"

while true; do
    read -p "Disable IPv6 (y/n)? " response
    if [ "$response" = "y" ]; then
        sed -i "/net.ipv6.conf/d" $SYSCTL_CONF
        echo "net.ipv6.conf.all.disable_ipv6=1" >> $SYSCTL_CONF
        echo "net.ipv6.conf.default.disable_ipv6=1" >> $SYSCTL_CONF
        echo "net.ipv6.conf.lo.disable_ipv6=1" >> $SYSCTL_CONF
        break
    elif [ "$response" = "n" ]; then break
    fi
done

echo -e "\n"

while true; do
    read -p "Install UFW firewall (y/n)? " response
    if [ "$response" = "y" ]; then
        apt install ufw -y
        echo -e "\n"
        while true; do
            read -p "Allow SSH connection (y/n)? " response
            if [ "$response" = "y" ]; then
                ssh=$(grep "Port=" $SSH_CONF | cut -c 6-11)
                echo "SSH port is: "${ssh}
                ufw allow $ssh
                break
            elif [ "$response" = "n" ]; then break
            fi
        done
        while true; do
            echo -e "\n"
            read -p "Set up default policies (y/n)? " response
            if [ "$response" = "y" ]; then
                ufw default deny incoming
                ufw default allow outgoing
                break
            elif [ "$response" = "n" ]; then break
            fi
        done
        echo -e "\n"
        while true; do
            read -p "Disable IPV6 (y/n) ? " response
            if [ "$response" = "y" ]; then
                sed -i "s/.*IPV6.*/IPV6=no/g" /etc/default/ufw
                break
            elif [ "$response" = "n" ]; then break
            fi
        done
        echo -e "\nUFW Activation ..."
        sleep 3
        ufw enable
        break
    elif [ "$response" = "n" ]; then break
    fi
done

echo -e "\n******************************************************************************\n"

while true; do
    read -p "Enable unattended upgrades ? " response
    if [ "$response" = "y" ]; then
        sudo apt-get install unattended-upgrades apt-listchanges -y
        echo 'APT::Periodic::Update-Package-Lists "1";' >> /etc/apt/apt.conf.d/20auto-upgrades
        echo 'APT::Periodic::Unattended-Upgrade "1";' >> /etc/apt/apt.conf.d/20auto-upgrades
        break
    elif [ "$response" = "n" ]; then break
    fi
done

echo -e "\nDone. System must be restarted...\n"
sleep 1
exit 0
