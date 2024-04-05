#! /bin/bash
set -x

for i in {0..24} do
         sbatch scripts/physiological_opti_sbatch.sh i 24
         sleep 30
done
