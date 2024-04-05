#! /bin/bash
set -x

max_nodes=24

for i in {0..${max_nodes}} do
         sbatch scripts/physiological_opti_sbatch.sh ${i} ${max_nodes}
         sleep 30
done
