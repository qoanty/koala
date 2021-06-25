#!/bin/bash

# set -x

#======================================================
#   System Required: Debian 8+ / Ubuntu 16+ / CentOS 7+
#   Description: Simple VPS Manager
#   Author: qoant
#======================================================

RED="\033[0;31m"      # Error message
GREEN="\033[0;32m"    # Success message
YELLOW="\033[0;33m"   # Warning message
BLUE="\033[0;36m"     # Info message
PLAIN="\033[0m"

SHELL_VER="v1.0.0.3"

LIST=(xray v2ray nginx caddy trojan brook trojan-go kms)
CADDYFILE="/usr/local/etc/caddy/Caddyfile"

DOMAIN="197774.xyz"
VPSIP="107.172.207.230"
VWSPATH="/ws"
VPORT="10088"
XWSPATH="/websocket"
XPORT="10888"
CADDYCER="/usr/local/ssl/caddy/197774.cer"
CADDYKEY="/usr/local/ssl/caddy/197774.key"
CERFILE="/usr/local/ssl/xray/xyz.cer"
KEYFILE="/usr/local/ssl/xray/xyz.key"
NGINXFILE="/etc/nginx/sites-available/${DOMAIN}"

DOMAIN="qoant.com"
VPSIP="192.3.122.87"
VWSPATH="/ws"
VPORT="13000"
XWSPATH="/websocket"
XPORT="18000"
CADDYCER="/usr/local/ssl/caddy/qoant.cer"
CADDYKEY="/usr/local/ssl/caddy/qoant.key"
CERFILE="/usr/local/ssl/xray/qoant.cer"
KEYFILE="/usr/local/ssl/xray/qoant.key"
NGINXFILE="/etc/nginx/sites-available/${DOMAIN}"

# check root
[[ ${EUID} != 0 ]] && echo -e "${RED} 错误: ${PLAIN}必须使用root用户运行此脚本！\n" && exit 1

confirm() {
    while true; do
        read -p "$1 [y/n] " yn
        case ${yn} in
            [Yy] ) return 0 ;;
            [Nn]|"" ) return 1 ;;
        esac
    done
}

set_trojan_caddy() {
    check_status caddy
    if [[ $? == 0 ]]; then
        systemctl stop caddy
    fi
    sleep 1
    cat > "${CADDYFILE}" << EOF
http://${DOMAIN}, http://www.${DOMAIN} {
    gzip
    root /var/www
    browse
}
EOF
    systemctl start caddy
}

set_ray_caddy() {
    check_status caddy
    if [[ $? == 0 ]]; then
        systemctl stop caddy
    fi
    sleep 1
    cat > "${CADDYFILE}" << EOF
http://${DOMAIN}, http://www.${DOMAIN} {
    redir https://${DOMAIN}{url}
}

https://${DOMAIN}, https://www.${DOMAIN} {
    gzip
    timeouts none
    root /var/www
    tls ${CADDYCER} ${CADDYKEY}
    fastcgi / /run/php/php7.0-fpm.sock php
    # proxy / https://www.debian.org/
    proxy ${VWSPATH} localhost:${VPORT} {
        websocket
        header_upstream -Origin
    }
    proxy ${XWSPATH} localhost:${XPORT} {
        websocket
        header_upstream -Origin
    }
}
EOF
    systemctl start caddy
}

stop_all() {
    systemctl stop caddy
    systemctl stop nginx
    systemctl stop xray
    systemctl stop v2ray
    systemctl stop trojan
    systemctl stop trojan-go
}

use_xray() {
    stop_all
    set_ray_caddy
    systemctl start xray
    sleep 2
    main
}

use_v2ray() {
    stop_all
    set_ray_caddy
    systemctl start v2ray
    sleep 2
    main
}

use_trojan() {
    stop_all
    set_trojan_caddy
    systemctl start trojan
    sleep 2
    main
}

use_trojan_go() {
    stop_all
    set_trojan_caddy
    systemctl start trojan-go
    sleep 2
    main
}

use_xray_ng() {
    stop_all
    set_ray_nginx
    systemctl start xray
    sleep 2
    main
}

use_v2ray_ng() {
    stop_all
    set_ray_nginx
    systemctl start v2ray
    sleep 2
    main
}

use_trojan_ng() {
    stop_all
    set_trojan_nginx
    systemctl start trojan
    sleep 2
    main
}

use_trojan_go_ng() {
    stop_all
    set_trojan_nginx
    systemctl start trojan-go
    sleep 2
    main
}

# 0: running. 1: not running. 2: not installed
check_status() {
    # if ! which $1 >/dev/null; then
    if [[ ! -f "/etc/systemd/system/$1.service" ]] && [[ ! -f "/lib/systemd/system/$1.service" ]]; then
        return 2
    fi
    if pgrep $1 >/dev/null ; then
        return 0
    else
        return 1
    fi
}

show_status() {
    check_status $1
    case $? in
        0)
        echo -e "${GREEN}  $1 已运行${PLAIN}"
        ;;
        1)
        echo -e "${YELLOW}  $1 未运行${PLAIN}"
        ;;
        2)
        echo -e "${RED}  $1 未安装${PLAIN}"
        ;;
    esac
}

check_all() {
    for NAME in ${LIST[*]}; do
        show_status ${NAME}
    done
}

in_caddy() {
    echo && confirm "  确定安装 caddy ?"
    if [[ $? == 0 ]]; then
        wget -N --no-check-certificate https://raw.githubusercontent.com/qoanty/koala/master/icaddy.sh && bash icaddy.sh && exit 0
    fi
}

in_xray() {
    echo && confirm "  确定安装 xray ?"
    if [[ $? == 0 ]]; then
        wget -N --no-check-certificate https://raw.githubusercontent.com/qoanty/koala/master/ixray.sh && bash ixray.sh && exit 0
    fi
}

in_v2ray() {
    echo && confirm "  确定安装 v2ray ?"
    if [[ $? == 0 ]]; then
        wget -N --no-check-certificate https://raw.githubusercontent.com/qoanty/koala/master/iv2ray.sh && bash iv2ray.sh && exit 0
    fi
}

in_trojan() {
    echo && confirm "  确定安装 trojan ?"
    if [[ $? == 0 ]]; then
        wget -N --no-check-certificate https://raw.githubusercontent.com/qoanty/koala/master/itrojan.sh && bash itrojan.sh && exit 0
    fi
}

in_trojan_go() {
    echo && confirm "  确定安装 trojan-go ?"
    if [[ $? == 0 ]]; then
        wget -N --no-check-certificate https://raw.githubusercontent.com/qoanty/koala/master/itrojan-go.sh && bash igrojan-go.sh && exit 0
    fi
}

before_main() {
    echo && echo -n -e "${YELLOW}  按回车返回主菜单: ${PLAIN}" && read p
    main
}

main() {
    echo -e "
  ${GREEN}VPS 管理脚本${PLAIN} ${RED}${SHELL_VER}${PLAIN}

  ${GREEN}0.${PLAIN} 退出脚本
————————————————————————————
  ${GREEN}1.${PLAIN} 使用 xray + caddy
  ${GREEN}2.${PLAIN} 使用 xray + nginx
  ${GREEN}3.${PLAIN} 使用 v2ray + caddy
  ${GREEN}4.${PLAIN} 使用 v2ray + nginx
————————————————————————————
  ${GREEN}5.${PLAIN} 使用 trojan + caddy
  ${GREEN}6.${PLAIN} 使用 trojan-go + caddy
  ${GREEN}7.${PLAIN} 使用 trojan + nginx
  ${GREEN}8.${PLAIN} 使用 trojan-go + nginx
————————————————————————————
  ${GREEN}9.${PLAIN} 安装 xray
  ${GREEN}9.${PLAIN} 安装 v2ray
 ${GREEN}10.${PLAIN} 安装 trojan
 ${GREEN}11.${PLAIN} 安装 trojan-go
 ${GREEN}12.${PLAIN} 安装 caddy
  "
    check_all
    echo && read -p "  请输入数字 [0-10]: " num
    case "${num}" in
        0) exit 0
        ;;
        1) use_xray
        ;;
        2) use_xray_ng
        ;;
        3) use_v2ray
        ;;
        4) use_v2ray_ng
        ;;
        5) use_trojan
        ;;
        6) use_trojan_go
        ;;
        7) use_trojan_ng
        ;;
        8) use_trojan_go_ng
        ;;
        9) in_xray
        ;;
        10) in_v2ray
        ;;
        10) in_trojan
        ;;
        11) in_trojan_go
        ;;
        12) in_caddy
        ;;
        *) echo -e "${BLUE}  请输入正确的数字 [0-10]${PLAIN}"
        ;;
    esac
}

set_trojan_nginx() {
    cat > "${NGINXFILE}" <<EOF
server {
	listen 127.0.0.1:80 default_server;

	server_name ${DOMAIN} www.${DOMAIN};

	root /var/www;

	# Add index.php to the list if you are using PHP
	index index.html index.htm;

	location / {
		# First attempt to serve request as file, then
		# as directory, then fall back to displaying a 404.
		#proxy_pass https://www.debian.org;
		try_files \$uri \$uri/ =404;
	}

	# pass PHP scripts to FastCGI server
	#
	location ~ \.php\$ {
	#	include snippets/fastcgi-php.conf;
	#
		# With php-fpm (or other unix sockets):
		fastcgi_pass unix:/var/run/php/php7.0-fpm.sock;
		# With php-cgi (or other tcp sockets):
		#fastcgi_pass 127.0.0.1:9000;
		root /var/www;
		fastcgi_index index.php;
		fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
		include fastcgi_params;
	}
}

server {
	listen 127.0.0.1:80;

	server_name ${VPSIP};

	root /var/www;
	index index.html;

	return 301 https://${DOMAIN}\$request_uri;

	#location / {
	#	try_files \$uri \$uri/ =404;
	#}
}

server {
	listen 0.0.0.0:80;
	listen [::]:80;

	server_name _;

	return 301 https://\$host\$request_uri;
}
EOF
    systemctl restart nginx
}

set_ray_nginx() {
    cat > "${NGINXFILE}" <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN} www.${DOMAIN};
    return 301 https://\$server_name\$request_uri;
}

server {
	listen 443 ssl http2;
    listen [::]:443 ssl http2;
	server_name ${DOMAIN} www.${DOMAIN};

	root /var/www;

	# Add index.php to the list if you are using PHP
	index index.html index.htm;

    ssl_certificate ${CERFILE};
    ssl_certificate_key ${KEYFILE};
    ssl_session_timeout 5m;
    ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
    ssl_prefer_server_ciphers on;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_session_cache builtin:1000 shared:SSL:10m;

	location / {
		# First attempt to serve request as file, then
		# as directory, then fall back to displaying a 404.
		#proxy_pass https://www.debian.org;
		try_files \$uri \$uri/ =404;
	}

	location ${VWSPATH} {
		proxy_redirect off;
		proxy_pass http://127.0.0.1:${VPORT};
		proxy_http_version 1.1;
		proxy_set_header Upgrade \$http_upgrade;
		proxy_set_header Connection "upgrade";
		proxy_set_header Host \$http_host;
	}

    location ${XWSPATH} {
		proxy_redirect off;
		proxy_pass http://127.0.0.1:${XPORT};
		proxy_http_version 1.1;
		proxy_set_header Upgrade \$http_upgrade;
		proxy_set_header Connection "upgrade";
		proxy_set_header Host \$http_host;
	}

	location ~ \.php\$ {
		#include snippets/fastcgi-php.conf;

		# With php-fpm (or other unix sockets):
		fastcgi_pass unix:/var/run/php/php7.0-fpm.sock;
		# With php-cgi (or other tcp sockets):
		#fastcgi_pass 127.0.0.1:9000;
		root /var/www;
		fastcgi_index index.php;
		fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
		include fastcgi_params;
	}
}
EOF
    systemctl restart nginx
}

main
