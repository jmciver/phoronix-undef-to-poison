#!/usr/bin/bash
#
#SBATCH -J pts-alive2-main-12
#SBATCH -p skx
#SBATCH -N 1                    # Total nodes per job
#SBRACH -n 1                    # Total number of tasks requested
#SBATCH -t 48:00:00
#SBATCH -o pts-alive2-main-12-%j.out
#SBATCH -e pts-alive2-main-12-%j.err
module load tacc-apptainer

cd $WORK/phoronix
./run-pts.bash \
    --no-cpu-checks \
    --container=apptainer \
    --llvm=$HOME/llvm-phoronix/apptainer/main-sroa-gvn \
    --scratch=$SCRATCH/pts-alive-runs-test \
    -- \
    --number-of-cores=24 \
    --number-of-threads=48 \
    --pts-alive2=12
