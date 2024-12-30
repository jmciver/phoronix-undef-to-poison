#!/usr/bin/bash

set -u

declare -r buildType="main"

# pushd tacc-scripts
for idNumber in {0,2,3,5,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21}; do
    declare scriptName=$(printf 'pts-alive2-%s-%02d.sbatch' "${buildType}" "${idNumber}")
    printf "INFO: submit %s\n" "$scriptName"
    sbatch "$scriptName"
    sleep 1
done
# popd
