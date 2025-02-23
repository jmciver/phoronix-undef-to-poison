#!/usr/bin/bash

set -u

declare -r SCRIPT_NAME=${0##*/}
declare -r SCRIPT_PATH=${0%/*}

declare -r OPT_STRING="-h"

declare PTS_PATH="/tmp"
declare -r PTS_HOME="pts-home"
declare -r PTS_INSTALL="pts-install"

declare -r CPU_TURBO_BOOST="/sys/devices/system/cpu/intel_pstate/no_turbo"
declare -r CPU_HYPER_THREAD="/sys/devices/system/cpu/smt/control"

declare -i CPU_CHECK_FAIL=1

declare -i INTERACTIVE=0

declare -r CONTAINER_BASENAME="pts-test"
declare -i CONTAINER_TAG=1
declare -ar CONTAINERS=("docker" "apptainer")
declare CONTAINER_TYPE="docker"

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

function checkContainerType() {
    for ((I=0; I < ${#CONTAINERS[@]}; I++)); do
        if [ "$CONTAINER_TYPE" = "${CONTAINERS[$I]}" ]; then
            return 0
        fi
    done
    printf 'ERROR: container type "%s" is not defined\n' "$CONTAINER_TYPE"
    return 1
}

function createDownloadCacheDirectory() {
    declare -r downloadCachePath="${SCRIPT_PATH}/download-cache"
    [[ ! -d "$downloadCachePath" ]] && mkdir "$downloadCachePath"
}

function helpMessage () {
    cat <<-EOF
Usage: $SCRIPT_NAME [OPTION]... [-- ENTRY_POINT_OPTIONS]
  -h, --help                  Help message

      --no-cpu-checks         Do not fail, just warn, on CPU governance checks
      --cpu-set               Set CPU governance to performance, disable turbo
                              boost and Hyper threading for Phoronix runs
      --cpu-unset             Undo --cpu-set

      --container-type=TYPE   The type can be docker or apptainer
      --tag                   Container tag/version
      --interactive           Start container in interactive mode,
                              ENTRY_POINT_OPTIONS have not effect

      --list-jobs             List jobs/tests specified in categorized-profiles.txt

      --llvm=PATH             Path to llvm-project, also where alive2 is located
      --scratch=PATH          Path to temporary (fast) storage for building Phoronix tests

ENTRY_POINT_OPTIONS are:

EOF
    "${SCRIPT_PATH}/container/build-and-run.bash" --help
    echo ""
}

function listJobIds() {
    declare -a jobIds=()
    for name in $(grep -v -E '^(#|/build-)' "${SCRIPT_PATH}/phoronix-scripts/categorized-profiles.txt"); do
	jobIds+=("$name")
    done
    for index in "${!jobIds[@]}"; do
        printf '%2d. %s\n' "$index" "${jobIds[index]}"
    done
}

function setupMountPoints() {
    [[ -d "$PTS_PATH" ]] || mkdir -p "$PTS_PATH"
    declare ptsHome="${PTS_PATH}/${PTS_HOME}"
    [[ -d "$ptsHome" ]] || mkdir -p "$ptsHome"
    declare ptsInstall="${PTS_PATH}/${PTS_INSTALL}"
    [[ -d "$ptsInstall" ]] || mkdir -p "$ptsInstall"
}

function runDocker() {
    declare userUID=$(id -u)
    declare userGID=$(id -g)
    declare -r imageName="${CONTAINER_BASENAME}:${CONTAINER_TAG}"
    declare -r ptsInstallPath="${PTS_PATH}/${PTS_INSTALL}"
    declare -r ptsHomePath="${PTS_PATH}/${PTS_HOME}"
    if [ $INTERACTIVE -eq 1 ]; then
        docker \
            run \
            -it \
            --rm \
            --cap-add SYS_NICE \
            --ulimit core=0 \
            --mount type=bind,source="$(pwd)",target="/pts/phoronix" \
            --mount type=bind,source="$ptsInstallPath",target="/pts/pts-install" \
            --mount type=bind,source="$ptsHomePath",target="/pts/pts-home" \
            --mount type=bind,source="$LLVM_PATH",target="/llvm" \
            --user "${userUID}:${userGID}" \
            --entrypoint=/usr/bin/bash \
            "$imageName"
    else
        docker \
            run \
            -it \
            --rm \
            --cap-add SYS_NICE \
            --ulimit core=0 \
            --mount type=bind,source="$(pwd)",target="/pts/phoronix" \
            --mount type=bind,source="$ptsInstallPath",target="/pts/pts-install" \
            --mount type=bind,source="$ptsHomePath",target="/pts/pts-home" \
            --mount type=bind,source="$LLVM_PATH",target="/llvm" \
            --user "${userUID}:${userGID}" \
            "$imageName" "$@"
    fi
}

function runApptainer() {
    declare -r imageName="${SCRIPT_PATH}/container/${CONTAINER_BASENAME}-${CONTAINER_TAG}.sif"
    declare -r ptsInstallPath="${PTS_PATH}/${PTS_INSTALL}"
    declare -r ptsHomePath="${PTS_PATH}/${PTS_HOME}"
    if [ $INTERACTIVE -eq 1 ]; then
        apptainer \
            shell \
            --no-home \
            --containall \
            --mount type=bind,source="$(pwd)",target="/pts/phoronix" \
            --mount type=bind,source="$ptsInstallPath",target="/pts/pts-install" \
            --mount type=bind,source="$ptsHomePath",target="/pts/pts-home" \
            --mount type=bind,source="$LLVM_PATH",target="/llvm" \
            "$imageName"
    else
        apptainer \
            run \
            --no-home \
            --containall \
            --mount type=bind,source="$(pwd)",target="/pts/phoronix" \
            --mount type=bind,source="$ptsInstallPath",target="/pts/pts-install" \
            --mount type=bind,source="$ptsHomePath",target="/pts/pts-home" \
            --mount type=bind,source="$LLVM_PATH",target="/llvm" \
            "$imageName" "$@"
    fi
}

function createPtsInstallPath() {
    if [ ! -d "$PTS_PATH" ]; then
        printf "INFO: making pts home and install/build directory in %s\n" "$PTS_PATH"
        mkdir -p "$PTS_PATH" && \
            mkdir -p "${PTS_PATH}/${PTS_INSTALL}" && \
            mkdir -p "${PTS_PATH}/${PTS_HOME}" || \
                exit 1
    fi
}

RESULT=$(getopt \
             --name "$SCRIPT_NAME" \
             --options "$OPT_STRING" \
             --longoptions "help,container-type:,tag:,interactive,llvm:,scratch:,list-jobs,no-cpu-checks,cpu-set,cpu-unset,cpu-info" \
             -- "$@")
[[ $? -eq 0 ]] || exit 1

eval set -- "$RESULT"

while [ $# -gt 0 ]; do
    case "$1" in
        -h | --help)
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
        --scratch)
            shift
            PTS_PATH=$1
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
        --container-type)
            shift
            CONTAINER_TYPE=$1
            checkContainerType || exit 1
            ;;
        --tag)
            shift
            CONTAINER_TAG=$1
            ;;
        --list-jobs)
            listJobIds
            exit 0
            ;;
        --)
            shift
            break
            ;;
    esac
    shift
done

createPtsInstallPath
checkCpuSettings

if [ -z "$LLVM_PATH" ]; then
    printf "ERROR: --llvm=PATH must be specified\n"
    exit 1
fi

if [ ! -d "$LLVM_PATH" ]; then
    printf "ERROR: --llvm=%s does not specify a real directory\n" "$LLVM_PATH"
    exit 1
fi

createDownloadCacheDirectory
setupMountPoints
case "$CONTAINER_TYPE" in
    docker)
        runDocker "$@"
        ;;
    apptainer)
        runApptainer "$@"
        ;;
esac
