#!/bin/bash --login

# Job name
#SBATCH --job-name=PHYS_0D_OPT
# Job stdout file
#SBATCH --output=phys_0d_opt.out.%J
# Job stderr file
#SBATCH --error=phys_0d_opt.err.%J
# Number of nodes
#SBATCH --nodes=1
# Number of tasks
#SBATCH --ntasks=1
# Number of CPUs per task
#SBATCH --cpus-per-task=25
# Parition
#SBATCH --partition=compute
# Time Limit (1440 = 24hrs)
#SBATCH --time=2880
# Account name
#SBATCH --account=scw1706
# Email alerts
#SBATCH --mail-user=2026353@swansea.ac.uk
#SBATCH --mail-type=ALL

module load singularity/3.8.5

# START, NUM and TOTAL are environment variables
# as sbatch scripts don't allow for command line arguments.

srun singularity exec --bind "$(pwd)":/app cl0.sif \
python3 scripts/optimisation_from_physiological_db_example.py \
--start ${START} --total ${TOTAL} --num_workers ${NUM} 
