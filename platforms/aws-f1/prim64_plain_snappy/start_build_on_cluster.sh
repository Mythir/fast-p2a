#!/bin/bash

#SBATCH -J vivado-2018.3           # Job name
#SBATCH -o vivado-2018.3.%j.out    # Name of stdout output file (%j expands to jobId)
#SBATCH -n 1                       # 1 task
#SBATCH -c 2                       # 2 CPUs per task (HT)
#SBATCH -t 18:30:00                 # Run time (hh:mm:ss) - 18 hours and 30 min
#SBATCH --mem 16G                  # use 16GB memory
#SBATCH --mail-user=l.t.j.vanleeuwen@student.tudelft.nl
#SBATCH --mail-type=ALL

source /home/ltjvanleeuwen/github/fletcher/env.sh
source /opt/applics/bin/xilinx-vivado-2018.3.sh
source /home/ltjvanleeuwen/bulk/github/fast-p2a/env.sh
source /home/ltjvanleeuwen/github/aws-fpga/hdk_setup.sh

export CL_DIR=/home/ltjvanleeuwen/bulk/github/fast-p2a/platforms/aws-f1/prim64_plain_snappy

cd $CL_DIR/build/scripts
source ./aws_build_dcp_from_cl.sh -clock_recipe_a A1 -foreground
