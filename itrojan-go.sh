#!/bin/bash

# set -x

#======================================================
#   System Required: Debian 8+ / Ubuntu 16+ / CentOS 7+
#   Description: Manage trojan-go
#   Author: qoant
#   Blog: https://qoant.com
#   Github: https://github.com/qoanty/koala
#======================================================

RED="\033[0;31m"      # Error message
GREEN="\033[0;32m"    # Success message
YELLOW="\033[0;33m"   # Warning message
BLUE="\033[0;36m"     # Info message
PLAIN="\033[0m"

SHELL_VER="v1.0.0.1"

NAME="trojan-go"
BINARYPATH="/usr/local/bin/${NAME}"
BINARYFILE="${BINARYPATH}/${NAME}"
CONFIGPATH="/usr/local/etc/${NAME}"
CONFIGFILE="${CONFIGPATH}/config.json"
SERVICEFILE="/etc/systemd/system/${NAME}.service"
SSLPATH="/usr/local/ssl/${NAME%-*}"
TMPDIR="/tmp/${NAME}"
TARFILE=""

PROXY=""
#PROXY="--socks5-hostname localhost:1080"
#TAG_URL="https://api.github.com/repos/p4gefau1t/trojan-go/releases/latest"
TAG_URL="https://api.github.com/repos/p4gefau1t/trojan-go/releases"
DOWNLOAD="https://github.com/p4gefau1t/trojan-go/releases/download"
CUR_VER=""
NEW_VER=""
VDIS=""
OS=""
DOMAIN="197774.xyz"

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

install_base() {
    if [[ -n $(command -v apt 2>/dev/null) ]]; then
        apt install -y -qq curl wget tar unzip net-tools >/dev/null 2>&1
    elif [[ -n $(command -v yum 2>/dev/null) ]]; then
        yum install wget curl tar unzip -y >/dev/null 2>&1
    else
        echo -e "${YELLOW} 请使用 Debian 8+ / Ubuntu 16+ / CentOS 7+ 系统！${PLAIN}\n" && exit 1
    fi
}

get_arch() {
    case "$(uname -m)" in
        i686|i386)
            echo '386'
        ;;
        x86_64|amd64)
            echo 'amd64'
        ;;
        *armv7*|armv6l)
            echo 'arm'
        ;;
        *armv8*|aarch64)
            echo 'arm64'
        ;;
        *mips64le*)
            echo 'mips64le'
        ;;
        *mips64*)
            echo 'mips64'
        ;;
        *mipsle*)
            echo 'mipsle'
        ;;
        *mips*)
            echo 'mips'
        ;;
        *)
            return 1
        ;;
    esac
    return 0
}

get_os() {
    case "$(tr '[:lower:]' '[:upper:]' <<<$(uname))" in
        *LINUX*)
            echo 'linux'
        ;;
        *FREEBSD*)
            echo 'freebsd'
        ;;
        *OPENBSD*)
            echo 'openbsd'
        ;;
        *)
            return 1
        ;;
    esac
    return 0
}

# 0: no new. 1: new version. 2: not installed. 3: check failed.
check_version() {
    VER="$(${BINARYFILE} -v 2>/dev/null)"
    RETVAL="$?"
    CUR_VER="$(echo "${VER}" | head -n 1 | awk '{print $2}')"
    NEW_VER="$(curl ${PROXY} -H "Accept: application/json" -H "User-Agent: Mozilla/5.0 (X11; Linux x86_64; rv:74.0) Gecko/20100101 Firefox/74.0" -s "${TAG_URL}" --connect-timeout 10 | grep "tag_name" | head -n 1 | cut -d \" -f4)"
    if [[ $? != 0 ]] || [[ ${NEW_VER} == "" ]]; then
        return 3
    elif [[ ${RETVAL} != 0 ]]; then
        return 2
    elif [[ ${NEW_VER} != ${CUR_VER} ]]; then
        return 1
    fi
    return 0
}

download() {
    rm -rf ${TMPDIR} && mkdir -p ${TMPDIR}
    VDIS="$(get_arch)"
    OS="$(get_os)"
    TARBALL="${NAME}-${OS}-${VDIS}.zip"
    TARFILE="${TMPDIR}/${TARBALL}"
    DOWNLOAD_URL="${DOWNLOAD}/${NEW_VER}/${TARBALL}"
    echo -e "${BLUE} 下载 ${NAME} ${DOWNLOAD_URL}${PLAIN}"
    curl ${PROXY} -L -H "Cache-Control: no-cache" -o "${TARFILE}" "${DOWNLOAD_URL}"
    if [[ $? != 0 ]]; then
        echo -e "${RED} 下载 ${NAME} ${NEW_VER} 失败，请检查网络设置或稍后重试${PLAIN}"
        exit 1
    fi
}

install_binary() {
    mkdir -p "${CONFIGPATH}" "${SSLPATH}"
    unzip -oj "${TARFILE}" "${NAME}" "geoip.dat" "geosite.dat" -d "${BINARYPATH}"
    if [[ $? != 0 ]]; then
        echo -e "${RED} 复制 ${NAME} 文件错误${PLAIN}"
        exit 1
    fi
    chmod +x "${BINARYFILE}"
    # -s /sbin/nologin 不允许用户登录
    # -r 建立系统账号 -M 不要自动建立用户的登录目录
    useradd -s /usr/sbin/nologin -r -M ${NAME%-*}
    chown -R ${NAME%-*}:${NAME%-*} "${BINARYFILE}" "${CONFIGPATH}" "${SSLPATH}"

    if [[ ! -f "${CONFIGFILE}" ]]; then
        cat > "${CONFIGFILE}" << EOF
{
    "run_type": "server",
    "local_addr": "0.0.0.0",
    "local_port": 443,
    "remote_addr": "127.0.0.1",
    "remote_port": 80,
    "password": [
        "fuckgfw"
    ],
    "ssl": {
        "cert": "${SSLPATH}/xyz.cer",
        "key": "${SSLPATH}/xyz.key",
        "sni": "${DOMAIN}"
    },
    "websocket": {
        "enabled": false,
        "path": "/ws",
        "host": "${DOMAIN}"
    },
    "router":{
        "enabled": true,
        "block": [
            "geoip:private"
        ]
    }
}
EOF
        echo -e "${BLUE} 配置文件已生成，请手动修改密码及证书路径${PLAIN}"
    fi
    rm -rf ${TMPDIR}
}

install_service() {
    if [[ ! -f ${SERVICEFILE} ]]; then
        cat > "${SERVICEFILE}" << EOF
[Unit]
Description=${NAME}
Documentation=https://github.com/p4gefau1t/${NAME}
After=network.target nss-lookup.target
Wants=network-online.target

[Service]
Type=simple
User=${NAME%-*}
ExecStart=${BINARYFILE} -config ${CONFIGFILE}
Restart=on-failure
RestartSec=15

CapabilityBoundingSet=CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_BIND_SERVICE
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF
        systemctl daemon-reload
        systemctl enable ${NAME}
        systemctl start ${NAME}
    fi
    echo && confirm " 是否要配置 Caddyfile 文件?"
    if [[ $? == 0 ]]; then
        set_caddy
    fi
}

set_caddy() {
    CADDYFILE="/usr/local/etc/caddy/Caddyfile"
    if [[ -f ${CADDYFILE} ]]; then
        cp "${CADDYFILE}" "${CADDYFILE}.bak"
    fi
    cat > "${CADDYFILE}" << EOF
http://${DOMAIN}, http://www.${DOMAIN} {
    gzip
    root /var/www
    browse
}
EOF
    systemctl restart caddy
}

install() {
    check_status
    if [[ $? == 2 ]]; then
        check_version
        if [[ $? != 3 ]]; then
            echo && echo -e "${BLUE} 安装 ${NAME} ${NEW_VER}${PLAIN}"
            install_base
            download
            install_binary
            install_service
            echo -e "${GREEN} 已成功安装${PLAIN}"
        else
            echo -e "${RED} 获取 ${NAME} 版本失败，请检查网络设置或稍后重试 ${PLAIN}"
        fi
    else
        echo && echo -e "${YELLOW} ${NAME} 已安装，请不要重复安装${PLAIN}"
    fi
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

uninstall() {
    check_status
    if [[ $? != 2 ]]; then
        echo && confirm " 确定要卸载 ${NAME} ?"
        if [[ $? == 0 ]]; then
            systemctl stop ${NAME}
            systemctl disable ${NAME}
            userdel ${NAME%-*}
            rm -rf "${BINARYFILE}" "${SERVICEFILE}"
            if [[ $? != 0 ]]; then
                echo -e "${RED} 删除 ${NAME} 失败${PLAIN}"
            else
                echo -e "${GREEN} 删除 ${NAME} 成功${PLAIN}"
                echo -e "${BLUE} 如果需要，请手动删除配置文件及证书文件${PLAIN}"
                systemctl daemon-reload
                # rm -rf "${CONFIGPATH}" "${SSLPATH}"
            fi
        else
            echo -e "${YELLOW} 已取消${PLAIN}"
        fi
    else
        echo && echo -e "${YELLOW} 请先安装 ${NAME}${PLAIN}"
    fi
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

update() {
    check_version
    RETVAL="$?"
    if [[ ${RETVAL} == 0 ]]; then
       echo && echo -e "${GREEN} 当前 ${NAME} 已是最新版本 ${NEW_VER}${PLAIN}"
    elif [[ ${RETVAL} == 1 ]]; then
        echo && confirm " ${NAME} 当前版本为 ${CUR_VER}，发现新版本 ${NEW_VER}，是否升级?"
        if [[ $? == 0 ]]; then
            uninstall 0
            install 0
            echo -e "${GREEN} ${NAME} ${NEW_VER} 已安装${PLAIN}"
        else
            echo -e "${YELLOW} 已取消${PLAIN}"
        fi
    elif [[ ${RETVAL} == 3 ]]; then
        echo && echo -e "${RED} 获取 ${NAME} 版本失败，请稍后重试 ${PLAIN}"
    elif [[ ${RETVAL} == 2 ]]; then
        echo && echo -e "${GREEN} ${NAME} 未安装，当前最新版本为 ${NEW_VER}${PLAIN}"
    fi
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

do_start() {
    check_status
    if [[ $? == 0 ]]; then
        echo && echo -e "${GREEN} ${NAME} 已运行，无需再次启动${PLAIN}"
    else
        systemctl start ${NAME}
        sleep 2
        check_status
        if [[ $? == 0 ]]; then
            echo -e "${GREEN} ${NAME} 启动成功${PLAIN}"
        else
            echo -e "${RED} ${NAME} 启动失败，请查看日志信息${PLAIN}"
            journalctl -xe
        fi
    fi
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

do_stop() {
    check_status
    if [[ $? == 1 ]]; then
        echo && echo -e "${GREEN} ${NAME} 已停止，无需再次停止${PLAIN}"
    else
        systemctl stop ${NAME}
        sleep 2
        check_status
        if [[ $? == 1 ]]; then
            echo -e "${GREEN} ${NAME} 停止成功${PLAIN}"
        else
            echo -e "${RED} ${NAME} 停止失败，请查看日志信息${PLAIN}"
            journalctl -xe
        fi
    fi
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

do_restart() {
    check_status
    if [[ $? == 2 ]]; then
        echo && echo -e "${YELLOW} 请先安装 ${NAME}${PLAIN}"
    else
        systemctl restart ${NAME}
        sleep 2
        check_status
        if [[ $? == 0 ]]; then
            echo -e "${GREEN} ${NAME} 重启成功${PLAIN}"
        else
            echo -e "${RED} ${NAME} 重启失败，请查看日志信息${PLAIN}"
            journalctl -xe
        fi
    fi
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

do_status() {
    check_status
    if [[ $? != 2 ]]; then
        systemctl status ${NAME} -l
    fi
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

do_enable() {
    check_enabled
    if [[ $? == 1 ]]; then
        systemctl enable ${NAME}
        if [[ $? == 0 ]]; then
            echo -e "${GREEN} ${NAME} 设置开机自启成功${PLAIN}"
        else
            echo -e "${RED} ${NAME} 设置开机自启失败${PLAIN}"
        fi
    fi
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

do_disable() {
    check_enabled
    if [[ $? == 0 ]]; then
        systemctl disable ${NAME}
        if [[ $? == 0 ]]; then
            echo -e "${GREEN} ${NAME} 取消开机自启成功${PLAIN}"
        else
            echo -e "${RED} ${NAME} 取消开机自启失败${PLAIN}"
        fi
    fi
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

view_log() {
    check_status
    if [[ $? != 2 ]]; then
        # journalctl --boot -u ${NAME}    # 查看启动日志
        journalctl -n 20 -u ${NAME}        # 查看最新日志
    fi
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

update_shell() {
    wget -N --no-check-certificate https://github.com/qoanty/koala/raw/master/itrojan-go.sh
    if [[ $? != 0 ]]; then
        echo && echo -e "${RED} 下载脚本失败，请检查本机能否连接 Github${PLAIN}"
        before_show_menu
    else
        chmod +x itrojan-go.sh && echo -e "${GREEN} 升级脚本成功，请重新运行脚本${PLAIN}" && exit 0
    fi
}

# 0: running. 1: not running. 2: not installed
check_status() {
    if [[ ! -f ${SERVICEFILE} ]]; then
        return 2
    fi
    if pgrep ${NAME} >/dev/null ; then
        return 0
    else
        return 1
    fi
}

check_enabled() {
    case "$(systemctl is-enabled ${NAME} 2>/dev/null)" in
        enabled)
            return 0
        ;;
        disabled)
            return 1
        ;;
        *)
            return 2
        ;;
    esac
}

show_enable_status() {
    check_enabled
    case $? in
        0)
        echo -e "${BLUE} 是否开机自启: ${GREEN}是${PLAIN}"
        ;;
        1)
        echo -e "${BLUE} 是否开机自启: ${RED}否${PLAIN}"
        ;;
        2)
        echo -e "${RED} 请确认是否安装 ${NAME}${PLAIN}"
        ;;
    esac
}

show_status() {
    check_status
    case $? in
        0)
        echo -e "${GREEN} ${NAME} 已运行${PLAIN}" && show_enable_status
        ;;
        1)
        echo -e "${YELLOW} ${NAME} 未运行${PLAIN}" && show_enable_status
        ;;
        2)
        echo -e "${RED} ${NAME} 未安装${PLAIN}"
        ;;
    esac
}

get_ssl() {
    echo -e "${BLUE} 使用手动 cloudflare dns 方式生成证书${PLAIN}"
    #echo -n -e "${YELLOW} 请输入域名: ${PLAIN}" && read DOMAIN
    if [[ ! -d ~/.acme.sh ]]; then
        curl  https://get.acme.sh | sh
        source .bashrc
    fi
    export CF_Key="1167f76592eb80c725a4669373b5d2ec44c90"
    export CF_Email="qoanty@gmail.com"
    acme.sh --issue --dns dns_cf -d "${DOMAIN}" -d "www.${DOMAIN}"
    acme.sh --installcert -d "${DOMAIN}" \
        --key-file "${SSLPATH}/${DOMAIN%.*}.key" \
        --fullchain-file "${SSLPATH}/${DOMAIN%.*}.cer"
    acme.sh --upgrade --auto-upgrade
    echo -e "${GREEN} 证书已申请并安装到相应的位置，需手动修改配置文件${PLAIN}"
}

before_show_menu() {
    echo && echo -n -e "${YELLOW} 按回车返回主菜单: ${PLAIN}" && read p
    show_menu
}

show_usage() {
    echo "Trojan-go 管理脚本使用方法: "
    echo "------------------------------------------"
    echo "itrojan-go              - 显示管理菜单"
    echo "itrojan-go start        - 启动 ${NAME}"
    echo "itrojan-go stop         - 停止 ${NAME}"
    echo "itrojan-go restart      - 重启 ${NAME}"
    echo "itrojan-go status       - 查看 ${NAME} 状态"
    echo "itrojan-go enable       - 设置 ${NAME} 开机自启"
    echo "itrojan-go disable      - 取消 ${NAME} 开机自启"
    echo "itrojan-go log          - 查看 ${NAME} 日志"
    echo "itrojan-go update       - 升级 ${NAME}"
    echo "itrojan-go install      - 安装 ${NAME}"
    echo "itrojan-go uninstall    - 卸载 ${NAME}"
    echo "itrojan-go shell        - 升级脚本"
    echo "itrojan-go ssl          - 申请证书"
    echo "------------------------------------------"
}

show_menu() {
    echo -e "
  ${GREEN}${NAME} 一键管理脚本${PLAIN} ${RED}${SHELL_VER}${PLAIN}
--- https://qoant.com/2020/06/vps-with-trojan-go/ ---

  ${GREEN}0.${PLAIN} 退出脚本
————————————————
  ${GREEN}1.${PLAIN} 安装 ${NAME}
  ${GREEN}2.${PLAIN} 升级 ${NAME}
  ${GREEN}3.${PLAIN} 卸载 ${NAME}
————————————————
  ${GREEN}4.${PLAIN} 启动 ${NAME}
  ${GREEN}5.${PLAIN} 停止 ${NAME}
  ${GREEN}6.${PLAIN} 重启 ${NAME}
————————————————
  ${GREEN}7.${PLAIN} 查看 状态信息
  ${GREEN}8.${PLAIN} 查看 日志信息
————————————————
  ${GREEN}9.${PLAIN} 设置 ${NAME} 开机自启
 ${GREEN}10.${PLAIN} 取消 ${NAME} 开机自启
 ${GREEN}11.${PLAIN} 用 acme.sh 申请证书
 "
    show_status
    echo && read -p " 请输入数字 [0-11]: " num

    case "${num}" in
        0) exit 0
        ;;
        1) install
        ;;
        2) update
        ;;
        3) uninstall
        ;;
        4) do_start
        ;;
        5) do_stop
        ;;
        6) do_restart
        ;;
        7) do_status
        ;;
        8) view_log
        ;;
        9) do_enable
        ;;
        10) do_disable
        ;;
        11) get_ssl
        ;;
        *) echo -e "${BLUE} 请输入正确的数字 [0-11]${PLAIN}"
        ;;
    esac
}

if [[ $# > 0 ]]; then
    case $1 in
        "start") do_start 0
        ;;
        "stop") do_stop 0
        ;;
        "restart") do_restart 0
        ;;
        "status") do_status 0
        ;;
        "enable") do_enable 0
        ;;
        "disable") do_disable 0
        ;;
        "log") view_log 0
        ;;
        "update") update 0
        ;;
        "install") install 0
        ;;
        "uninstall") uninstall 0
        ;;
        "shell") update_shell
        ;;
        "ssl") get_ssl
        ;;
        *) show_usage
        ;;
    esac
else
    show_menu
fi
