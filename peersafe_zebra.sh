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
DEFUALT_SERVICES=("peersafe_server" "peersafe_relay" "peersafe_box" "peersafe_push_service")

function usage() {
    echo "usage: "
    echo " peersafe_zebra command service [option]"
    echo
    echo " commands"
    echo "  start       start/restart a service"
    echo "  restart     restart a peersafe service"
    echo "  stop        stop a peersafe service"
    echo "  show        show status of a peersafe service"
    echo
    echo " services"
    echo "  peersafe_server"
    echo "  peersafe_box"
    echo "  peersafe_relay"
    echo
    echo "examples:"
    echo " peersafe_zebra start peersafe_server"
    echo " peersafe_zebra stop"
    echo " peersafe_zebra show"
    echo
}

function has_service() {
    local service_count=`ps -ef|grep $1|grep -v grep|grep -v bash|grep -v ssh|wc -l`
    echo ${service_count}
}

function service_pid() {
    local service=`ps -ef|grep $1|grep -v grep|grep -v bash|grep -v ssh| awk '{print $2}'`
    echo ${service}
}

function kill_service() {
    local service_name="$1"

    # kill parent process
    local parent_service=`ps -ef|grep ${service_name}|grep -v grep|grep -v bash|grep -v ssh| awk '{print $3}'`
    if [ ${parent_service} -gt 1 ]; then
        kill -9 ${parent_service}
    fi

    # then kill child process
    local service=`ps -ef|grep ${service_name}|grep -v grep|grep -v bash|grep -v ssh| awk '{print $2}'`
    if [ ${service} -gt 0 ]; then
        kill -9 ${service}
    fi
}

function show_service() {
    local has_service=$(has_service $1)
    if [ ${has_service} -eq 0 ]; then
        echo ""
    else
        local service=$(service_pid $1)
        local state=`netstat -nulp 2>/dev/null| grep ${service}`
        echo ${state}
    fi
}

function start_peersafe_server() {
    local has_service=$(has_service ${SERVICE})
    if [ ${has_service} -gt 0 ]; then
        printf "${RED}peersafe_server has already run.\n${NC}"
        exit 1
    fi

    script_path="${zebra_dir}/scripts"
    start_peersafe_server="${script_path}/peersafe_server.sh"
    chmod 755 ${start_peersafe_server}
    nohup ${start_peersafe_server} 1>/dev/null 2>&1 &

    wait_seconds=0
    while true
    do
        status=$(show_service ${SERVICE})
        if [ "${status}" != "" ]; then
            pid=`echo ${status} | awk '{print $6}'| awk -F '/' '{print $1}'`
            if [ "${pid}" != "" ]; then
                printf "${GREEN}${SERVICE} has startup successfully${NC}\n"
                break
            fi
        fi

        if [ ${wait_seconds} -gt 4 ]; then
            break
        fi
        wait_seconds=$[${wait_seconds} + 1]
        sleep 1
    done
}

function start_peersafe_box() {
    local has_service=$(has_service ${SERVICE})
    if [ ${has_service} -gt 0 ]; then
        printf "${RED}${SERVICE} has already run.\n${NC}"
        exit 1
    fi

    script_path="${zebra_dir}/scripts"
    start_peersafe_box="${script_path}/${SERVICE}.sh"
    chmod 755 ${start_peersafe_box}
    nohup ${start_peersafe_box} 1>/dev/null 2>&1 &

    wait_seconds=0
    while true
    do
        status=$(show_service ${SERVICE})
        if [ "${status}" != "" ]; then
            pid=`echo ${status} | awk '{print $6}'| awk -F '/' '{print $1}'`
            if [ "${pid}" != "" ]; then
                printf "${GREEN}${SERVICE} has startup successfully${NC}\n"
                break
            fi
        fi

        if [ ${wait_seconds} -gt 4 ]; then
            break
        fi
        wait_seconds=$[${wait_seconds} + 1]
        sleep 1
    done
}

function start_peersafe_relay() {
    has_peersafe_relay=$(has_service ${SERVICE})
    if [ ${has_peersafe_relay} -gt 0 ]; then
        printf "${RED}${SERVICE} has already setup${NC}\n"
        exit 1
    fi

    script_path="${zebra_dir}/scripts"
    start_peersafe_relay="${script_path}/peersafe_relay.sh"
    chmod 755 ${start_peersafe_relay}
    nohup ${start_peersafe_relay} 1>/dev/null 2>&1 &

    wait_seconds=0
    while true
    do
        status=$(show_service ${SERVICE})
        if [ "${status}" != "" ]; then
            pid=`echo ${status} | awk '{print $6}'| awk -F '/' '{print $1}'`
            if [ "${pid}" != "" ]; then
                printf "${GREEN}${SERVICE} has startup successfully${NC}\n"
                break
            fi
        fi

        if [ ${wait_seconds} -gt 4 ]; then
            break
        fi
        wait_seconds=$[${wait_seconds} + 1]
        sleep 1
    done
}

function start_peersafe_push_service() {
    local has_service=$(has_service ${SERVICE})
    if [ ${has_service} -gt 0 ]; then
        printf "${RED}peersafe_push_service has already run.\n${NC}"
        exit 1
    fi

    script_path="${zebra_dir}/scripts"
    start_peersafe_push_service="${script_path}/peersafe_push_service.sh"
    chmod 755 ${start_peersafe_push_service}
    nohup ${start_peersafe_push_service} 1>/dev/null 2>&1 &

    wait_seconds=0
    while true
    do
        status=$(show_service ${SERVICE})
        if [ "${status}" != "" ]; then
            pid=`echo ${status} | awk '{print $6}'| awk -F '/' '{print $1}'`
            if [ "${pid}" != "" ]; then
                printf "${GREEN}${SERVICE} has startup successfully${NC}\n"
                break
            fi
        fi

        if [ ${wait_seconds} -gt 4 ]; then
            break
        fi
        wait_seconds=$[${wait_seconds} + 1]
        sleep 1
    done
}

COMMAND=""
SERVICE=""

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
    show)
    if [ ! -z ${COMMAND} ]; then
        usage
        exit 0
    fi
    COMMAND="show"
    shift # past argument
    ;;
    peersafe_server)
    if [ ! -z ${SERVICE} ]; then
        usage
        exit 0
    fi
    SERVICE="peersafe_server"
    shift # past argument
    ;;
    peersafe_box)
    if [ ! -z ${SERVICE} ]; then
        usage
        exit 0
    fi
    SERVICE="peersafe_box"
    shift # past argument
    ;;
    peersafe_relay)
    if [ ! -z ${SERVICE} ]; then
        usage
        exit 0
    fi
    SERVICE="peersafe_relay"
    shift # past argument
    ;;
    peersafe_push_service)
    if [ ! -z ${SERVICE} ]; then
        usage
        exit 0
    fi
    SERVICE="peersafe_push_service"
    shift # past argument
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


valid_service=0
for service_name in ${DEFUALT_SERVICES[@]}; do
    if [ "${service_name}" = "${SERVICE}" ]; then
        valid_service=1
        break
    fi
done

if [ ${valid_service} -eq 0 ]; then
    printf "${RED}SERVICE is invalid. using -h print help${NC}\n"
    exit
fi

if [ "${COMMAND}" = "start" ]; then
    if [ "${SERVICE}" = "peersafe_server" ]; then
        start_peersafe_server
    elif [ "${SERVICE}" = "peersafe_relay" ]; then
        start_peersafe_relay
    elif [ "${SERVICE}" = "peersafe_box" ]; then
        start_peersafe_box
    elif [ "${SERVICE}" = "peersafe_push_service" ]; then
        start_peersafe_push_service
    fi
elif [ "${COMMAND}" = "stop" ]; then
    has_peersafe_server=$(has_service ${SERVICE})
    if [ ${has_peersafe_server} -gt 0 ]; then
        kill_service ${SERVICE}

        if [ "${SERVICE}" = "umbroatcast" ]; then
            has_umbroatcast=$(has_service "umbroatcast")
            if [ ${has_umbroatcast} -gt 0 ]; then
                kill_service "umbroatcast" 
            fi
        fi

        #printf "${CYAN}peersafe_server has stopped${NC}\n"
        has_peersafe_server=$(has_service ${SERVICE})

        if [ ${has_peersafe_server} -eq 0 ]; then
            printf "${GREEN}${SERVICE} has stop successfully\n${NC}"
            exit 1
        fi
    fi
elif [ "${COMMAND}" = "show" ]; then
    status=$(show_service ${SERVICE})
    if [ "${status}" == "" ]; then
        printf '%-15s %-10s %-6s %-17s\n' \
        "${SERVICE}" "-" "-" "-"
        exit 0
    fi
    protocol=`echo ${status} | awk '{print $1}'`
    bind=`echo ${status} | awk '{print $4}'`
    pid=`echo ${status} | awk '{print $6}'| awk -F '/' '{print $1}'`
    name=`echo ${status} | awk '{print $6}'| awk -F '/' '{print $2}'`

    printf '%-15s %-10s %-6s %-17s\n' \
    "${name}" "${pid}" "${protocol}" "${bind}"
else
    printf "${RED}COMMAND is invalid.${NC}\n"
fi