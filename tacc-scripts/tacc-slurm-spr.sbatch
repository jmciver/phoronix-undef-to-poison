#!/usr/bin/bash
#
#SBATCH -J pts-alive2-run
#SBATCH -p spr
#SBATCH -N 1                    # Total nodes per job
#SBATCH -t 48:00:00
#SBATCH -o pts-alive2-%A_%a.out # Standard output
#SBATCH -e pts-alive2-%A_%a.err # Standard error
module load tacc-apptainer

cd $WORK/phoronix
./run-pts.bash \
    --no-cpu-checks \
    --container=apptainer \
    --llvm=$HOME/llvm-phoronix/apptainer/base-sroa-gvn \
    --scratch=$SCRATCH/pts-alive-runs-test \
    -- \
    --number-of-cores=56 \
    --number-of-threads=112 \
    --pts-alive2=${SLURM_ARRAY_TASK_ID}
