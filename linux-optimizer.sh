#!/bin/bash


clear


# Green, Yellow & Red Messages.
green_msg() {
    tput setaf 2
    echo "[*] ----- $1"
    tput sgr0
}

yellow_msg() {
    tput setaf 3
    echo "[*] ----- $1"
    tput sgr0
}

red_msg() {
    tput setaf 1
    echo "[*] ----- $1"
    tput sgr0
}


# Paths
HOST_PATH="/etc/hosts"
DNS_PATH="/etc/resolv.conf"


# Repo source. Distro scripts are fetched from here.
REPO="LivingG0D/linux-optimizer"
BRANCH="main"


# Download a repo file with a hard timeout, trying GitHub raw first and the
# jsDelivr CDN mirror as a fallback (raw.githubusercontent.com is filtered on
# some networks, e.g. Iran, where it would otherwise hang forever).
# Usage: fetch_repo_file <path-in-repo> <output-file>
fetch_repo_file() {
    local path="$1"
    local out="$2"
    local url
    local urls=(
        "https://raw.githubusercontent.com/${REPO}/${BRANCH}/${path}"
        "https://cdn.jsdelivr.net/gh/${REPO}@${BRANCH}/${path}"
    )

    for url in "${urls[@]}"; do
        if wget --timeout=15 --tries=2 -q -O "$out" "$url" && [ -s "$out" ]; then
            green_msg "Downloaded ${out}."
            return 0
        fi
        yellow_msg "Source unreachable, trying next mirror..."
    done

    red_msg "Failed to download ${path} from all sources. Check network/DNS and retry."
    return 1
}


# Intro
echo 
green_msg '================================================================='
green_msg 'This script will automatically Optimize your Linux Server.'
green_msg 'Tested on: Ubuntu 20+, Debian 11+, CentOS stream 8+, AlmaLinux 8+, Fedora 37+'
green_msg 'Root access is required.' 
green_msg 'Source is @ https://github.com/LivingG0D/linux-optimizer' 
green_msg '================================================================='
echo 


# Check Root Function
check_if_running_as_root() {
    # If you want to run as another user, please modify $EUID to be owned by this user
    if [[ "$EUID" -ne '0' ]]; then
      echo 
      red_msg 'Error: You must run this script as root!'
      echo 
      sleep 0.5
      exit 1
    fi
}


# Run Check Root
check_if_running_as_root
sleep 0.5


# Install dependencies
install_dependencies_debian_based() {
  echo 
  yellow_msg 'Installing Dependencies...'
  echo 
  sleep 0.5
  
  apt update -q
  apt install -yq wget curl sudo jq

  echo
  green_msg 'Dependencies Installed.'
  echo 
  sleep 0.5
}


# Install dependencies
install_dependencies_rhel_based() {
  echo 
  yellow_msg 'Installing Dependencies...'
  echo 
  sleep 0.5

  # dnf up -y
  dnf install -y wget curl sudo jq
  
  echo
  green_msg 'Dependencies Installed.'
  echo 
  sleep 0.5
}


# Fix Hosts file
fix_etc_hosts(){ 
  echo 
  yellow_msg "Fixing Hosts file."
  sleep 0.5

  cp $HOST_PATH /etc/hosts.bak
  yellow_msg "Default hosts file saved. Directory: /etc/hosts.bak"
  sleep 0.5

  if ! grep -q $(hostname) $HOST_PATH; then
    echo "127.0.1.1 $(hostname)" | sudo tee -a $HOST_PATH > /dev/null
    green_msg "Hosts Fixed."
    echo 
    sleep 0.5
  else
    green_msg "Hosts OK. No changes made."
    echo 
    sleep 0.5
  fi
}


# Fix DNS Temporarily
fix_dns(){
    echo 
    yellow_msg "Fixing DNS Temporarily."
    sleep 0.5

    cp $DNS_PATH /etc/resolv.conf.bak
    yellow_msg "Default resolv.conf file saved. Directory: /etc/resolv.conf.bak"
    sleep 0.5

    sed -i '/nameserver/d' $DNS_PATH

    echo "nameserver 1.1.1.2" >> $DNS_PATH
    echo "nameserver 1.0.0.2" >> $DNS_PATH
    echo "nameserver 127.0.0.53" >> $DNS_PATH

    green_msg "DNS Fixed Temporarily."
    echo 
    sleep 0.5
}


# Set the server TimeZone to the VPS IP address location.
set_timezone() {
    echo
    yellow_msg 'Setting TimeZone based on VPS IP address...'
    sleep 0.5

    get_location_info() {
        local ip_sources=("https://ipv4.icanhazip.com" "https://api.ipify.org" "https://ipv4.ident.me/")
        local location_info

        for source in "${ip_sources[@]}"; do
            local ip=$(curl -s "$source")
            if [ -n "$ip" ]; then
                location_info=$(curl -s "http://ip-api.com/json/$ip")
                if [ -n "$location_info" ]; then
                    echo "$location_info"
                    return 0
                fi
            fi
        done

        red_msg "Error: Failed to fetch location information from known sources. Setting timezone to UTC."
        sudo timedatectl set-timezone "UTC"
        return 1
    }

    # Fetch location information from three sources
    location_info_1=$(get_location_info)
    location_info_2=$(get_location_info)
    location_info_3=$(get_location_info)

    # Extract timezones from the location information
    timezones=($(echo "$location_info_1 $location_info_2 $location_info_3" | jq -r '.timezone'))

    # Check if at least two timezones are equal
    if [[ "${timezones[0]}" == "${timezones[1]}" || "${timezones[0]}" == "${timezones[2]}" || "${timezones[1]}" == "${timezones[2]}" ]]; then
        # Set the timezone based on the first matching pair
        timezone="${timezones[0]}"
        sudo timedatectl set-timezone "$timezone"
        green_msg "Timezone set to $timezone"
    else
        red_msg "Error: Failed to fetch consistent location information from known sources. Setting timezone to UTC."
        sudo timedatectl set-timezone "UTC"
    fi

    echo
    sleep 0.5
}


# OS Detection
if [[ $(grep -oP '(?<=^NAME=").*(?=")' /etc/os-release) == "Ubuntu" ]]; then
    OS="ubuntu"
    echo 
    sleep 0.5
    yellow_msg "OS: Ubuntu"
    echo 
    sleep 0.5
elif [[ $(grep -oP '(?<=^NAME=").*(?=")' /etc/os-release) == "Debian GNU/Linux" ]]; then
    OS="debian"
    echo 
    sleep 0.5
    yellow_msg "OS: Debian"
    echo 
    sleep 0.5
elif [[ $(grep -oP '(?<=^NAME=").*(?=")' /etc/os-release) == "CentOS Stream" ]]; then
    OS="centos"
    echo 
    sleep 0.5
    yellow_msg "OS: Centos Stream"
    echo 
    sleep 0.5
elif [[ $(grep -oP '(?<=^NAME=").*(?=")' /etc/os-release) == "AlmaLinux" ]]; then
    OS="almalinux"
    echo 
    sleep 0.5
    yellow_msg "OS: AlmaLinux"
    echo 
    sleep 0.5
elif [[ $(grep -oP '(?<=^NAME=").*(?=")' /etc/os-release) == "Fedora Linux" ]]; then
    OS="fedora"
    echo 
    sleep 0.5
    yellow_msg "OS: Fedora"
    echo 
    sleep 0.5
else
    echo 
    sleep 0.5
    red_msg "Unknown OS, Create an issue here: https://github.com/LivingG0D/linux-optimizer"
    OS="unknown"
    echo 
    sleep 2
fi


## Run

# Install dependencies
if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
    install_dependencies_debian_based
elif [[ "$OS" == "centos" || "$OS" == "fedora" || "$OS" == "almalinux" ]]; then
    install_dependencies_rhel_based
fi


# Fix Hosts file
fix_etc_hosts
sleep 0.5

# Fix DNS
fix_dns
sleep 0.5

# Timezone
set_timezone
sleep 0.5


# Run Script based on Distros
case $OS in
ubuntu)
    # Ubuntu
    fetch_repo_file "scripts/ubuntu-optimizer.sh" "ubuntu-optimizer.sh" && chmod +x ubuntu-optimizer.sh && bash ubuntu-optimizer.sh
    ;;
debian)
    # Debian
    fetch_repo_file "scripts/debian-optimizer.sh" "debian-optimizer.sh" && chmod +x debian-optimizer.sh && bash debian-optimizer.sh
    ;;
centos)
    # CentOS
    fetch_repo_file "scripts/centos-optimizer.sh" "centos-optimizer.sh" && chmod +x centos-optimizer.sh && bash centos-optimizer.sh
    ;;
almalinux)
    # AlmaLinux (uses the CentOS script)
    fetch_repo_file "scripts/centos-optimizer.sh" "almalinux-optimizer.sh" && chmod +x almalinux-optimizer.sh && bash almalinux-optimizer.sh
    ;;
fedora)
    # Fedora
    fetch_repo_file "scripts/fedora-optimizer.sh" "fedora-optimizer.sh" && chmod +x fedora-optimizer.sh && bash fedora-optimizer.sh
    ;;
unknown)
    # Unknown
    exit 
    ;;
esac

