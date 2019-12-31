#!/bin/bash

#Black        0;30     Dark Gray     1;30
#Red          0;31     Light Red     1;31
#Green        0;32     Light Green   1;32
#Brown/Orange 0;33     Yellow        1;33
#Blue         0;34     Light Blue    1;34
#Purple       0;35     Light Purple  1;35
#Cyan         0;36     Light Cyan    1;36
#Light Gray   0;37     White         1;37

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

zebra_dir=`pwd`
peersafe_relay_config="${zebra_dir}/etc/peersafe_relay.json"
peersafe_relay="${zebra_dir}/bin/peersafe_relay"

zero=`cat "${peersafe_relay_config}" | jq -r .zero`
listen_port=`cat "${peersafe_relay_config}" | jq -r .port`
user=`cat "${peersafe_relay_config}" | jq -r .user`
passwd=`cat "${peersafe_relay_config}" | jq -r .passwd`

function has_peersafe_relay() {
    local count=`ps -ef|grep peersafe_relay|grep -v grep|grep -v sh|grep -v ssh|grep -v bash|grep -v make|wc -l`
    echo ${count}
}

function has_service() {
    local has=`netstat -nulp 2>/dev/null|grep $1|wc -l`
    echo ${has}
}

if [ ! -f "${peersafe_relay_config}" ]; then
    printf "${RED}peersafe_relay.json dosen't exists in etc\n${NC}"
    exit 1
fi

if [ ! -f "${peersafe_relay}" ]; then
    printf "${RED}peersafe_relay dosen't exists in bin\n${NC}"
    exit 1
fi

has_peersafe_relay=$(has_peersafe_relay)
if [ ${has_peersafe_relay} -gt 0 ]; then
    printf "${RED}peersafe_relay has already run\n${NC}"
    exit 1
fi

has_service=$(has_service ${listen_port})
if [ ${has_service} -gt 0 ]; then
    printf "${RED}port ${listen_port} has already opened\n${NC}"
    exit 1
fi

if [ "${user}" = "" -o "${passwd}" = "" ]; then
    printf "${RED}please specify user or password\n${NC}"
    exit 1
fi

while true
do
    has_peersafe_relay=$(has_peersafe_relay)
    if [ ${has_peersafe_relay} -eq 0 ]; then
        date=`date +%Y-%m-%d`
        zebra_log_dir="${zebra_dir}/log/peersafe_relay/${date}"
        mkdir -p "${zebra_log_dir}"

        error_log="${zebra_log_dir}/error_console.log"
        console_log="${zebra_log_dir}/console_log.log"
        ${peersafe_relay} -b -e ${listen_port} -t $[${listen_port} + 1] \
            -u ${user} -p ${passwd} 2>>${error_log} 1>>${console_log} &
    fi
    sleep 60 
done