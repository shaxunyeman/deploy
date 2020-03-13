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
peersafe_box_config="${zebra_dir}/etc/peersafe_box.json"
peersafe_box_api_config="${zebra_dir}/etc/config.yaml"
peersafe_box_path="${zebra_dir}/bin/box"
peersafe_box="${peersafe_box_path}/peersafe_box"
peersafe_box_api="${peersafe_box_path}/ShadowBox"

zero=`cat "${peersafe_box_config}" | jq -r .zero`
listen_port=`cat "${peersafe_box_config}" | jq -r .port`
ip_family=`cat "${peersafe_box_config}" | jq -r .ip_family`
log_level=`cat "${peersafe_box_config}" | jq -r .log_level`
rest_api_ip=`cat "${peersafe_box_config}" | jq -r .rest_api_ip`
rest_api_port=`cat "${peersafe_box_config}" | jq -r .rest_api_port`
rest_api_protocol=`cat "${peersafe_box_config}" | jq -r .rest_api_protocol`

function has_peersafe_box() {
    local count=`netstat -nulp 2>/dev/null|grep ${listen_port}|wc -l`
    echo ${count}
}

function has_peersafe_box_api() {
    local count=`netstat -ntlp 2>/dev/null | grep ${rest_api_port}| wc -l`
    echo ${count}
}

#function has_service() {
#    local has=`netstat -nulp 2>/dev/null|grep $1|wc -l`
#    echo ${has}
#}

function nodes() {
    local ns=`cat "${peersafe_box_config}" | jq -r .$1?`
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


if [ ! -f "${peersafe_box_config}" ]; then
    printf "${RED}peersafe_box.json dosen't exists in etc\n${NC}"
    exit 1
fi

has_peersafe_box=$(has_peersafe_box)
if [ ${has_peersafe_box} -gt 0 ]; then
    printf "${RED}peersafe_box has already run\n${NC}"
    exit 1
fi

#has_service=$(has_service ${listen_port})
#if [ ${has_service} -gt 0 ]; then
#    printf "${RED}port ${listen_port} has already opened\n${NC}"
#    exit 1
#fi

if [ ! -f "${peersafe_box}" ]; then
    if [ ! -f "${zebra_dir}/bin/peersafe_server" ]; then
        printf "${RED}peersafe_server dosen't exits\n${NC}"
        exit
    fi
    if [ ! -d "${peersafe_box_path}" ]; then
        mkdir -p "${peersafe_box_path}"
    fi
    cp ${zebra_dir}/bin/peersafe_server ${peersafe_box}
fi

if [ ! -f "${peersafe_box_api}" ]; then
    if [ ! -f "${zebra_dir}/bin/ShadowBox" ]; then
        printf "${RED}ShadowBox dosen't exits\n${NC}"
        exit
    fi

    if [ ! -f "${peersafe_box_api_config}" ]; then
        printf "${RED}${peersafe_box_api_config} dosen't exits\n${NC}"
        exit
    fi

    ln -s ${zebra_dir}/bin/ShadowBox ${peersafe_box_api}
fi

pass="${peersafe_box_path}/PASS"   
if [ ! -f "${pass}" ]; then
    ${peersafe_box} --init -${ip_family}| tail -n 1 > ${pass}
    cp "${zebra_dir}/boxinfo" "${peersafe_box_path}"
    cp "${zebra_dir}/.passwd" "${peersafe_box_path}"
fi
box_password=`cat ${pass}`

while true 
do
    has_peersafe_box_api=$(has_peersafe_box_api)
    if [ ${has_peersafe_box_api} -eq 0 ]; then
        date=`date +%Y-%m-%d`
        zebra_log_dir="${zebra_dir}/log/shadowbox/${date}"
        mkdir -p "${zebra_log_dir}"

        error_log="${zebra_log_dir}/error_console.log"
        console_log="${zebra_log_dir}/console_log.log"
        ${peersafe_box_api} -configPath ${peersafe_box_api_config} 1>>"${console_log}" 2>>"${error_log}" &
    fi

    has_peersafe_box=$(has_peersafe_box)
    if [ ${has_peersafe_box} -eq 0 ]; then

        date=`date +%Y-%m-%d`
        zebra_log_dir="${zebra_dir}/log/peersafe_box/${date}"
        mkdir -p "${zebra_log_dir}"

        error_log="${zebra_log_dir}/error_console.log"
        console_log="${zebra_log_dir}/console_log.log"

        peersafe_relay=$(nodes "peersafe_relay")
        cache_arg=""
        if [ ! -z "${peersafe_relay}" ]; then
            cache_arg="--cache "${peersafe_relay}""
        fi

        ${peersafe_box} ${cache_arg} -${ip_family} --uploadbox ${box_password} \
        -p ${listen_port} -P "${bootstrap}" --rest_api_ip ${rest_api_ip} --rest_api_port ${rest_api_port} \
        --rest_api_protocol "${rest_api_protocol}" --log_no_console \
        --log_folder "${zebra_log_dir}" --log_* "${log_level}" 2>"${error_log}" 1>"${console_log}" &
    fi
    sleep 60
done
