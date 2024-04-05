#!/bin/bash --login

# Job name
#SBATCH --job-name=PHYS_0D_OPT
# Job stdout file
#SBATCH --output=phys_0d_opt.out.%J
# Job stderr file
#SBATCH --error=phys_0d_opt.err.%J
# Number of tasks
#SBATCH --ntasks=1
# Number of CPUs per task
#SBATCH --cpus-per-task=40
# Account name
#SBATCH --account=scw1706
# Email alerts
#SBATCH --mail-user=2026353@swansea.ac.uk
#SBATCH --mail-type=ALL

module load singularity/3.8.5

srun singularity run --bind "$(pwd)":/app cl0.sif \ 
./scripts/optimisation_from_physiological_db_example.py \
--node $1
--max_node $2
