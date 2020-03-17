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
peersafe_push_service_config="${zebra_dir}/etc/peersafe_push_service.json"
peersafe_push_service="${zebra_dir}/bin/peersafe_push_service"

if [ ! -f "${peersafe_push_service_config}" ]; then
    printf "${RED}peersafe_push_service_config.json dosen't exists in etc\n${NC}"
    exit 1
fi

redis=`cat "${peersafe_push_service_config}" | jq -r .redis`
log_level=`cat "${peersafe_push_service_config}" | jq -r .log_level`

function has_service() {
    local count=`ps -ef|grep "$1"|grep -v grep|grep -v sh|grep -v ssh|grep -v bash|grep -v make|wc -l`
    echo ${count}
}

function has_service() {
    local has=`netstat -nulp 2>/dev/null|grep $1|wc -l`
    echo ${has}
}

function nodes() {
    local ns=`cat "${peersafe_push_service_config}" | jq -r .$1?`
    if [ "${ns}" = "null" -o  "${ns}" = "" ]; then
        echo ""
    else
        local nodes=""
        local length=`echo "${ns}" | jq -r length`
        local index=0
        while [ ${index} -lt ${length} ]
        do
            local n=`echo "${ns}" | jq -r .[${index}]`

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

bootstrap=$(nodes "bootstraps")

if [ "${bootstrap}" = "" ]; then
    printf "${RED}non-zero peersafe must be specified bootstrap\n${NC}"
    exit 1
fi

has_peersafe_push_service=$(has_service "peersafe_push_service")
if [ ${has_peersafe_push_service} -gt 0 ]; then
    printf "${RED}peersafe_peersafe_service has already run\n${NC}"
    exit 1
fi

if [ ! -f "${peersafe_push_service}" ]; then
    printf "${RED}peersafe_push_service dosen't exists\n${NC}"
    exit 1
fi

has_pip=`pip --version 2>/dev/null|wc -l`
if [ ${has_pip} -eq 0 ]; then
    sudo apt -y install python-pip
fi

has_redis=`pip show redis 2>/dev/null|wc -l`
if [ ${has_redis} -eq 0 ]; then
    pip install redis
fi

has_requests=`pip show requests 2>/dev/null|wc -l`
if [ ${has_requests} -eq 0 ]; then
    pip install requests
fi

has_zlib=`pip show zlib 2>/dev/null|wc -l`
if [ ${has_zlib} -eq 0 ]; then
    pip install zlib
fi

has_redis=`redis-server --version|wc -l`
if [ ${has_redis} -eq 0 ]; then
    apt -y install redis-server
fi

has_redis=$(has_service "redis-server")
if [ ${has_redis} -eq 0 ]; then
    redis-server /etc/redis/redis.conf
fi

reg_appkey_script="${zebra_dir}/scripts/reg_dev_appkey.py"
python ${reg_appkey_script}

while true 
do
    # check whether push service is running
    has_peersafe_push_service=$(has_service "peersafe_push_service")
    if [ ${has_peersafe_push_service} -eq 0 ]; then

        date=`date +%Y-%m-%d`
        zebra_log_dir="${zebra_dir}/log/peersafe_push_service/${date}"
        mkdir -p "${zebra_log_dir}"

        error_log="${zebra_log_dir}/error_console.log"
        console_log="${zebra_log_dir}/console_log.log"

        ${peersafe_push_service} -R ${redis} -N "${bootstrap}" \
            --log_no_console --log_folder "${zebra_log_dir}" \
            --log_* "${log_level}" 2>"${error_log}" 1>"${console_log}" &
    fi

    # check whether umbroatcat is running
    has_umbroatcast=$(has_service "umbroadcast")
    if [ ${has_umbroatcast} -eq 0 ]; then
        zebra_log_dir="${zebra_dir}/log/peersafe_push_service/${date}"
        mkdir -p "${zebra_log_dir}"

        error_log="${zebra_log_dir}/umbroatcast_error_console.log"
        console_log="${zebra_log_dir}/umbroatcast_console_log.log"


        umbroadcast="${zebra_dir}/scripts/umbroadcast.py"
        python ${umbroadcast} -R ${redis} 1>"${console_log}" 2>"${error_log}" &
    fi
    sleep 60
done