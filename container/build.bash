#!/usr/bin/bash

set -u

declare -r SCRIPT_NAME=${0##*/}
declare -r SCRIPT_PATH=${0%/*}

declare -r OPT_STRING="-h"

declare -i BUILD_DOCKER=0
declare -i BUILD_APPTAINER=0

declare -r USER_UID=$(id -u)
declare -r USER_GID=$(id -g)
declare -r USER_NAME=$(id -u -n)

declare -r APPTAINER_SIF_NAME="pts-test.sif"

function buildDocker() {
    docker \
        build \
        --build-arg="USER_UID=${USER_UID}" \
        --build-arg="USER_GID=${USER_GID}" \
        --tag=pts-test:1 .
}

function buildApptainer() {
    rm -rf "$APPTAINER_SIF_NAME" && \
        apptainer \
            build \
            --build-arg "USER_HOME=ptr" \
            "$APPTAINER_SIF_NAME" \
            Apptainer
}

RESULT=$(getopt \
             --name "$SCRIPT_NAME" \
             --options "$OPT_STRING" \
             --longoptions "help,docker,apptainer" \
             -- "$@")

eval set -- "$RESULT"

while [ $# -gt 0 ]; do
    case "$1" in
        -h | --help)
            printf "%s\n" "usage: $SCRIPT_NAME [-h|--help] [--docker] [--apptainer]"
            exit 0
            ;;
        --docker)
            BUILD_DOCKER=1
            ;;
        --apptainer)
            BUILD_APPTAINER=1
            ;;
    esac
    shift
done

[ $BUILD_DOCKER -eq 1 ] && buildDocker
[ $BUILD_APPTAINER -eq 1 ] && buildApptainer
