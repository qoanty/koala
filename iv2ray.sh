#!/bin/bash

#======================================================
#   System Required: Debian 8+ / Ubuntu 16+ / CentOS 7+
#   Description: Manage v2ray
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

NAME="v2ray"
BINARYPATH="/usr/local/bin/${NAME}"
BINARYFILE="${BINARYPATH}/${NAME}"
CONFIGPATH="/usr/local/etc/${NAME}"
CONFIGFILE="${CONFIGPATH}/config.json"
SERVICEFILE="/etc/systemd/system/${NAME}.service"
LOGPATH="/var/log/${NAME}"
LOGFILE="${LOGPATH}/access.log"
# LOGFILE="${LOGPATH}/error.log"
TMPDIR="/tmp/${NAME}"
ZIPFILE="${TMPDIR}/${NAME}.zip"

PROXY=""
# PROXY="--socks5-hostname localhost:1080"
TAG_URL="https://api.github.com/repos/v2ray/v2ray-core/releases/latest"
DOWNLOAD="https://github.com/v2ray/v2ray-core/releases/download"
CUR_VER=""
NEW_VER=""
VDIS=""

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
    # 读（r=4），写（w=2），执行（x=1）
    # 2>/dev/null 不显示错误 >/dev/null 2>&1 标准输出和错误都不显示
    # 2>&1 >/dev/null 显示错误，不显示标准输出
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
            echo '32'
        ;;
        x86_64|amd64)
            echo '64'
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
        *s390x*)
            echo 's390x'
        ;;
        ppc64le)
            echo 'ppc64le'
        ;;
        ppc64)
            echo 'ppc64'
        ;;
        *)
            return 1
        ;;
    esac
    return 0
}

# 0: no new. 1: new version. 2: not installed. 3: check failed.
check_version() {
    VER="$(${BINARYFILE} -version 2>/dev/null)"
    RETVAL="$?"
    CUR_VER="$(echo "${VER}" | head -n 1 | cut -d " " -f2)"
    NEW_VER="$(curl ${PROXY} -H "Accept: application/json" -H "User-Agent: Mozilla/5.0 (X11; Linux x86_64; rv:74.0) Gecko/20100101 Firefox/74.0" -s "${TAG_URL}" --connect-timeout 10 | grep "tag_name" | cut -d \" -f4)"
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
    DOWNLOAD_URL="${DOWNLOAD}/${NEW_VER}/v2ray-linux-${VDIS}.zip"
    echo -e "${BLUE} 下载 ${NAME} ${DOWNLOAD_URL}${PLAIN}"
    curl ${PROXY} -L -H "Cache-Control: no-cache" -o "${ZIPFILE}" "${DOWNLOAD_URL}"
    if [[ $? != 0 ]]; then
        echo -e "${RED} 下载 ${NAME} ${NEW_VER} 失败，请检查网络设置或稍后重试${PLAIN}"
        exit 1
    fi
}

install_binary() {
    mkdir -p "${CONFIGPATH}" "${LOGPATH}"
    # -o 在不提示的情况下覆盖文件 -j 垃圾路径（不生成目录）
    unzip -oj "${ZIPFILE}" "v2ray" "v2ctl" "geoip.dat" "geosite.dat" -d "${BINARYPATH}"
    if [[ $? != 0 ]]; then
        echo -e "${RED} 复制 ${NAME} 文件错误${PLAIN}"
        exit 1
    fi
    chmod +x "${BINARYPATH}/v2ray" "${BINARYPATH}/v2ctl"
    # -s /sbin/nologin 不允许用户登录 -r 建立系统账号
    # -M 不要自动建立用户的登录目录
    useradd -s /usr/sbin/nologin -r -M ${NAME}
    chown -R ${NAME}:${NAME} "${BINARYPATH}" "${CONFIGPATH}" "${LOGPATH}"

    if [[ ! -f "${CONFIGFILE}" ]]; then
        local PORT="$((${RANDOM} + 10000))"
        local UUID="$(cat '/proc/sys/kernel/random/uuid')"
        # -p 将文件提取到管道 -q 安静模式
        unzip -pq "${ZIPFILE}" "vpoint_vmess_freedom.json" | \
        sed -e "s/10086/${PORT}/g; s/23ad6b10-8d1a-40f7-8ad0-e3e35cd38297/${UUID}/g;" - > "${CONFIGFILE}"
        if [[ $? != 0 ]]; then
            echo -e "${RED} 创建 ${NAME} 配置文件错误，请手动创建${PLAIN}"
            exit 1
        fi
        echo -e "${GREEN} PORT:${PORT}${PLAIN}"
        echo -e "${GREEN} UUID:${UUID}${PLAIN}"
    fi
    rm -rf ${TMPDIR}
}

install_service() {
    if [[ ! -f ${SERVICEFILE} ]]; then
        # unzip -oj "${ZIPFILE}" "systemd/v2ray.service" -d "/etc/systemd/system"
        cat > "${SERVICEFILE}" << EOF
[Unit]
Description=V2Ray Service
Documentation=https://www.v2ray.com/
After=network.target nss-lookup.target

[Service]
Type=simple
User=${NAME}

CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=${BINARYFILE} -config ${CONFIGFILE}
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
        systemctl daemon-reload
        systemctl enable ${NAME}
        systemctl start ${NAME}
    fi
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
            echo -e "${BLUE} 请按照需求手动修改配置文件 ${CONFIGFILE}${PLAIN}"
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
            userdel ${NAME}
            rm -rf "${BINARYPATH}" "${SERVICEFILE}"
            if [[ $? != 0 ]]; then
                echo -e "${RED} 删除 ${NAME} 失败${PLAIN}"
            else
                echo -e "${GREEN} 删除 ${NAME} 成功${PLAIN}"
                echo -e "${BLUE} 如果需要，请手动删除配置文件及日志文件${PLAIN}"
                systemctl daemon-reload
                # rm -rf "${CONFIGPATH}" "${LOGPATH}"
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
    if [[ -f ${LOGFILE} ]]; then
        tail -n 30 ${LOGFILE}
    else
        journalctl -n 20 -u ${NAME}        # 查看最新20条日志
        # journalctl --boot -u ${NAME}    # 查看启动日志
        # journalctl -f -u ${NAME}        # 查看实时日志
        # echo -e "${RED} ${NAME} 日志文件不存在${PLAIN}"
    fi
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

update_shell() {
    wget -N --no-check-certificate https://github.com/qoanty/koala/raw/master/iv2ray.sh
    if [[ $? != 0 ]]; then
        echo && echo -e "${RED} 下载脚本失败，请检查本机能否连接 Github${PLAIN}"
        before_show_menu
    else
        chmod +x iv2ray.sh && echo -e "${GREEN} 升级脚本成功，请重新运行脚本${PLAIN}" && exit 0
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

before_show_menu() {
    echo && echo -n -e "${YELLOW} 按回车返回主菜单: ${PLAIN}" && read p
    show_menu
}

show_usage() {
    echo "V2ray 管理脚本使用方法: "
    echo "------------------------------------------"
    echo "iv2ray              - 显示管理菜单"
    echo "iv2ray start        - 启动 ${NAME}"
    echo "iv2ray stop         - 停止 ${NAME}"
    echo "iv2ray restart      - 重启 ${NAME}"
    echo "iv2ray status       - 查看 ${NAME} 状态"
    echo "iv2ray enable       - 设置 ${NAME} 开机自启"
    echo "iv2ray disable      - 取消 ${NAME} 开机自启"
    echo "iv2ray log          - 查看 ${NAME} 日志"
    echo "iv2ray update       - 升级 ${NAME}"
    echo "iv2ray install      - 安装 ${NAME}"
    echo "iv2ray uninstall    - 卸载 ${NAME}"
    echo "iv2ray shell        - 升级脚本"
    echo "------------------------------------------"
}

show_menu() {
    echo -e "
  ${GREEN}${NAME} 一键管理脚本${PLAIN} ${RED}${SHELL_VER}${PLAIN}
--- https://qoant.com/2019/04/vps-with-v2ray/ ---

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
 "
    show_status
    echo && read -p " 请输入数字 [0-10]: " num

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
        *) echo -e "${BLUE} 请输入正确的数字 [0-10]${PLAIN}"
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
        *) show_usage
        ;;
    esac
else
    show_menu
fi
