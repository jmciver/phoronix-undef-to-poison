#!/usr/bin/bash

set -u

declare -r SCRIPT_NAME=${0##*/}
declare -r SCRIPT_PATH=${0%/*}

declare -r OPT_STRING="-h"

declare -r PTS_INSTALL="/tmp/pts-install"

declare -r CPU_TURBO_BOOST="/sys/devices/system/cpu/intel_pstate/no_turbo"
declare -r CPU_HYPER_THREAD="/sys/devices/system/cpu/smt/control"

declare -i CPU_CHECK_FAIL=1

declare LLVM_PATH=""

function checkCpuSettings() {
    checkCpuTurboBoost
    checkCpuHyperThread
    checkCpuGovernor
}

function cpuCheckMessage() {
    declare header=$([ $1 -eq 0 -a $CPU_CHECK_FAIL -eq 1 ] && echo "ERROR" || echo "INFO")
    declare state=$([ $1 -eq 0 ] && echo $3 || echo $4)
    printf "%s: %s %s\n" "$header" "$2" "$state"
    [ $CPU_CHECK_FAIL -eq 1 -a $1 -eq 0 ] && exit 1
}

function checkCpuTurboBoost() {
    grep -q '0' $CPU_TURBO_BOOST
    cpuCheckMessage $? "Turbo boost is" "enabled" "disabled"
}

function checkCpuHyperThread() {
    grep -q 'on' $CPU_HYPER_THREAD
    cpuCheckMessage $? "Hyper-threading is" "enabled" "disabled"
}

function checkCpuGovernor() {
    if ! command -v cpupower &> /dev/null; then
        printf "WARNING: cpupower command is not available\n"
        return
    fi
    declare -r governor=$(cpupower frequency-info -p | sed -E -e '3!d' -e 's/\s.*+"(.*)".*/\1/')
    printf "INFO: Performance governor is %s\n" "$governor"
    [ $CPU_CHECK_FAIL -eq 1 -a ! "$governor" = "performance" ] && exit 1
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
             --longoptions "help,llvm:,no-cpu-checks" \
             -- "$@")

eval set -- "$RESULT"

while [ $# -gt 0 ]; do
    case "$1" in
        -h | --help)
            printf "%s\n" "usage: $SCRIPT_NAME [-h|--help] [--no-cpu-checks] --llvm=PATH -- ENTRY_POINT_OPTIONS"
            helpMessage
            exit 0
            ;;
        --llvm)
            shift
            LLVM_PATH=$1
            ;;
        --no-cpu-checks)
            CPU_CHECK_FAIL=0
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
