#!/usr/bin/bash

set -u

declare -r SCRIPT_NAME=${0##*/}
declare -r SCRIPT_PATH_FULL=$(realpath $0)
declare -r SCRIPT_PATH=${SCRIPT_PATH_FULL%/*}

declare -i RETURN_VALUE=0

declare -r OPT_STRING="-h,-b,-p,-t"

declare -i STEP_LLVM_BUILD=0
declare -i STEP_LLVM_BUILD_TARGET=0
declare -i STEP_LLVM_TEST=0
declare -i STEP_LIST_JOBS=0
declare -i STEP_PHORONIX_BUILD_USING_ALIVE2=0
declare -i STEP_PHORONIX=0
declare -i STEP_MAKE_DOWNLOAD_CACHE=0

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

declare -r Z3_DIR="/llvm/z3"

declare -r PHORONIX_DIR="/pts/phoronix/phoronix-scripts"
declare -a PTS_JOB_IDS=()
declare -i PTS_JOB_ID=0
declare -r PTS_JOBS_FILE="${PHORONIX_DIR}/categorized-profiles.txt"

declare -x DEBIAN_FRONTEND=noninteractive

declare -x NUM_CPU_CORES=20
declare -x ALIVE2_JOB_SERVER_PATH="${ALIVE2_BUILD_DIR}/alive-jobserver"
declare -x ALIVE2_JOB_SERVER_THREADS=40

function buildLLVM() {
    checkForLLVMDirectory
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
    checkForLLVMDirectory
    pushd $LLVM_DIR &> /dev/null
    copyLLVMCMakePresetsJSON
    cmake --preset "$LLVM_BUILD_TARGET_NAME" && \
        cmake --build --preset "$LLVM_BUILD_TARGET_NAME"
    RETURN_VALUE=$?
    popd &> /dev/null
}

function testLLVM() {
    checkForLLVMDirectory
    pushd $LLVM_DIR &> /dev/null
    copyLLVMCMakePresetsJSON
    cmake --build --preset release2 -t check-all
    RETURN_VALUE=$?
    popd &> /dev/null
}

function buildAlive2() {
    checkForBuildDirectory "LLVM" "$LLVM_RELEASE1"
    pushd "$ALIVE2_DIR" &> /dev/null
    copyCMakePresets "CMakePresetsAlive2.json"
    cmake --preset release && cmake --build --preset release
    RETURN_VALUE=$?
    popd &> /dev/null
    return $RETURN_VALUE
}

function buildZ3() {
    pushd "$Z3_DIR" &> /dev/null
    copyCMakePresets "CMakePresetsZ3.json"
    cmake --preset release && cmake --build --preset release
    RETURN_VALUE=$?
    popd &> /dev/null
    return $RETURN_VALUE
}

function alive2TranslationValidation() {
    checkForBuildDirectory "LLVM" "$LLVM_RELEASE1"
    checkForBuildDirectory "Alive2" "$ALIVE2_BUILD_DIR"
    "${LLVM_RELEASE1}/bin/llvm-lit" '-s' "-Dopt=${ALIVE2_BUILD_DIR}/opt-alive.sh" "$ALIVE2_LLVMLIT_TEST_PATH"
    RETURN_VALUE=$?
}

function checkForLLVMDirectory() {
    if [ ! -d "$LLVM_DIR" ]; then
        printf 'ERROR: LLVM directory "%s" does not exist\n' "$LLVM_DIR"
        exit 1
    fi
}

function checkForBuildDirectory() {
    declare buildName=$1
    declare buildPath=$2
    if [ ! -d "$buildPath" ]; then
        printf 'ERROR: %s build directory "%s" does not exist. Build %s first.\n' "$buildName" "$buildPath" "$buildName"
        exit 1
    fi
}

function loadJobIds() {
    if [ ! -f "$PTS_JOBS_FILE" ]; then
        printf 'ERROR: PTS jobs file "%s" does not exist.\n' "$PTS_JOBS_FILE"
        exit 1
    fi
    for name in $(grep -v -E '^(#|/build-)' "${PTS_JOBS_FILE}"); do
	PTS_JOB_IDS+=("$name")
    done
}

function printJobIds() {
    for index in "${!PTS_JOB_IDS[@]}"; do
        printf '%2d. %s\n' "$index" "${PTS_JOB_IDS[index]}"
    done
}

function checkJobId() {
    declare -i idNumber=$1
    if [[ "$idNumber" -lt 0 || "$idNumber" -ge "${#PTS_JOB_IDS[*]}" ]]; then
        printf 'ERROR: Phoronix job ID %d is out of range.\n' "$idNumber"
        exit 1
    fi
}

function setupPtsHome() {
    declare userConfig="${PTS_USER_PATH_OVERRIDE}/user-config.xml"
    declare testProfiles="${PTS_USER_PATH_OVERRIDE}/test-profiles"
    [[ -f "$userConfig" ]] || cp "${HOME}/user-config.xml" "$userConfig"
    [[ -L "$testProfiles" ]] || ln -s '/pts/phoronix/test-profiles' "$testProfiles"
}

function phoronixMakeDownloadCache() {
    for jobName in "${PTS_JOB_IDS[@]}"; do
        /pts/phoronix/phoronix-test-suite/phoronix-test-suite \
            make-download-cache \
            "$jobName"
        updateReturnValue "$?"
    done
}

function phoronixBuildUsingAlive2() {
    checkJobId $PTS_JOB_ID
    declare -r jobNameBase=$(basename "${PTS_JOB_IDS[$PTS_JOB_ID]}" | tr '.' 'p')'-base'

    # The following environment variables are used by Phoronix. The result name
    # is also the name of the directory where the results reside.
    # declare -x TEST_RESULTS_NAME="$jobNameBase"
    # declare -x TEST_RESULTS_IDENTIFIER="container"

    # Use unique random file IDs to prevent naming collisions due to different
    # translational objects in a project's hierarchy using the same name. Alive2
    # results are placed in the test-results directory to maintain a separation
    # between build and report artifacts.
    declare -x ALIVECC_OVERWRITE_REPORTS=0
    declare -x ALIVECC_REPORT_DIR="/pts/pts-install/test-results/${jobNameBase}/alive2-logs"
    declare -x ALIVECC_QUIET=1
    declare -x ALIVECC_PARALLEL_FIFO=1

    declare -x CC="/llvm/alive2/build/release/alivecc"
    declare -x CXX="/llvm/alive2/build/release/alive++"
    php /pts/phoronix/phoronix-test-suite/pts-core/phoronix-test-suite.php debug-install "${PTS_JOB_IDS[${PTS_JOB_ID}]}"
    # php /pts/phoronix/phoronix-test-suite/pts-core/phoronix-test-suite.php batch-run "${PTS_JOB_IDS[${PTS_JOB_ID}]}"
}

function runPhoronix() {
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
    declare -x CC="${LLVM_BIN_PATH}/clang"
    declare -x CXX="${LLVM_BIN_PATH}/clang++"
    pushd $PHORONIX_DIR &> /dev/null
    ./run.sh
    RETURN_VALUE=$?
    popd &> /dev/null
}

function copyLLVMCMakePresetsJSON() {
    [ ! -f CMakePresets.json ] && cp "${SCRIPT_PATH}/CMakePresetsLLVM.json" CMakePresets.json
}

function copyCMakePresets() {
    declare sourceName=$1
    [ ! -f CMakePresets.json ] && cp "${SCRIPT_PATH}/${sourceName}" CMakePresets.json
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

function updateReturnValue() {
    declare -i newValue=$1
    if [[ $RETURN_VALUE -eq 0 && $newValue -ne 0 ]]; then
        RETURN_VALUE=$newValue
    fi
}

function validateInteger() {
    declare number="$1"
    declare minimum="$2"
    declare maximum="$3"
    declare testValue=''

    if [[ -z "$number" ]]; then
        printf 'ERROR: no number provided\n' >&2
        return 1
    fi
    # Remove negative sign if present.
    if [[ "${number%${number#?}}" = '-' ]]; then
        testValue="${number#?}"
    else
        testValue="$number"
    fi
    declare noDigits=$(echo "$testValue" | sed 's/[[:digit:]]//g')
    if [[ ! -z "$noDigits" ]]; then
        printf 'ERROR: invalid number format %s\n' "$number" >&2
        return 1
    fi
    if [[ ! -z "$minimum" && "$testValue" -lt "$minimum" ]]; then
        printf 'ERROR: %i < %i\n' "$testValue" "$minimum" >&2
        return 1
    fi
    if [[ ! -z "$maximum" && "$testValue" -gt "$maximum" ]]; then
        printf 'ERROR: %i > %i\n' "$testValue" "$maximum" >&2
        return 1
    fi
    return 0
}

function helpMessage() {
    cat <<-EOF
Usage: $SCRIPT_NAME [OPTION]...
  -h, --help               Help message

      --number-of-cores=N   Number of CPU cores to build with
      --number-of-threads=N Number of threads to provide to the Alive2
                            job server

  -b, --build              Build phase 1 and 2 of LLVM bootstrap build
      --build-target=NAME  Build specific CMakePresets.json target name
      --build-alive2       Build Alive2

  -t, --test               Run check-all using phase 2
      --test-alive2=PATH   Execute alive2 TV run using llvm-lit path

  -p, --phoronix                Run Phoronix testsuite
      --list-jobs               List jobs/tests specified in
                                categorized-profiles.txt
      --pts-alive2=ID           Build Phoronix test using ID# obtained
                                from --list-jobs
      --pts-make-download-cache Generate download cache for all categorized
                                tests
EOF
}

RESULT=$(getopt \
             --name "$SCRIPT_NAME" \
             --options "$OPT_STRING" \
             --longoptions "help,build-alive2,build,build-target:,number-of-cores:,number-of-threads:,list-jobs,phoronix,pts-alive2:,pts-make-download-cache,test,test-alive2::" \
             -- "$@")

if [ $? -ne 0 ]; then
    exit 1
fi

eval set -- "$RESULT"

while [ $# -gt 0 ]; do
    case "$1" in
        -h | --help)
            helpMessage
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
        --list-jobs)
            STEP_LIST_JOBS=1
            ;;
        --pts-alive2)
            STEP_PHORONIX_BUILD_USING_ALIVE2=1
            shift
            PTS_JOB_ID=$1
            ;;
        --pts-make-download-cache)
            STEP_MAKE_DOWNLOAD_CACHE=1
            ;;
        --number-of-cores)
            shift
            NUM_CPU_CORES=$1
            validateInteger "$NUM_CPU_CORES" 1 '' || exit 1
            ;;
        --number-of-threads)
            shift
            ALIVE2_JOB_SERVER_THREADS=$1
            validateInteger "$ALIVE2_JOB_SERVER_THREADS" 1 '' || exit 1
            ;;
    esac
    shift
done

[ $STEP_LLVM_BUILD -eq 1 -a $RETURN_VALUE -eq 0 ] && buildLLVM
[ $STEP_LLVM_BUILD_TARGET -eq 1 -a $RETURN_VALUE -eq 0 ] && buildTargetByNameLLVM
[ $STEP_LLVM_TEST -eq 1 -a $RETURN_VALUE -eq 0 ] && testLLVM

[ $STEP_ALIVE2_BUILD -eq 1 -a $RETURN_VALUE -eq 0 ] && buildZ3 && buildAlive2
[ $STEP_ALIVE2_TEST -eq 1 -a $RETURN_VALUE -eq 0 ] && alive2TranslationValidation

loadJobIds
setupPtsHome
[ $STEP_LIST_JOBS -eq 1 -a $RETURN_VALUE -eq 0 ] && printJobIds
[ $STEP_MAKE_DOWNLOAD_CACHE -eq 1 -a $RETURN_VALUE -eq 0 ] && phoronixMakeDownloadCache
[ $STEP_PHORONIX_BUILD_USING_ALIVE2 -eq 1 -a $RETURN_VALUE -eq 0 ] && phoronixBuildUsingAlive2
[ $STEP_PHORONIX -eq 1 -a $RETURN_VALUE -eq 0 ] && runPhoronix

exit $RETURN_VALUE
