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
peersafe_server_config="${zebra_dir}/etc/peersafe_server.json"
peersafe_server="${zebra_dir}/bin/peersafe_server"

zero=`cat "${peersafe_server_config}" | jq -r .zero`
listen_port=`cat "${peersafe_server_config}" | jq -r .port`
ip_family=`cat "${peersafe_server_config}" | jq -r .ip_family`
log_level=`cat "${peersafe_server_config}" | jq -r .log_level`

function has_peersafe_server() {
    local count=`ps -ef|grep peersafe_server|grep -v grep|grep -v sh|grep -v ssh|grep -v bash|grep -v make|wc -l`
    echo ${count}
}

function has_service() {
    local has=`netstat -nulp 2>/dev/null|grep $1|wc -l`
    echo ${has}
}

function peersafe_bootstraps() {
    local bootstraps=`cat "${peersafe_server_config}" | jq -r .bootstraps?`
    if [ "${bootstraps}" = "null" -o  "${bootstraps}" = "" ]; then
        echo ""
    else
        local nodes=""
        local length=`echo "${bootstraps}" | jq -r length`
        local index=0
        while [ ${index} -lt ${length} ]
        do
            local n=`echo "${bootstraps}" | jq -r .[${index}]`

            if [ ! -z "${nodes}" ]; then
                nodes="${nodes};${n}"
            else
                nodes="${n}"
            fi

            index=$[${index} + 1]

        done
        echo "${nodes}"
    fi
}

bootstrap=$(peersafe_bootstraps)

if [ ${zero} -eq 0 -a "${bootstrap}" = "" ]; then
    printf "${RED}non-zero peersafe must be specified bootstrap\n${NC}"
    exit 1
fi

if [ ! -f "${peersafe_server_config}" ]; then
    printf "${RED}peersafe_server.json dosen't exists in etc\n${NC}"
    exit 1
fi

if [ ! -f "${peersafe_server}" ]; then
    printf "${RED}peersafe_server dosen't exists in bin\n${NC}"
    exit 1
fi

has_peersafe_server=$(has_peersafe_server)
if [ ${has_peersafe_server} -gt 0 ]; then
    printf "${RED}peersafe_server has already run\n${NC}"
    exit 1
fi

has_service=$(has_service ${listen_port})
if [ ${has_service} -gt 0 ]; then
    printf "${RED}port ${listen_port} has already opened\n${NC}"
    exit 1
fi

while true
do
    has_peersafe_server=$(has_peersafe_server)
    if [ ${has_peersafe_server} -eq 0 ]; then

        date=`date +%Y-%m-%d`
        zebra_log_dir="${zebra_dir}/log/peersafe_server/${date}"
        mkdir -p "${zebra_log_dir}"

        error_log="${zebra_log_dir}/error_console.log"
        console_log="${zebra_log_dir}/console_log.log"

        if [ ${zero} -eq 1 ]; then
            ${peersafe_server} -f -z -${ip_family} -p ${listen_port} \
                --log_no_console --log_folder ${zebra_log_dir} --log_* ${log_level} \
                2>>${error_log} 1>>${console_log} &
        else
            ${peersafe_server} -f -${ip_family} -p ${listen_port} \
                -P ${bootstrap} --log_no_console --log_folder \
                ${zebra_log_dir} --log_* ${log_level} 2>>${error_log} 1>>${console_log} &
        fi
    fi
    sleep 60
done