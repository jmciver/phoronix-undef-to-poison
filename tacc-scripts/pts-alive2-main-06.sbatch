#!/usr/bin/bash
#
#SBATCH -J pts-alive2-main-06
#SBATCH -p skx
#SBATCH -N 1                    # Total nodes per job
#SBRACH -n 1                    # Total number of tasks requested
#SBATCH -t 05:00:00
#SBATCH -o pts-alive2-main-06-%j.out
#SBATCH -e pts-alive2-main-06-%j.err

# On skx the elapsed time was 03:57:03. Rounding to 04:00:00 and 25%
# buffer we can set the wall time to 05:00:00.
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
    --pts-alive2=6
