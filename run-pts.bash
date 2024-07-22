#!/usr/bin/bash

set -u

declare -r SCRIPT_NAME=${0##*/}
declare -r SCRIPT_PATH=${0%/*}

declare -r OPT_STRING="-h"

declare -r PTS_INSTALL="/tmp/pts-install"

declare -r CPU_TURBO_BOOST="/sys/devices/system/cpu/intel_pstate/no_turbo"
declare -r CPU_HYPER_THREAD="/sys/devices/system/cpu/smt/control"

declare -i CPU_CHECK_FAIL=1

declare -i INTERACTIVE=0

declare LLVM_PATH=""

function setCpuConfiguration() {
    echo "1" | sudo tee $CPU_TURBO_BOOST
    echo "off" | sudo tee $CPU_HYPER_THREAD
    checkCpuPowerCommand && sudo cpupower frequency-set --governor performance
    CPU_CHECK_FAIL=1
    checkCpuSettings
}

function unsetCpuConfiguration() {
    echo "0" | sudo tee $CPU_TURBO_BOOST
    echo "on" | sudo tee $CPU_HYPER_THREAD
    checkCpuPowerCommand && sudo cpupower frequency-set --governor schedutil
    CPU_CHECK_FAIL=0
    checkCpuSettings
}

function checkCpuSettings() {
    checkCpuTurboBoost
    checkCpuHyperThread
    checkCpuGovernor
}

function checkCpuPowerCommand() {
    command -v cpupower &> /dev/null && true || false
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

function cpuPowerErrorMessage() {
    cat <<-EOF
$1: cpupower command was not able to obtain frequency information. This is
       most likely caused by a performance related BIOS setting.

       "cpupower frequency-info -p" reported the following output:
EOF
    cpupower frequency-info -p
}

function checkCpuGovernor() {
    if ! checkCpuPowerCommand; then
        if [ $CPU_CHECK_FAIL -eq 1 ]; then
            printf "ERROR: cpupower command is not available\n" && exit 1
        else
            printf "WARNING: cpupower command is not available\n"
        fi
    else
        declare -r governor=$(cpupower frequency-info -p | sed -E -e '3!d' -e 's/\s.*+"(.*)".*/\1/')
        if [ $? -ne 0 ]; then
            if [ $CPU_CHECK_FAIL -eq 1 ]; then
                cpuPowerErrorMessage "ERROR"
                exit 1
            else
                cpuPowerErrorMessage "WARNING"
            fi
        else
            printf "INFO: Performance governor is %s\n" "$governor"
            [ $CPU_CHECK_FAIL -eq 1 -a ! "$governor" = "performance" ] && exit 1
        fi
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
             --longoptions "help,interactive,llvm:,no-cpu-checks,cpu-set,cpu-unset,cpu-info" \
             -- "$@")

eval set -- "$RESULT"

while [ $# -gt 0 ]; do
    case "$1" in
        -h | --help)
            printf "%s\n" "usage: $SCRIPT_NAME [-h|--help] [--interactive] [--no-cpu-checks] [--cpu-set] [--cpu-unset] [--cpu-info] --llvm=PATH -- ENTRY_POINT_OPTIONS"
            helpMessage
            exit 0
            ;;
        --interactive)
            INTERACTIVE=1
            ;;
        --llvm)
            shift
            LLVM_PATH=$1
            ;;
        --no-cpu-checks)
            CPU_CHECK_FAIL=0
            ;;
        --cpu-set)
            setCpuConfiguration
            exit 0
            ;;
        --cpu-unset)
            unsetCpuConfiguration
            exit 0
            ;;
        --cpu-info)
            CPU_CHECK_FAIL=0
            checkCpuSettings
            exit 0
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

if [ $INTERACTIVE -eq 1 ]; then
   docker \
       run \
       -it \
       --rm \
       --cap-add SYS_NICE \
       --mount type=bind,source="$(pwd)",target="/pts/phoronix" \
       --mount type=bind,source="$PTS_INSTALL",target="/pts/pts-install" \
       --mount type=bind,source="$LLVM_PATH",target="/llvm" \
       --entrypoint=/usr/bin/bash \
       pts-test:1
   exit 0
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
