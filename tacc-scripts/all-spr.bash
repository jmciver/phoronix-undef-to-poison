#!/usr/bin/bash

sbatch --array=1,2,3,5,7,8,9,11,21 tacc-slurm-spr.sbatch
