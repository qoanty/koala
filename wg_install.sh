#!/bin/bash

# If not specify, default meaning of return value:
# 0: Success
# 1: System error
# 2: Application error
# 3: Network error

SYSTEMCTL_CMD=$(command -v systemctl 2>/dev/null) # /bin/systemctl
SERVICE_CMD=$(command -v service 2>/dev/null) # /usr/sbin/service

#color prompt
RED="31m"      # Error message
GREEN="32m"    # Success message
YELLOW="33m"   # Warning message
BLUE="36m"     # Info message

colorEcho(){
    COLOR=$1
    echo -e "\033[${COLOR}${@:2}\033[0m"
}

# generate random port
rand(){
    min=$1
    max=$(($2-$min+1))
    num=$(cat /dev/urandom | head -n 10 | cksum | awk -F ' ' '{print $1}')
    echo $(($num%$max+$min))
}

checkRoot(){
    [[ $EUID != 0 ]] && colorEcho ${RED} "��ǰ��ROOT�˺�(��û��ROOTȨ��)���޷����������������ROOT�˺š�" && exit 1
}

checkSys(){
    if [[ -f /etc/redhat-release ]]; then
        release="centos"
    elif cat /etc/issue | grep -q -E -i "debian"; then
        release="debian"
    elif cat /etc/issue | grep -q -E -i "ubuntu"; then
        release="ubuntu"
    fi
    arch=$(uname -m)
    return 0
}

installWG(){
    if [[ ${release} = "debian" ]]; then
        echo "deb http://deb.debian.org/debian/ unstable main" > /etc/apt/sources.list.d/unstable.list
        printf 'Package: *\nPin: release a=unstable\nPin-Priority: 90\n' > /        etc/apt/preferences.d/limit-unstable
        apt update
        apt install -y wireguard resolvconf qrencode
        apt clean
        modprobe wireguard
    fi
    return 0
}

ipFWD(){
    echo 1 > /proc/sys/net/ipv4/ip_forward
    echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
    sysctl -p
    return 0
}

setConfig(){
    mkdir /etc/wireguard
    chmod 777 -R /etc/wireguard
    cd /etc/wireguard
    wg genkey | tee sprivatekey | wg pubkey > spublickey
    wg genkey | tee cprivatekey | wg pubkey > cpublickey
    ss=$(cat sprivatekey)
    sg=$(cat spublickey)
    cs=$(cat cprivatekey)
    cg=$(cat cpublickey)
    serverip=$(curl ipv4.icanhazip.com)
    port=$(rand 10000 60000)
    eth=$(ls /sys/class/net | awk '/^e/{print}')

cat > /etc/wireguard/wg0.conf <<-EOF
[Interface]
PrivateKey = $ss
Address = 10.0.0.1/24 
PostUp   = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -A FORWARD -o wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o $eth -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -D FORWARD -o wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o $eth -j MASQUERADE
ListenPort = $port
DNS = 8.8.8.8
MTU = 1420
[Peer]
PublicKey = $cg
AllowedIPs = 10.0.0.2/32
EOF

cat > /etc/wireguard/client.conf <<-EOF
[Interface]
PrivateKey = $cs
Address = 10.0.0.2/24 
DNS = 8.8.8.8
MTU = 1420
[Peer]
PublicKey = $sg
Endpoint = $serverip:$port
AllowedIPs = 0.0.0.0/0, ::0/0
PersistentKeepalive = 25
EOF

cat > /etc/init.d/wireguard <<-EOF
#! /bin/bash
### BEGIN INIT INFO
# Provides:		wireguard
# Required-Start:	$remote_fs $syslog
# Required-Stop:    $remote_fs $syslog
# Default-Start:	2 3 4 5
# Default-Stop:		0 1 6
# Short-Description:	wireguard
### END INIT INFO
wg-quick up wg0
EOF
    chmod +x "/etc/init.d/wireguard"
    update-rc.d -f wireguard defaults
    wg-quick up wg0
    codeQR
    return 0
}

codeQR(){
    content=$(cat /etc/wireguard/client.conf)
    colorEcho ${BLUE} "���Զ�������/etc/wireguard/client.conf���ֻ��˿�ֱ��ɨ�롣"
    echo "${content}" | qrencode -o - -t UTF8
    return 0
}

removeWG(){
    wg-quick down wg0
    apt remove -y wireguard
    rm -rf /etc/wireguard
    return 0
}

main(){
    echo && colorEcho ${BLUE} "1. ��װwireguard"
    colorEcho ${BLUE} "2. �鿴�ͻ��˶�ά��"
    colorEcho ${BLUE} "3. ɾ��wireguard"
    colorEcho ${BLUE} "0. �˳��ű�" && echo
    stty erase '^H' && read -p "����������:" num
    case "$num" in
        0)
        exit 0
        ;;
        1)
        #installWG
        setConfig
        ;;
        2)
        codeQR
        ;;
        3)
        #removeWG
        ;;
        *)
        echo "��������ȷ����"
        ;;
        esac
}

main
