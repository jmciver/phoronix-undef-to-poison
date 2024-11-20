#!/usr/bin/bash

set -u

declare -r SCRIPT_NAME=${0##*/}
declare -r SCRIPT_PATH=${0%/*}

declare -i RETURN_VALUE=0

declare -r OPT_STRING="-h,-b,-p,-t"

declare -i STEP_LLVM_BUILD=0
declare -i STEP_LLVM_BUILD_TARGET=0
declare -i STEP_LLVM_TEST=0
declare -i STEP_PHORONIX=0

declare LLVM_BUILD_TARGET_NAME="debug"

declare -i STEP_ALIVE2_BUILD=0
declare -i STEP_ALIVE2_TEST=0

declare -r LLVM_PROJECT_DIR="/llvm/llvm-project"
declare -r LLVM_DIR="${LLVM_PROJECT_DIR}/llvm"
declare -r LLVM_RELEASE1="/llvm/build/release1"
declare -r LLVM_RELEASE2="/llvm/build/release2"
declare -r PTS_INSTALL_DIR="/pts/pts-install"

declare -r ALIVE2_DIR="/llvm/alive2"
declare -r ALIVE2_BUILD_DIR="${ALIVE2_DIR}/build/release"
declare ALIVE2_LLVMLIT_TEST_PATH="${LLVM_PROJECT_DIR}/llvm/test"

export DEBIAN_FRONTEND=noninteractive

function buildLLVM() {
    if [ ! -d "$LLVM_DIR" ]; then
        printf 'ERROR: LLVM directory "%s" does not exist\n' "$LLVM_DIR"
        exit 1
    fi
    pushd $LLVM_DIR &> /dev/null
    copyLLVMCMakePresetsJSON
    rm -rf ../../build/release2 && \
        cmake --preset release1 && \
        cmake --build --preset release1 && \
        cmake --preset release2 && \
        cmake --build --preset release2
    RETURN_VALUE=$?
    popd &> /dev/null
}

function buildTargetByNameLLVM() {
    if [ ! -d "$LLVM_DIR" ]; then
        printf 'ERROR: LLVM directory "%s" does not exist\n' "$LLVM_DIR"
        exit 1
    fi
    pushd $LLVM_DIR &> /dev/null
    copyLLVMCMakePresetsJSON
    cmake --preset "$LLVM_BUILD_TARGET_NAME" && \
        cmake --build --preset "$LLVM_BUILD_TARGET_NAME"
    RETURN_VALUE=$?
    popd &> /dev/null
}

function testLLVM() {
    if [ ! -d "$LLVM_DIR" ]; then
        printf 'ERROR: LLVM directory "%s" does not exist\n' "$LLVM_DIR"
        exit 1
    fi
    pushd $LLVM_DIR &> /dev/null
    copyLLVMCMakePresetsJSON
    cmake --build --preset release2 -t check-all
    RETURN_VALUE=$?
    popd &> /dev/null
}

function buildAlive2() {
    if [ ! -d "$LLVM_RELEASE1" ]; then
        printf 'ERROR: LLVM build directory "%s" does not exist. Build LLVM first.\n' "$LLVM_RELEASE1"
        exit 1
    fi
    pushd "$ALIVE2_DIR" &> /dev/null
    copyAlive2CMakePresetsJSON
    cmake --preset release && cmake --build --preset release
    RETURN_VALUE=$?
    popd &> /dev/null
}

function alive2TranslationValidation() {
    if [ ! -d "$LLVM_RELEASE1" ]; then
        printf 'ERROR: LLVM build directory "%s" does not exist. Build LLVM first.\n' "$LLVM_RELEASE1"
        exit 1
    fi
    if [ ! -d "$ALIVE2_BUILD_DIR" ]; then
        printf 'ERROR: Alive2 build directory "%s" does not exist. Build Alive2 first.\n' "$ALIVE2_BUILD_DIR"
        exit 1
    fi
    "${LLVM_RELEASE1}/bin/llvm-lit" '-s' "-Dopt=${ALIVE2_BUILD_DIR}/opt-alive.sh" "$ALIVE2_LLVMLIT_TEST_PATH"
    RETURN_VALUE=$?
}

function runPhoronix() {
    declare -r PHORONIX_DIR="/pts/phoronix/phoronix-scripts"
    if [ ! -d "$PHORONIX_DIR" ]; then
        printf 'ERROR: Phonronix scripts directory "%s\n" does not exist' "$PHORONIX_DIR"
        exit 1
    fi
    declare -r LLVM_BIN_PATH=$(realpath "${LLVM_DIR}/../../build/release2/bin")
    if [ ! -f "${LLVM_BIN_PATH}/clang" ]; then
        print 'ERROR: Clang executable does not exist\n'
        exit 1
    fi
    archiveGitVersionAndChanges
    export CC="${LLVM_BIN_PATH}/clang"
    export CXX="${LLVM_BIN_PATH}/clang++"
    pushd $PHORONIX_DIR &> /dev/null
    ./run.sh
    RETURN_VALUE=$?
    popd &> /dev/null
}

function copyLLVMCMakePresetsJSON() {
    [ ! -f CMakePresets.json ] && cp $HOME/CMakePresetsLLVM.json CMakePresets.json
}

function copyAlive2CMakePresetsJSON() {
    [ ! -f CMakePresets.json ] && cp $HOME/CMakePresetsAlive2.json CMakePresets.json
}

function archiveGitVersionAndChanges() {
    if [ ! -d  "$PTS_INSTALL_DIR" ]; then
        printf 'ERROR: directory %s does not exist\n' "$PTS_INSTALL_DIR"
        exit 1
    fi
    pushd "${LLVM_DIR}/.." &> /dev/null
    declare -r GIT_ID=$(git rev-parse --short HEAD)
    git diff > "${PTS_INSTALL_DIR}/${GIT_ID}.patch"
    popd &> /dev/null
}

RESULT=$(getopt \
             --name "$SCRIPT_NAME" \
             --options "$OPT_STRING" \
             --longoptions "help,build-alive2,build,build-target:,phoronix,test,test-alive2::" \
             -- "$@")

eval set -- "$RESULT"

while [ $# -gt 0 ]; do
    case "$1" in
        -h | --help)
            printf "%s\n" "usage: $SCRIPT_NAME [-h|--help] [-b|--build] [--build-target=NAME] [--build-alive2] [-p|--phoronix] [-t|--test] [--test-alive2[=PATH]]"
            exit 0
            ;;
        -b | --build)
            STEP_LLVM_BUILD=1
            ;;
        --build-alive2)
            STEP_ALIVE2_BUILD=1
            ;;
        --build-target)
            STEP_LLVM_BUILD_TARGET=1
            shift
            LLVM_BUILD_TARGET_NAME=$1
            ;;
        -p | --phoronix)
            STEP_PHORONIX=1
            ;;
        -t | --test)
            STEP_LLVM_TEST=1
            ;;
        --test-alive2)
            STEP_ALIVE2_TEST=1
            if [ ! -z "$2" ]; then
                ALIVE2_LLVMLIT_TEST_PATH=$2
                shift
            fi
            ;;
    esac
    shift
done

[ $STEP_LLVM_BUILD -eq 1 -a $RETURN_VALUE -eq 0 ] && buildLLVM
[ $STEP_LLVM_BUILD_TARGET -eq 1 -a $RETURN_VALUE -eq 0 ] && buildTargetByNameLLVM
[ $STEP_LLVM_TEST -eq 1 -a $RETURN_VALUE -eq 0 ] && testLLVM

[ $STEP_ALIVE2_BUILD -eq 1 -a $RETURN_VALUE -eq 0 ] && buildAlive2
[ $STEP_ALIVE2_TEST -eq 1 -a $RETURN_VALUE -eq 0 ] && alive2TranslationValidation

[ $STEP_PHORONIX -eq 1 -a $RETURN_VALUE -eq 0 ] && runPhoronix

exit $RETURN_VALUE
