#!/usr/bin/bash
#
#SBATCH -J pts-alive2-run
#SBATCH -p skx
#SBATCH -N 1                    # Total nodes per job
#SBATCH -o pts-alive2-%A_%a.out # Standard output
#SBATCH -e pts-alive2-%A_%a.err # Standard error
declare buildType=$1

module load tacc-apptainer

cd ${WORK}/phoronix
./run-pts.bash \
    --no-cpu-checks \
    --container=apptainer \
    --llvm=${WORK}/llvm-phoronix/apptainer/${buildType}-sroa-gvn \
    --scratch=${SCRATCH}/pts-alive-runs-${buildType} \
    -- \
    --number-of-cores=24 \
    --number-of-threads=48 \
    --pts-alive2=${SLURM_ARRAY_TASK_ID}
