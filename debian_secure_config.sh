#!/bin/bash

NC="\033[0m" # No Color
RED="\033[0;31m"
LRED="\033[1;31m"
LPURPLE="\033[1;35m"

SSH_CONF="/etc/ssh/sshd_config"
SYSCTL_CONF="/etc/sysctl.conf"
SOURCES_LIST="/etc/apt/sources.list"
NULL="/dev/null"

while true; do
    read -p "Which user do you want to configure ? " user
    user_id=$(id -u $user 2>/dev/null)
    if [ -z $user_id ]; then
        echo -e "User ${RED}$user${NC} does not exist."
        continue
    else
        break
    fi
done

SSH_KEYS="/home/${user}/.ssh"

echo -e "Starting configuration..."

if [ ! -f "/usr/bin/sudo" ]; then
    echo -e "\n${LRED}- SUDO -${NC}"
    while true; do
        read -p "Sudo is not installed, install sudo (y/n)? " response
        if [ "$response" = "y" ]; then
            apt-get install sudo -y >"$NULL" 2>&1
            while true; do
                read -p "Disable password request (y/n)? " response
                if [ "$response" = "y" ]; then
                    sed -i "s/.*\%sudo.*/\%sudo ALL=(ALL:ALL) NOPASSWD:ALL/g" /etc/sudoers
                    break
                elif [ "$response" = "n" ]; then
                    break
                fi
            done
            break
        elif [ "$response" = "n" ]; then
            break
        fi
    done
fi

if [ -z $(groups "$user" | grep -o "sudo") ]; then
    while true; do
        read -p "$user does not belong to the sudo group, add him (y/n)? " response
        if [ "$response" = "y" ]; then
            /usr/sbin/usermod -aG sudo "$user"
            break
        elif [ "$response" = "n" ]; then
            break
        fi
    done
fi

echo -e "\n${LRED}- Updating OS & Installing Net Packages -${NC}"

rm "$SOURCES_LIST"
cat <<EOF >"$SOURCES_LIST"
deb http://deb.debian.org/debian buster main
deb-src http://deb.debian.org/debian buster main

deb http://deb.debian.org/debian-security/ buster/updates main
deb-src http://deb.debian.org/debian-security/ buster/updates main

deb http://deb.debian.org/debian buster-updates main
deb-src http://deb.debian.org/debian buster-updates main
EOF

apt-get update 1>"$NULL"
apt-get upgrade -y 1>"$NULL"
apt-get install openssh-server -y 1>"$NULL"
apt-get install dnsutils -y 1>"$NULL"
apt-get install net-tools -y 1>"$NULL"

echo -e "OS Updated."
echo -e "\n${LRED}- SSH -${NC}"

function ssh() {
    sudo -u "$user" mkdir -p $SSH_KEYS
    cd $SSH_KEYS
    sudo -u "$user" touch known_hosts
    sudo -u "$user" ssh-keygen -t rsa -b 4096 -f $user 1>"$NULL"
    sudo -u "$user" cat ${user}.pub >authorized_keys
    sed -i "s/.*PubkeyAuthentication.*/PubkeyAuthentication yes/g" $SSH_CONF
    sed -i "s/.*AuthorizedKeysFile.*/AuthorizedKeysFile .ssh\/authorized_keys/g" $SSH_CONF
    echo -e "\n  - Your private key has been saved in ${LPURPLE}${SSH_KEYS}/${user}${NC}"
    echo -e "  - Your public key has been saved in ${LPURPLE}${SSH_KEYS}/${user}.pub${NC}\n"
    sleep 3
    while true; do
        read -p "Send the private key to a remote client (linux only) (y/n)? " response
        if [ "$response" = "y" ]; then
            read -p "Port: " scp_port
            read -p "File location [${SSH_KEYS}/${user}]: " scp_file
            scp_file=${scp_file:-${SSH_KEYS}/${user}}
            read -p "Username: " scp_username
            read -p "IP: " scp_ip
            read -p "Remote destination: " scp_destination
            if $(scp -P $scp_port $scp_file ${scp_username}@${scp_ip}:${scp_destination} >"$NULL" 2>&1); then
                echo -e "${LPURPLE}The private key has been successfully sent! Follow theses steps to secure your server:${NC} "
                echo -e "\n  - First, uncomment and set PasswordAuthentication to no in the /etc/ssh/sshd_config file."
                echo -e "  - Second, remove the private key (${SSH_KEYS}/${user}).\n"
            else
                sleep 1
                echo -e "\n${RED}An error occured, follow theses steps to get your private key:${NC} "
                ssh_error
            fi
            break
        elif [ "$response" = "n" ]; then
            echo -e "\n${LPURPLE}Follow theses steps to secure your server:${NC} "
            ssh_error
            break
        fi
    done
    sleep 3
    while true; do
        read -p "Make ${SSH_KEYS} folder immutable (y/n)? " response
        if [ "$response" = "y" ]; then
            chattr -R +i $SSH_KEYS
            break
        elif [ "$response" = "n" ]; then
            break
        fi
    done
}

function ssh_error() {
    sleep 1
    echo -e "\n  - First, make sure you copy you private key (${SSH_KEYS}/${user}) to your client with a FTP software (ex: FileZilla)."
    echo -e "  - Second, uncomment and set PasswordAuthentication to no in the /etc/ssh/sshd_config file."
    echo -e "  - Third, remove the private key (${SSH_KEYS}/${user}).\n"
    sleep 3
}

while true; do
    read -p "Modify SSH port (y/n)? " response
    if [ "$response" = "y" ]; then
        read -p "Enter SSH port: " ssh
        sed -i "10,20 s/.*Port.*/Port="${ssh}"/g" $SSH_CONF
        break
    elif [ "$response" = "n" ]; then
        break
    fi
done

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

while true; do
    read -p "Use SSH key (y/n)? " response
    if [ "$response" = "y" ]; then
        if [ -d $SSH_KEYS ]; then
            while true; do
                read -p "There is already a configuration, would you like to erase it (y/n)? " response
                if [ "$response" = "y" ]; then
                    chattr -R -i $SSH_KEYS 2>"$NULL"
                    rm -Rf $SSH_KEYS
                    ssh
                    break
                elif [ "$response" = "n" ]; then
                    break
                fi
            done
            break
        else
            ssh
            break
        fi
    elif [ "$response" = "n" ]; then
        chattr -R -i $SSH_KEYS 2>"$NULL"
        rm -Rf $SSH_KEYS
        break
    fi
done

systemctl restart sshd
sleep 1

echo -e "\n${LRED}- IPv6 -${NC}"

while true; do
    read -p "Disable IPv6 (y/n)? " response
    if [ "$response" = "y" ]; then
        sed -i "/net.ipv6.conf/d" $SYSCTL_CONF
        echo "net.ipv6.conf.all.disable_ipv6 = 1" >>$SYSCTL_CONF
        echo "net.ipv6.conf.default.disable_ipv6 = 1" >>$SYSCTL_CONF
        echo "net.ipv6.conf.lo.disable_ipv6 = 1" >>$SYSCTL_CONF
        break
    elif [ "$response" = "n" ]; then
        # delete net.ipv6.conf lines
        sed -i "/net.ipv6.conf/d" $SYSCTL_CONF
        break
    fi
done

echo -e "\n${LRED}- UFW -${NC}"

while true; do
    read -p "Install UFW firewall (y/n)? " response
    if [ "$response" = "y" ]; then
        apt-get install ufw -y >"$NULL" 2>&1
        while true; do
            read -p "Allow SSH connection (y/n)? " response
            if [ "$response" = "y" ]; then
                ssh=$(grep "Port=" $SSH_CONF | cut -c 6-11)
                /usr/sbin/ufw allow $ssh 1>"$NULL"
                break
            elif [ "$response" = "n" ]; then
                break
            fi
        done
        while true; do
            read -p "Set up default policies (y/n)? " response
            if [ "$response" = "y" ]; then
                /usr/sbin/ufw default deny incoming 1>"$NULL"
                /usr/sbin/ufw default allow outgoing 1>"$NULL"
                echo -e "${LPURPLE}Default policies changed to: deny incoming, allow outgoing.${NC}"
                break
            elif [ "$response" = "n" ]; then
                /usr/sbin/ufw default allow incoming 1>"$NULL"
                /usr/sbin/ufw default allow outgoing 1>"$NULL"
                echo -e "${LPURPLE}Default policies changed to: allow incoming, allow outgoing.${NC}"
                break
            fi
        done
        while true; do
            read -p "Disable firewall IPv6 (y/n)? " response
            if [ "$response" = "y" ]; then
                sed -i "s/.*IPV6.*/IPV6=no/g" /etc/default/ufw
                break
            elif [ "$response" = "n" ]; then
                break
            fi
        done
        echo -e "UFW Activation..."
        sleep 1
        /usr/sbin/ufw enable 1>"$NULL"
        echo -e "UFW Activated!"
        break
    elif [ "$response" = "n" ]; then
        /usr/sbin/ufw disable >"$NULL" 2>&1
        break
    fi
done

echo -e "\n${LRED}- Unattended Upgrades -${NC}"

while true; do
    read -p "Install unattended upgrades (y/n)? " response
    if [ "$response" = "y" ]; then
        apt-get install unattended-upgrades apt-listchanges -y 1>"$NULL"
        break
    elif [ "$response" = "n" ]; then
        break
    fi
done

echo -e "\nEnding configuration..."
sleep 1
echo -e "System must be restarted."
sleep 1
exit
