#!/usr/bin/bash

set -u

declare -r SCRIPT_NAME=${0##*/}
declare -r SCRIPT_PATH=${0%/*}

declare -i RETURN_VALUE=0

declare -r OPT_STRING="-h,-b,-p,-t"

declare -i STEP_BUILD=0
declare -i STEP_BUILD_TARGET=0
declare -i STEP_TEST=0
declare -i STEP_PHORONIX=0

declare BUILD_TARGET_NAME="debug"

declare -r LLVM_DIR="/llvm/llvm-project/llvm"
declare -r PTS_INSTALL_DIR="/pts/pts-install"

export DEBIAN_FRONTEND=noninteractive

function buildLLVM() {
    if [ ! -d "$LLVM_DIR" ]; then
        printf 'ERROR: LLVM directory "%s" does not exist\n' "$LLVM_DIR"
        exit 1
    fi
    pushd $LLVM_DIR &> /dev/null
    copyCMakePresetsJSON
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
    copyCMakePresetsJSON
    cmake --preset "$BUILD_TARGET_NAME" && \
        cmake --build --preset "$BUILD_TARGET_NAME"
    RETURN_VALUE=$?
    popd &> /dev/null
}

function testLLVM() {
    if [ ! -d "$LLVM_DIR" ]; then
        printf 'ERROR: LLVM directory "%s" does not exist\n' "$LLVM_DIR"
        exit 1
    fi
    pushd $LLVM_DIR &> /dev/null
    copyCMakePresetsJSON
    cmake --build --preset release2 -t check-all
    RETURN_VALUE=$?
    popd &> /dev/null
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

function copyCMakePresetsJSON() {
    [ ! -f CMakePresets.json ] && cp $HOME/CMakePresetsLLVM.json CMakePresets.json
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
             --longoptions "help,build,build-target:,phoronix,test" \
             -- "$@")

eval set -- "$RESULT"

while [ $# -gt 0 ]; do
    case "$1" in
        -h | --help)
            printf "%s\n" "usage: $SCRIPT_NAME [-h|--help] [-b|--build] [--build-target=NAME] [-p|--phoronix] [-t|--test]"
            exit 0
            ;;
        -b | --build)
            STEP_BUILD=1
            ;;
        --build-target)
            STEP_BUILD_TARGET=1
            shift
            BUILD_TARGET_NAME=$1
            ;;
        -p | --phoronix)
            STEP_PHORONIX=1
            ;;
        -t | --test)
            STEP_TEST=1
    esac
    shift
done

[ $STEP_BUILD -eq 1 -a $RETURN_VALUE -eq 0 ] && buildLLVM
[ $STEP_BUILD_TARGET -eq 1 -a $RETURN_VALUE -eq 0 ] && buildTargetByNameLLVM
[ $STEP_TEST -eq 1 -a $RETURN_VALUE -eq 0 ] && testLLVM
[ $STEP_PHORONIX -eq 1 -a $RETURN_VALUE -eq 0 ] && runPhoronix

exit $RETURN_VALUE
