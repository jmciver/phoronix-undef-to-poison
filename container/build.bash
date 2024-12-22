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

declare -r CONTAINER_BASENAME="pts-test"
declare -i CONTAINER_VERSION=1

function buildDocker() {
    declare -r imageName="${CONTAINER_BASENAME}:${CONTAINER_VERSION}"
    cleanupDocker "$imageName"
    docker \
        build \
        --build-arg="USER_UID=${USER_UID}" \
        --build-arg="USER_GID=${USER_GID}" \
        --tag="$imageName" .
}

function cleanupDocker() {
    declare -r imageName=$1
    if [[ $(docker ps -qa --filter "ancestor=${imageName}" | wc -l) -gt 0 ]]; then
        printf 'ERROR: image "%s" is currently used by a container\n' "$imageName"
        exit 1
    else
        docker image inspect "$imageName" &> /dev/null && \
            docker image rm "$imageName"
    fi
}

function buildApptainer() {
    declare -r sifFilename="${CONTAINER_BASENAME}-${CONTAINER_VERSION}.sif"
    [[ -f "$sifFilename" ]] && rm "$sifFilename"
    apptainer \
        build \
        --build-arg "USER_HOME=ptr" \
        "$sifFilename" \
        Apptainer
}

RESULT=$(getopt \
             --name "$SCRIPT_NAME" \
             --options "$OPT_STRING" \
             --longoptions "help,docker,apptainer,tag:" \
             -- "$@")
[[ $? -eq 0 ]] || exit 1

eval set -- "$RESULT"

while [ $# -gt 0 ]; do
    case "$1" in
        -h | --help)
            printf "%s\n" "usage: $SCRIPT_NAME [-h|--help] [--docker] [--apptainer] [--tag=NUMBER]"
            exit 0
            ;;
        --docker)
            BUILD_DOCKER=1
            ;;
        --apptainer)
            BUILD_APPTAINER=1
            ;;
        --tag)
            shift
            CONTAINER_VERSION=$1
            ;;
    esac
    shift
done

[ $BUILD_DOCKER -eq 1 ] && buildDocker
[ $BUILD_APPTAINER -eq 1 ] && buildApptainer
