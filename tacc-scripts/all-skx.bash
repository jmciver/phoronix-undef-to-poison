#!/usr/bin/bash

set -u

declare -r SCRIPT_NAME=${0##*/}
declare -r SCRIPT_PATH=${0%/*}

declare -r OPT_STRING="-h"

declare RUN_TYPE=''


RESULT=$(getopt \
             --name "$SCRIPT_NAME" \
             --options "$OPT_STRING" \
             --longoptions "help,type:" \
             -- "$@")
[[ $? -eq 0 ]] || exit 1

eval set -- "$RESULT"
while [ $# -gt 0 ]; do
    case "$1" in
        -h | --help)
            printf '%s: [-h|--help] --type=(base|dev|main)\n' "$SCRIPT_NAME"
            exit 0
            ;;
        --type)
            shift
            case "$1" in
                base)
                    RUN_TYPE=base
                    ;;
                dev)
                    RUN_TYPE=dev
                    ;;
                main)
                    RUN_TYPE=main
                    ;;
                *)
                    printf 'ERROR: %s is not a supported type\n' "$1" 1>&2
                    exit 1
                    ;;
            esac
    esac
    shift
done

if [[ -z "$RUN_TYPE" ]]; then
    printf 'ERROR: --type must be specified\n' 1>&2
    exit 1
fi

echo "sbatch --array=0,4,6,10,12,14,15,16,17,19,20 tacc-slurm-skx.sbatch $RUN_TYPE"
