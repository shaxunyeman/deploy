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

has_jq=`jq --version 2>/dev/null|wc -l`
if [ ${has_jq} -eq 0 ]; then
    printf "${GREEN}install jq${NC}\n"
    sudo apt-get -y install jq
fi

services_tar_name="peersafe_zebra_service.tar.gz"
deploy_log="deploy.log"

declare -a DEFUALT_SERVICES_ARRAY
declare -a SERVICES_ARRAY

COMMAND=""
disable_zero=0
zero_node=1
bootstrap=""
which_remote_node=-1
deploy_config="config.json"
rewrite_configuration=0
rewrite_executable_scripts=0

DEFUALT_SERVICES_ARRAY=("${DEFUALT_SERVICES_ARRAY[@]}" "peersafe_server" "peersafe_box" "ShadowBox" "peersafe_relay")

function usage() {
    echo "usage: "
    echo " deploy command [service] [option]"
    echo
    echo " commands"
    echo "  start       start a service"
    echo "  update      update a service"
    echo "  stop        stop a service"
    echo "  show        show status of a service"
    echo "  remove      remove zebra directory"
    echo "  upload      upload a executable service"
    echo "  dep         install dependencies"
    echo "  install     install peersafe services"
    echo "  annouce     annouce/fetch/remove peersafe_relays to/from zebra network"
    echo
    echo " services"
    echo "  peersafe_server"
    echo "  peersafe_relay"
    echo "  peersafe_box"
    echo "  peersafe_push"
    echo
    echo " options"
    echo "  -c|--config specify config, defualt ${deploy_config}"
    echo "  -i|--which  where executes instructions"
    echo "  -w,c  rewrite configuration"
    echo "  -w,s  rewrite executable scripts"
    echo "  --bootstrap hosts1[;hosts2]     specify a bootstrap nodes, only for peersafe_server"
    echo
    echo "examples:"
    echo " peersafe_zebra start                         start all services"
    echo " peersafe_zebra start peersafe_server         start a peersafe_server"
    echo " peersafe_zebra start peersafe_server -i 0    start a peersafe_server on specified remote by i"
    echo " peersafe_zebra stop                          stop all services"
    echo " peersafe_zebra show                          show all status of running services"
    echo
}

function nodes() {
    local nodes=`cat ${deploy_config} | jq -r .$1| jq -r .hosts`
    echo "${nodes}"
}

function node() {
    local nodes="$1"
    local index="$2"
    local node=`echo ${nodes} | jq -r .[${index}]`

    echo "${node}"
}

function ip() {
    local node="$1"
    local ip=`echo ${node} | jq -r .ip`

    echo "${ip}"
}

function port() {
    local node="$1"
    local port=`echo ${node} | jq -r .port`

    echo "${port}"
}

function user() {
    local node="$1"
    local user=`echo ${node} | jq -r .user`

    echo "${user}"
}

function key() {
    local node="$1"
    local key=`echo ${node} | jq -r .key?`

    echo "${key}"
}

function passwd() {
    local node="$1"
    local passwd=`echo ${node} | jq -r .passwd?`

    echo "${passwd}"
}

function service_log_level() {
    local port=`cat ${deploy_config} | jq -r .$1| jq -r .log_level`
    echo ${port}
}

function service_port() {
    local port=`cat ${deploy_config} | jq -r .$1| jq -r .port`
    echo ${port}
}

function service_ip_family() {
    local ip_family=`cat ${deploy_config} | jq -r .$1| jq -r .ip_family?`
    echo ${ip_family}
}

function peersafe_relay_user() {
    local user=`cat ${deploy_config} | jq -r .peersafe_relay | jq -r .user`
    echo "${user}"
}

function peersafe_relay_passwd() {
    local passwd=`cat ${deploy_config} | jq -r .peersafe_relay | jq -r .passwd`
    echo "${passwd}"
}

function disable_zero() {
    local disable=`cat ${deploy_config} | jq -r .peersafe_server | jq -r .disable_zero`
    echo ${disable}
}

function setup_script() {
    local node="$1"
    local service_name="$2"
    local config="$3"

    local ip=$(ip "${node}")
    local port=$(port "${node}")
    local user=$(user "${node}")
    local key=$(key "${node}")

    # copy config into remote host
    peersafe_config="${zebra_dir}/etc/${service_name}.json"
    has_config=`ssh -i "${key}" ${user}@${ip} -p ${port} \
        "[ -f "${peersafe_config}" ] && echo "exists" || echo "not exists"" 2>/dev/null`

    echo "${config}" > /tmp/${service_name}.json
    if [ "${has_config}" = "not exists" ]; then
        scp -i "${key}" "/tmp/${service_name}.json" "${user}@${ip}:${peersafe_config}"
    else
        # rewrite configuration ?
        if [ ${rewrite_configuration} -eq 1 ]; then
            has_config=`ssh -i "${key}" ${user}@${ip} -p ${port} \
                    "[ -f "${peersafe_config}" ] && rm -f "${peersafe_config}"" 2>/dev/null`

            scp -i "${key}" "/tmp/${service_name}.json" "${user}@${ip}:${peersafe_config}"
        fi
    fi
    rm -f /tmp/${service_name}.json

    if [ "${service_name}" = "peersafe_box" ]; then
        shadwoBox_api_config="${zebra_dir}/etc/config.yaml"
        has_config=`ssh -i "${key}" ${user}@${ip} -p ${port} \
            "[ -f "${shadwoBox_api_config}" ] && echo "exists" || echo "not exists"" 2>/dev/null`

        echo "$4" > /tmp/config.yaml
        if [ "${has_config}" = "not exists" ]; then
            scp -i "${key}" "/tmp/config.yaml" "${user}@${ip}:${shadwoBox_api_config}"
        else
            # rewrite configuration ?
            if [ ${rewrite_configuration} -eq 1 ]; then
                has_config=`ssh -i "${key}" ${user}@${ip} -p ${port} \
                        "[ -f "${shadwoBox_api_config}" ] && rm -f "${shadwoBox_api_config}"" 2>/dev/null`

                scp -i "${key}" "/tmp/config.yaml" "${user}@${ip}:${shadwoBox_api_config}"
            fi
        fi
        rm -f /tmp/config.yaml
    fi

    # copy script into remote host
    script="${zebra_dir}/scripts/${service_name}.sh"
    has_script=`ssh -i "${key}" ${user}@${ip} -p ${port} \
        "[ -f "${script}" ] && echo "exists" || echo "not exists"" 2>/dev/null`

    if [ "${has_script}" = "not exists" ]; then
        scp -i "${key}" "./scripts/${service_name}.sh" "${user}@${ip}:${script}"
    else
        # rewrite scripts ?
        if [ ${rewrite_executable_scripts} -eq 1 ]; then
            has_config=`ssh -i "${key}" ${user}@${ip} -p ${port} \
                    "[ -f "${script}" ] && rm -f "${script}"" 2>/dev/null`

            scp -i "${key}" "./scripts/${service_name}.sh" "${user}@${ip}:${script}"
        fi
    fi
}

function start_peersafe_server() {
    local node="$1"
    local service_name="$2"

    local ip_protocol=$(service_ip_family "${service_name}")
    local listen_port=$(service_port "${service_name}")
    local log_level=$(service_log_level "${service_name}")

    local disable_zero=$(disable_zero)

    if [ "${disable_zero}" == "1" ]; then
        zero_node=0
    fi

    local ip=$(ip "${node}")
    local port=$(port "${node}")
    local user=$(user "${node}")
    local key=$(key "${node}")
    local config=""

    if [ "${bootstrap}" = "" ]; then
config=$(< <(cat <<EOF
{
    "zero":${zero_node},
    "port":${listen_port},
    "ip_family":${ip_protocol},
    "log_level":"${log_level}",
    "bootstraps":`cat ${deploy_config} | jq -r .${service_name}| jq -r .bootstraps?`
}
EOF
))
    else
config=$(< <(cat <<EOF
{
    "zero":${zero_node},
    "port":${listen_port},
    "ip_family":${ip_protocol},
    "log_level":"${log_level}",
    "bootstraps":`echo "{\"bootstraps\":[\"${bootstrap}\"]}" | jq -r .bootstraps`
}
EOF
))

    fi

    # setup script on remote host
    $(setup_script "${node}" "${service_name}" "${config}")

    # start peersafe_server on remote host
    ssh -i "${key}" ${user}@${ip} -p ${port} \
    "cd ${zebra_dir};./peersafe_zebra.sh start ${service_name}"

    if [ "${zero_node}" = "1" ]; then
        zero_node=0
    fi
}

function start_peersafe_box() {
    local node="$1"
    local service_name="$2"

    local ip=$(ip "${node}")
    local port=$(port "${node}")
    local user=$(user "${node}")
    local key=$(key "${node}")

    local ip_protocol=$(service_ip_family "${service_name}")
    local listen_port=$(service_port "${service_name}")
    local log_level=$(service_log_level "${service_name}")

    local rest_api_ip=`cat ${deploy_config} | jq -r .peersafe_box | jq -r .rest_api_ip`
    local rest_api_port=`cat ${deploy_config} | jq -r .peersafe_box | jq -r .rest_api_port`
    local rest_api_protocol=`cat ${deploy_config} | jq -r .peersafe_box | jq -r .rest_api_protocol`
    local config=""

    if [ "${bootstrap}" = "" ]; then
config=$(< <(cat <<EOF
{
    "port":${listen_port},
    "ip_family":${ip_protocol},
    "log_level":"${log_level}",
    "rest_api_ip":"${rest_api_ip}",
    "rest_api_port":${rest_api_port},
    "rest_api_protocol":"${rest_api_protocol}",
    "bootstraps":`cat ${deploy_config} | jq -r .${service_name}| jq -r .bootstraps?`,
    "peersafe_relay":`cat ${deploy_config} | jq -r .${service_name}| jq -r .peersafe_relays?`
}
EOF
))
    else
config=$(< <(cat <<EOF
{
    "port":${listen_port},
    "ip_family":${ip_protocol},
    "log_level":"${log_level}",
    "rest_api_ip":"${rest_api_ip}",
    "rest_api_port":${rest_api_port},
    "rest_api_protocol":"${rest_api_protocol}",
    "bootstraps":`echo "{\"bootstraps\":[\"${bootstrap}\"]}" | jq -r .bootstraps`,
    "peersafe_relay":`cat ${deploy_config} | jq -r .${service_name}| jq -r .peersafe_relays?`
}
EOF
))
    fi

shadowBox_api_config=$(< <(cat <<EOF
# Server's listening port
extern:
  port: ${rest_api_port}

resource:
  boxInfoPath: "./boxinfo"
  passwdPath: "./.passwd"
  contactsPath: "./contactsfile"

default:
  debugSign: true
  logLevel: "DEBUG"
EOF
))
    # setup script on remote host
    $(setup_script "${node}" "${service_name}" "${config}" "${shadowBox_api_config}")

    # start a peersafe_box
    ssh -i "${key}" ${user}@${ip} -p ${port} \
    "cd ${zebra_dir};./peersafe_zebra.sh start ${service_name}"
}

function start_peersafe_relay() {
    local node="$1"
    local service_name="$2"

    local ip=$(ip "${node}")
    local port=$(port "${node}")
    local user=$(user "${node}")
    local key=$(key "${node}")

    local listen_port=$(service_port "${service_name}")
    local ip_protocol=$(service_ip_family "${service_name}")
    local ice_user=$(peersafe_relay_user)
    local ice_passwd=$(peersafe_relay_passwd)

config=$(< <(cat <<EOF
{
    "port":${listen_port},
    "ip_family":${ip_protocol},
    "user":"${ice_user}",
    "passwd":"${ice_passwd}"
}
EOF
))

    # setup script on remote host
    $(setup_script "${node}" "${service_name}" "${config}")

    # start a peersafe_relay
    ssh -i "${key}" ${user}@${ip} -p ${port} \
    "cd ${zebra_dir};./peersafe_zebra.sh start ${service_name}"
}

function start_peersafe_push_service() {
    local node="$1"
    local service_name="$2"

    local ip=$(ip "${node}")
    local port=$(port "${node}")
    local user=$(user "${node}")
    local key=$(key "${node}")

    local log_level=$(service_log_level "${service_name}")
    local redis=`cat ${deploy_config} | jq -r .${service_name}| jq -r .redis`
    local config=""

    if [ "${bootstrap}" = "" ]; then
config=$(< <(cat <<EOF
{
    "redis":"127.0.0.1:6379",
    "log_level":"${log_level}",
    "bootstraps":`cat ${deploy_config} | jq -r .${service_name}| jq -r .bootstraps?`
}
EOF
))
    else
config=$(< <(cat <<EOF
{
    "redis":"127.0.0.1:6379",
    "log_level":"${log_level}",
    "bootstraps":`echo "{\"bootstraps\":[\"${bootstrap}\"]}" | jq -r .bootstraps`
}
EOF
))
    fi

    $(setup_script "${node}" "${service_name}" "${config}")

    # copy umbroatcast.py into remote host
    umbroatcast_script="${zebra_dir}/scripts/umbroadcast.py"
    has_script=`ssh -i "${key}" ${user}@${ip} -p ${port} \
        "[ -f "${umbroatcast_script}" ] && echo "exists" || echo "not exists"" 2>/dev/null`
    if [ "${has_script}" = "not exists" ]; then
        scp -i "${key}" "./scripts/umbroadcast.py" "${user}@${ip}:${umbroatcast_script}"
    fi

    # copy reg_dev_appkey.py into remote host
    appkey_script="${zebra_dir}/scripts/reg_dev_appkey.py"
    has_appkey_script=`ssh -i "${key}" ${user}@${ip} -p ${port} \
        "[ -f "${appkey_script}" ] && echo "exists" || echo "not exists"" 2>/dev/null`
    if [ "${has_appkey_script}" = "not exists" ]; then
        scp -i "${key}" "./scripts/reg_dev_appkey.py" "${user}@${ip}:${appkey_script}"
    fi

    # start a peersafe_push_service
    ssh -t -i "${key}" ${user}@${ip} -p ${port} \
    "cd ${zebra_dir};./peersafe_zebra.sh start ${service_name}"
}

function start() {
    local length=${#SERVICES_ARRAY[@]}
    if [ ${length} -eq 0 ]; then
        # show all services' status
        SERVICES_ARRAY=${DEFUALT_SERVICES_ARRAY[*]}
    fi

    for service_name in ${SERVICES_ARRAY[@]}; do

        local nodes=$(nodes "${service_name}")
        local length=`echo "${nodes}" | jq -r length`
        local index=0

        if [ "${which_remote_node}" != "-1" ]; then
            index=${which_remote_node}
            length=$[${index} + 1]
        fi

        while [ ${index} -lt ${length} ]
        do
            local node=$(node "${nodes}" "${index}")

            local ip=$(ip "${node}")
            local port=$(port "${node}")
            local user=$(user "${node}")
            local key=$(key "${node}")
            local passwd=$(passwd "${node}")

            if [ ! -n "${passwd}" ]; then
                echo "use a password login SSH"
            else
                if [ -f "${key}" ]; then
                    chmod 400 "${key}"
                fi

                # install dependent
                $(install_dependency "${node}")

                has_zebra_dir=`ssh -i "${key}" ${user}@${ip} -p ${port} \
                    "[ ! -d "${zebra_dir}" ] && echo "not exists"" 2>/dev/null`
                if [ "${has_zebra_dir}" = "not exists" ]; then
                    printf "${RED}peersafe services must install first${NC}\n"
                    printf "please use ${GREEN}install${NC} command installs peersafe services\n"

                    index=$[${index} + 1]
                    continue
                fi

                has_peersafe_server=`ssh -i "${key}" ${user}@${ip} -p ${port} \
                    "[ ! -f "${zebra_dir}/bin/peersafe_server" ] && echo "not exists"" 2>/dev/null`
                if [ "${has_peersafe_server}" = "not exists" ]; then
                    printf "${RED}peersafe services must install first${NC}\n"
                    printf "please use ${GREEN}install${NC} command installs peersafe services\n"

                    index=$[${index} + 1]
                    continue
                fi

                ## create work directory
                #ssh -i "${key}" ${user}@${ip} -p ${port} \
                #"[ ! -d "${zebra_dir}" ] && mkdir -p ${zebra_dir}/bin;mkdir -p ${zebra_dir}/etc;mkdir -p ${zebra_dir}/scripts"
                ## upload zebra service to remote host
                ## has a specified service name?
                #has_service=`ssh -i "${key}" ${user}@${ip} -p ${port} \
                #    "cd ${zebra_dir}/bin;[ -f "${service_name}" ] && echo "exists" || echo "not exists"" 2>/dev/null`
                #if [ "${service_name}" != "peersafe_box" -a "${has_service}" = "not exists" ]; then
                #    # upload tar file to remote host
                #    scp -i "${key}" "${services_tar_name}" "${user}@${ip}:${zebra_dir}"
                #    # unzip tar file
                #    ssh -i "${key}" ${user}@${ip} -p ${port} \
                #    "cd ${zebra_dir};tar -zxvf ${services_tar_name} -c ./bin;\
                #    rm -f ${services_tar_name}"
                #fi

                ## cp script into remote host
                #start_service_script="peersafe_zebra.sh"
                #has_start_service_script=`ssh -i "${key}" ${user}@${ip} -p ${port} \
                #    "cd ${zebra_dir};[ -f "${start_service_script}" ] && echo "exists" || echo "not exists"" 2>/dev/null`
                #if [ "${has_start_service_script}" == "not exists" ]; then
                #    scp -i "${key}" "${start_service_script}" ${user}@${ip}:${zebra_dir}
                #    ssh -i "${key}" ${user}@${ip} -p ${port} \
                #    "chmod 755 ${zebra_dir}/${start_service_script}"
                #fi

                #echo "ssh ${user}@${ip} -p ${port} -i ${key}"
                if [ "${service_name}" = "peersafe_server" ]; then
                    start_peersafe_server "${node}" "${service_name}"
                elif [ "${service_name}" = "peersafe_relay" ]; then
                    start_peersafe_relay "${node}" "${service_name}"
                elif [ "${service_name}" = "peersafe_box" ]; then
                    start_peersafe_box "${node}" "${service_name}"
                elif [ "${service_name}" = "peersafe_push_service" ]; then
                    start_peersafe_push_service "${node}" "${service_name}"
                fi

            fi

            index=$[${index} + 1]
        done
    done
}

function show() {
    local length=${#SERVICES_ARRAY[@]}
    if [ ${length} -eq 0 ]; then
        # show all services' status
        SERVICES_ARRAY=${DEFUALT_SERVICES_ARRAY[*]}
    fi

    printf '%-15s %-10s %-6s %-17s %s\n' \
    "name" "pid" "protocol" "listen" "host"

    for service_name in ${SERVICES_ARRAY[@]}; do
        if [ "${service_name}" = "ShadowBox" ]; then
            local nodes=$(nodes "peersafe_box")
        else
            local nodes=$(nodes "${service_name}")
        fi
        local length=`echo "${nodes}" | jq -r length`
        local index=0

        if [ "${which_remote_node}" != "-1" ]; then
            index=${which_remote_node}
            length=$[${index} + 1]
        fi

        while [ ${index} -lt ${length} ]
        do
            local node=$(node "${nodes}" "${index}")

            local ip=$(ip "${node}")
            local port=$(port "${node}")
            local user=$(user "${node}")
            local key=$(key "${node}")
            local passwd=$(passwd "${node}")

            if [ ! -n "${passwd}" ]; then
                echo "use a password login SSH"
            else
                if [ -f "${key}" ]; then
                    chmod 400 "${key}"
                fi

                status=`ssh -i "${key}" ${user}@${ip} -p ${port} \
                    "cd ${zebra_dir};./peersafe_zebra.sh show ${service_name}"`
                printf "%s" "${status}"
                printf "%15s\n" "${ip}"

            fi

            index=$[${index} + 1]
        done
    done
}

function stop() {
    local length=${#SERVICES_ARRAY[@]}
    if [ ${length} -eq 0 ]; then
        # show all services' status
        SERVICES_ARRAY=${DEFUALT_SERVICES_ARRAY[*]}
    fi

    for service_name in ${SERVICES_ARRAY[@]}; do
        local nodes=$(nodes "${service_name}")
        local length=`echo "${nodes}" | jq -r length`
        local index=0

        if [ "${which_remote_node}" != "-1" ]; then
            index=${which_remote_node}
            length=$[${index} + 1]
        fi

        while [ ${index} -lt ${length} ]
        do
            local node=$(node "${nodes}" "${index}")

            local ip=$(ip "${node}")
            local port=$(port "${node}")
            local user=$(user "${node}")
            local key=$(key "${node}")
            local passwd=$(passwd "${node}")

            if [ ! -n "${passwd}" ]; then
                echo "use a password login SSH"
            else
                if [ -f "${key}" ]; then
                    chmod 400 "${key}"
                fi
                # stop a service
                ssh -i "${key}" ${user}@${ip} -p ${port} \
                    "cd ${zebra_dir};./peersafe_zebra.sh stop ${service_name} -p ${which_service}" 2>/dev/null

                #printf "${GREEN}${service_name} has stopped on ${ip}${NC}\n"
            fi

            index=$[${index} + 1]
        done
    done
}

function update() {
    uninstall_peersafe_services

    install_peersafe_services
    start
}

function remove_zebra() {
    local length=${#SERVICES_ARRAY[@]}
    if [ ${length} -eq 0 ]; then
        # show all services' status
        SERVICES_ARRAY=${DEFUALT_SERVICES_ARRAY[*]}
    fi

    for service_name in ${SERVICES_ARRAY[@]}; do
        local nodes=$(nodes "${service_name}")
        local length=`echo "${nodes}" | jq -r length`
        local index=0

        while [ ${index} -lt ${length} ]
        do
            local node=$(node "${nodes}" "${index}")

            local ip=$(ip "${node}")
            local port=$(port "${node}")
            local user=$(user "${node}")
            local key=$(key "${node}")
            local passwd=$(passwd "${node}")

            if [ ! -n "${passwd}" ]; then
                echo "use a password login SSH"
            else
                if [ -f "${key}" ]; then
                    chmod 400 "${key}"
                fi
                # remove ${zebra_dir}
                ssh -i "${key}" ${user}@${ip} -p ${port} \
                    "cd ~;[ -d ${zebra_dir} ] && rm -rf ${zebra_dir}" 2>/dev/null
            fi

            printf "${GREEN}directory ${zebra_dir} has removed on ${ip}${NC}\n"

            index=$[${index} + 1]
        done
    done
}

function install_dependency() {
    local node="$1"

    local ip=$(ip "${node}")
    local port=$(port "${node}")
    local user=$(user "${node}")
    local key=$(key "${node}")

    ssh -T -i "${key}" ${user}@${ip} -p ${port} 1>>${deploy_log} 2>>${deploy_log} << 'EOF'
    has_jq=`jq --version 2>/dev/null|wc -l`
    if [ ${has_jq} -eq 0 ]; then
        printf "${GREEN}install jq${NC}\n"
        sudo apt-get -y install jq
    fi
EOF

}

function upload_service() {
    local length=${#SERVICES_ARRAY[@]}
    if [ ${length} -eq 0 ]; then
        # show all services' status
        SERVICES_ARRAY=${DEFUALT_SERVICES_ARRAY[*]}
    fi

    for service_name in ${SERVICES_ARRAY[@]}; do
        local nodes=$(nodes "${service_name}")
        local length=`echo "${nodes}" | jq -r length`
        local index=0

        if [ "${which_remote_node}" != "-1" ]; then
            index=${which_remote_node}
            length=$[${index} + 1]
        fi

        while [ ${index} -lt ${length} ]
        do
            local node=$(node "${nodes}" "${index}")

            local ip=$(ip "${node}")
            local port=$(port "${node}")
            local user=$(user "${node}")
            local key=$(key "${node}")
            local passwd=$(passwd "${node}")

            if [ ! -n "${passwd}" ]; then
                echo "use a password login SSH"
            else
                if [ -f "${key}" ]; then
                    chmod 400 "${key}"
                fi

                remote_target="${zebra_dir}/bin"
                if [ "${service_name}" == "peersafe_relay" ]; then
                    if [ -f "peersafe_relay_v4" ]; then
                        scp -i "${key}" peersafe_relay_v4 "${user}@${ip}:${remote_target}"
                    else
                        printf "${RED}peersafe_relay_v4 doesn't exists${NC}\n"
                    fi

                    if [ -f "peersafe_relay_v6" ]; then
                        scp -i "${key}" peersafe_relay_v6 "${user}@${ip}:${remote_target}"
                    else
                        printf "${RED}peersafe_relay_v6 doesn't exists${NC}\n"
                    fi
                elif [ "${service_name}" == "peersafe_box" ]; then
                    if [ -f "peersafe_server" ]; then
                        scp -i "${key}" peersafe_server "${user}@${ip}:${remote_target}/box/peersafe_box"
                    else
                        printf "${RED}peersafe_server doesn't exists${NC}\n"
                    fi

                    if [ -f "ShadowBox" ]; then
                        scp -i "${key}" ShadowBox "${user}@${ip}:${remote_target}"
                    else
                        printf "${RED}ShadowBox doesn't exists${NC}\n"
                    fi
                else
                    if [ -f "${service_name}" ]; then
                        scp -i "${key}" "${service_name}" "${user}@${ip}:${remote_target}"
                    else
                        printf "${RED}${service_name} doesn't exists${NC}\n"
                    fi
                fi
            fi

            index=$[${index} + 1]
        done
    done
}

function install_dependencies() {
    local length=${#SERVICES_ARRAY[@]}
    if [ ${length} -eq 0 ]; then
        # show all services' status
        SERVICES_ARRAY=${DEFUALT_SERVICES_ARRAY[*]}
    fi

    for service_name in ${SERVICES_ARRAY[@]}; do
        local nodes=$(nodes "${service_name}")
        local length=`echo "${nodes}" | jq -r length`
        local index=0

        while [ ${index} -lt ${length} ]
        do
            local node=$(node "${nodes}" "${index}")
            $(install_dependency "$node")
            index=$[${index} + 1]
        done
    done
}

function install_peersafe_services() {
    local length=${#SERVICES_ARRAY[@]}
    if [ ${length} -eq 0 ]; then
        # show all services' status
        SERVICES_ARRAY=${DEFUALT_SERVICES_ARRAY[*]}
    fi

    for service_name in ${SERVICES_ARRAY[@]}; do
        local nodes=$(nodes "${service_name}")
        local length=`echo "${nodes}" | jq -r length`
        local index=0

        while [ ${index} -lt ${length} ]
        do
            local node=$(node "${nodes}" "${index}")
            local ip=$(ip "${node}")
            local port=$(port "${node}")
            local user=$(user "${node}")
            local key=$(key "${node}")

            # install dependent
            $(install_dependency "${node}")

            ssh -i "${key}" ${user}@${ip} -p ${port} \
            "[ ! -d "${zebra_dir}" ] && mkdir -p ${zebra_dir}/bin;mkdir -p ${zebra_dir}/etc;mkdir -p ${zebra_dir}/scripts"

            has_service=`ssh -i "${key}" ${user}@${ip} -p ${port} \
                "cd ${zebra_dir}/bin;[ -f "peersafe_server" ] && echo "exists" || echo "not exists"" 2>/dev/null`
            if [ "${has_service}" = "not exists" ]; then
                # upload tar file to remote host
                scp -i "${key}" "${services_tar_name}" "${user}@${ip}:${zebra_dir}"
                # unzip tar file
                ssh -i "${key}" ${user}@${ip} -p ${port} \
                "cd ${zebra_dir};tar -zxvf ${services_tar_name} -C ./bin;rm -f ${services_tar_name}"
            fi

            #scp -i "${key}" "${services_tar_name}" "${user}@${ip}:${zebra_dir}"
            ## unzip tar file
            #ssh -i "${key}" ${user}@${ip} -p ${port} \
            #"cd ${zebra_dir};tar -zxvf ${services_tar_name} -C ./bin;"

            # cp script into remote host
            start_service_script="peersafe_zebra.sh"
            has_start_service_script=`ssh -i "${key}" ${user}@${ip} -p ${port} \
                "cd ${zebra_dir};[ -f "${start_service_script}" ] && echo "exists" || echo "not exists"" 2>/dev/null`
            if [ "${has_start_service_script}" == "not exists" ]; then
                scp -i "${key}" "${start_service_script}" ${user}@${ip}:${zebra_dir}
                ssh -i "${key}" ${user}@${ip} -p ${port} \
                "chmod 755 ${zebra_dir}/${start_service_script}"
            fi

            index=$[${index} + 1]
        done
    done
}

function uninstall_peersafe_services() {
    stop
    remove_zebra
}

function annouce_add_or_remove_peersafe_relay() {
    local nodes="$1"
    local command="$2"

    peersafe_relays=`cat "${deploy_config}" | jq -r .announce.${command}`
    local length=`echo "${peersafe_relays}" | jq -r length`
    local index=0

    while [ ${index} -lt ${length} ]
    do
        local peersafe_relay=`echo ${peersafe_relays} | jq -r .[${index}]`
        local user=""
        local pwd=""
        if [ "${command}" = "add" ]; then
            user=`echo ${peersafe_relay} | jq -r .user`
            pwd=`echo ${peersafe_relay} | jq -r .pwd`
        fi
        local ip=`echo ${peersafe_relay} | jq -r .ip`
        local port=`echo ${peersafe_relay} | jq -r .port`

        result=`./announce_ice_service -N "${nodes}" -c ${command} -s "${ip}:${port}" -u "${user}" -p "${pwd}"`
        echo "execute ${command} anounce"
        echo "${result}"

        index=$[${index} + 1]
    done
}

function announce_fetch_peersafe_relays() {
    local nodes="$1"
    local fetch=`cat "${deploy_config}" | jq -r .announce.fetch`
    if [ "${fetch}" = "1" ]; then
        result=`./announce_ice_service -N "${nodes}" -c fetch`
        echo "execute fetch anounce"
        echo "${result}"
    fi
}

function annouce_peersafe_relays() {
    if [ ! -f "announce_ice_service" ]; then
        printf "${RED}announce_ice_service dosen't exists${NC}\n"
        exit 1
    fi

    local bootstraps=`cat "${deploy_config}" | jq -r .announce.bootstraps?`
    local nodes=""
    if [ "${bootstraps}" = "null" -o  "${bootstraps}" = "" ]; then
        printf "${RED}Please specify bootstraps first${NC}\n"
        exit 1
    else
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
    fi

    annouce_add_or_remove_peersafe_relay "${nodes}" "add"
    annouce_add_or_remove_peersafe_relay "${nodes}" "remove"
    announce_fetch_peersafe_relays "${nodes}"
}

POSITIONAL=()
while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    start)
    if [ ! -z ${COMMAND} ]; then
        usage
        exit 0
    fi
    COMMAND="start"
    shift # past argument
    ;;
    stop)
    if [ ! -z ${COMMAND} ]; then
        usage
        exit 0
    fi
    COMMAND="stop"
    shift # past argument
    ;;
    update)
    if [ ! -z ${COMMAND} ]; then
        usage
        exit 0
    fi
    COMMAND="update"
    shift # past argument
    ;;
    show)
    if [ ! -z ${COMMAND} ]; then
        usage
        exit 0
    fi
    COMMAND="show"
    shift # past argument
    ;;
    remove)
    if [ ! -z ${COMMAND} ]; then
        usage
        exit 0
    fi
    COMMAND="remove"
    shift # past argument
    ;;
    upload)
    if [ ! -z ${COMMAND} ]; then
        usage
        exit 0
    fi
    COMMAND="upload"
    shift # past argument
    ;;
    dep)
    if [ ! -z ${COMMAND} ]; then
        usage
        exit 0
    fi
    COMMAND="dep"
    shift # past argument
    ;;
    install)
    if [ ! -z ${COMMAND} ]; then
        usage
        exit 0
    fi
    COMMAND="install"
    shift # past argument
    ;;
    uninstall)
    if [ ! -z ${COMMAND} ]; then
        usage
        exit 0
    fi
    COMMAND="uninstall"
    shift # past argument
    ;;
    announce)
    if [ ! -z ${COMMAND} ]; then
        usage
        exit 0
    fi
    COMMAND="announce"
    shift # past argument
    ;;
    peersafe_server)
    SERVICES_ARRAY=("${SERVICES_ARRAY[@]}" "peersafe_server")
    shift # past argument
    ;;
    peersafe_box)
    SERVICES_ARRAY=("${SERVICES_ARRAY[@]}" "peersafe_box" "ShadowBox")
    shift # past argument
    ;;
    peersafe_relay)
    SERVICES_ARRAY=("${SERVICES_ARRAY[@]}" "peersafe_relay")
    shift # past argument
    ;;
    peersafe_push_service)
    SERVICES_ARRAY=("${SERVICES_ARRAY[@]}" "peersafe_push_service")
    shift # past argument
    ;;
    -c|--config)
    deploy_config="$2"
    shift # past argument
    shift # past value
    ;;
    -i|--which)
    which_remote_node="$2"
    shift # past argument
    shift # past value
    ;;
    -w,c)
    rewrite_configuration=1
    shift # past argument
    ;;
    -w,s)
    rewrite_executable_scripts=1
    shift # past argument
    ;;
    --bootstrap)
    bootstrap="$2"
    zero_node=0
    shift # past argument
    shift # past value
    ;;
    -h|--help)
    usage
    shift # past argument
    ;;
    *)    # unknown option
    POSITIONAL+=("$1") # save it in an array for later
    shift # past argument
    ;;
esac
done
set -- "${POSITIONAL[@]}" # restore positional parameters

# executes

if [ ! -f "${deploy_config}" ]; then
    printf "${RED}${deploy_config} doesn't exists${NC}\n"
    exit 1
fi

zebra_dir=`cat ${deploy_config} | jq -r .work_path`

if [ "${COMMAND}" = "start" ]; then
    start
elif [ "${COMMAND}" = "show" ]; then
    show
elif [ "${COMMAND}" = "stop" ]; then
    stop
elif [ "${COMMAND}" = "update" ]; then
    update
elif [ "${COMMAND}" = "remove" ]; then
    remove_zebra
elif [ "${COMMAND}" = "upload" ]; then
    upload_service
elif [ "${COMMAND}" = "dep" ]; then
    install_dependencies
elif [ "${COMMAND}" = "install" ]; then
    install_peersafe_services
elif [ "${COMMAND}" = "uninstall" ]; then
    uninstall_peersafe_services
elif [ "${COMMAND}" = "announce" ]; then
    annouce_peersafe_relays
else
    usage
fi
