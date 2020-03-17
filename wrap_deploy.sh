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
LGREEN='\033[1;32m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m' # No Colo

COMMAND=""
SEVICE_NAME=""

function usag() {
    echo "deploy_zebra [command]"
    echo
    echo "commands"
    echo " install"
    echo " uninstall"
    echo " start"
    echo " stop"
    echo " show"
    echo " upload"
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
        show)
            if [ ! -z ${COMMAND} ]; then
                usage
                exit 0
            fi
            COMMAND="show"
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
        dep)
            if [ ! -z ${COMMAND} ]; then
                usage
                exit 0
            fi
            COMMAND="dep"
            shift # past argument
            ;;
         peersafe_server)
             SEVICE_NAME="peersafe_server"
             shift # past argument
             ;;  
         peersafe_box)
             SEVICE_NAME="peersafe_box"
             shift # past argument
             ;;  
         peersafe_relay)
             SEVICE_NAME="peersafe_relay"
             shift # past argument
             ;;  
         peersafe_push_service)
             SEVICE_NAME="peersafe_push_service"
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

peersafe_zebra_service="peersafe_zebra_service.tar.gz"

if [ ! -f "${peersafe_zebra_service}" ]; then
    tar zcvf ${peersafe_zebra_service} peersafe_server \
        peersafe_client \
        peersafe_push_service \
        peersafe_relay_v4 \
        peersafe_relay_v6 \
        ShadowBox
fi

declare -a CONFIG_LIST
CONFIG_LIST=("${CONFIG_LIST[@]}" \
    "config.json" \
    )

printf "${LGREEN}begin deploy on remote host${NC}\n"

for config in ${CONFIG_LIST[@]}; do
    if [ -f "${config}" ]; then
        ./deploy.sh -c ${config} -w,c ${COMMAND} ${SEVICE_NAME}
        echo
    else
        printf "${RED}${config} dosen't exists${NC}"
    fi
done

printf "${LGREEN}complete deploy on remote host${NC}\n"
