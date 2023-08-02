#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}错误：${plain} 必须使用root用户运行此脚本！\n" && exit 1

# check os
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
else
    echo -e "${red}未检测到系统版本，请联系脚本作者！${plain}\n" && exit 1
fi

arch=$(arch)

if [[ $arch == "x86_64" || $arch == "x64" || $arch == "amd64" ]]; then
  arch="64"
elif [[ $arch == "aarch64" || $arch == "arm64" ]]; then
  arch="arm64-v8a"
else
  arch="64"
  echo -e "${red}检测架构失败，使用默认架构: ${arch}${plain}"
fi

echo "架构: ${arch}"

if [ "$(getconf WORD_BIT)" != '32' ] && [ "$(getconf LONG_BIT)" != '64' ] ; then
    echo "本软件不支持 32 位系统(x86)，请使用 64 位系统(x86_64)，如果检测有误，请联系作者"
    exit 2
fi

os_version=""

# os version
if [[ -f /etc/os-release ]]; then
    os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
fi
if [[ -z "$os_version" && -f /etc/lsb-release ]]; then
    os_version=$(awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
fi

if [[ x"${release}" == x"centos" ]]; then
    if [[ ${os_version} -le 6 ]]; then
        echo -e "${red}请使用 CentOS 7 或更高版本的系统！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        echo -e "${red}请使用 Ubuntu 16 或更高版本的系统！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red}请使用 Debian 8 或更高版本的系统！${plain}\n" && exit 1
    fi
fi

warp_end="off"


install_base() {
    if [[ x"${release}" == x"centos" ]]; then
        yum install epel-release -y
        yum install wget curl unzip tar crontabs socat jq -y
    else
        apt update -y
        apt install wget curl unzip tar cron socat jq -y
    fi
    # speedtest
    if command -v speedtest >/dev/null 2>&1;then
        echo "已安装speedtest"
    else
        wget https://file.myluckys.org/file/speedtest-$arch -O /usr/bin/speedtest && chmod +x /usr/bin/speedtest
        echo "已安装speedtest"
    fi
}

function parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --ip)
                ip="$2"
                shift
                shift
                ;;
            *)
                echo "Unknown argument: $1"
                exit 1
        esac
    done
}

function main() {
    speed_result=`speedtest -f json --accept-gdpr --accept-license|jq .upload.bandwidth`
    rtt=`ping -c 10 $ip |grep rtt |awk '{print $4}' |awk -F'/' '{print $2}'`
    all_mem=`awk '($1 == "MemTotal:"){print $2/1024}' /proc/meminfo`
    mem_page=`getconf PAGE_SIZE`
    speed_result_mbps=$(($speed_result/125000))
    echo "speed_result:${speed_result_mbps}Mbps rtt:${rtt} System_mem:${all_mem} Mem_Page:${mem_page}"
    wget "https://tools.myrelays.org/sysctl_conf/?speed_result=$speed_result&rtt=$rtt&all_mem=$all_mem&mem_page=$mem_page" -O /etc/sysctl.conf
    sysctl -p
}

parse_args "$@"
install_base
main