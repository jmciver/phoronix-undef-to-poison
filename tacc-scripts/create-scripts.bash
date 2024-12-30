#!/usr/bin/bash

set -u

function createJobScript() {
    declare buildType="$1"
    declare idNumber="$2"
    declare commonName=$(printf 'pts-alive2-%s-%02d' "${buildType}" "${idNumber}")
cat <<-EOF > "${commonName}.sbatch"
#!/usr/bin/bash
#
#SBATCH -J ${commonName}
#SBATCH -p skx
#SBATCH -N 1                    # Total nodes per job
#SBRACH -n 1                    # Total number of tasks requested
#SBATCH -t 48:00:00
#SBATCH -o ${commonName}-%j.out
#SBATCH -e ${commonName}-%j.err
module load tacc-apptainer

cd \$WORK/phoronix
./run-pts.bash \\
    --no-cpu-checks \\
    --container=apptainer \\
    --llvm=\$HOME/llvm-phoronix/apptainer/${buildType}-sroa-gvn \\
    --scratch=\$SCRATCH/pts-alive-runs-test \\
    -- \\
    --number-of-cores=24 \\
    --number-of-threads=48 \\
    --pts-alive2=${idNumber}
EOF
}

for ((index=0; index < 23; index++)); do
    createJobScript "main" "$index"
done
