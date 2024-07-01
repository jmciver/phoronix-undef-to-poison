#!/usr/bin/bash

set -u

declare -r SCRIPT_NAME=${0##*/}
declare -r SCRIPT_PATH=${0%/*}

declare -r OPT_STRING="-h"

declare -r PTS_INSTALL="/tmp/pts-install"

declare LLVM_PATH=""

function checkCpuSettings() {
    declare -r cpuTurbo="/sys/devices/system/cpu/intel_pstate/no_turbo"
    grep -q '0' $cpuTurbo
    if [ $? -eq 0 ]; then
        printf "INFO: Turbo boost is enabled\n"
    fi
    declare -r hyperThread="/sys/devices/system/cpu/smt/control"
    grep -q 'on' $hyperThread
    if [ $? -eq 0 ]; then
        printf "INFO: Hyperthreading is enabled\n"
    fi

    if ! command -v cpupower &> /dev/null; then
        printf "WARNING: cpupower command is not available\n"
        return
    fi
    declare -r governor=$(cpupower frequency-info -p | sed -E -e '3!d' -e 's/\s.*+"(.*)".*/\1/')
    if [ "$governor" = "performance" ]; then
        printf "INFO: Performance governor is %s\n" "$governor"
    fi
}

function helpMessage () {
    cat <<-EOF

ENTRY_POINT_OPTIONS are:

Build & Test:
[-b|--build]    to build the llvm project
[-t|--test]     to run llvm release2 check-all target

Phoronix:
[-p|--phoronix] to run Phoronix tests

EOF
}

if [ ! -d "$PTS_INSTALL" ]; then
    printf "INFO: making pts install/build directory %s\n" "$PTS_INSTALL"
    mkdir -p "$PTS_INSTALL" || exit 1
fi

RESULT=$(getopt \
             --name "$SCRIPT_NAME" \
             --options "$OPT_STRING" \
             --longoptions "help,llvm:" \
             -- "$@")

eval set -- "$RESULT"

while [ $# -gt 0 ]; do
    case "$1" in
        -h | --help)
            printf "%s\n" "usage: $SCRIPT_NAME [-h|--help] --llvm=PATH -- ENTRY_POINT_OPTIONS"
            helpMessage
            exit 0
            ;;
        --llvm)
            shift
            LLVM_PATH=$1
            ;;
        --)
            shift
            break
            ;;
    esac
    shift
done

checkCpuSettings

if [ -z "$LLVM_PATH" ]; then
    printf "ERROR: --llvm=PATH must be specified\n"
    exit 1
fi

if [ ! -d "$LLVM_PATH" ]; then
    printf "ERROR: --llvm=%s does not specify a real directory\n" "$LLVM_PATH"
    exit 1
fi

docker \
    run \
    -it \
    --rm \
    --cap-add SYS_NICE \
    --mount type=bind,source="$(pwd)",target="/pts/phoronix" \
    --mount type=bind,source="$PTS_INSTALL",target="/pts/pts-install" \
    --mount type=bind,source="$LLVM_PATH",target="/llvm" \
    pts-test:1 $@
