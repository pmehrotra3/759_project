#!/usr/bin/env bash
# Slurm job: build and run the GPU game runner.
# Submit from inside this folder with:  sbatch run_games.sh
#SBATCH --job-name=othello_gpu
#SBATCH --partition=instruction
#SBATCH --gres=gpu:1
#SBATCH --cpus-per-task=1
#SBATCH --time=00:10:00
#SBATCH --output=run_games.out

module load nvidia/cuda 2>/dev/null || true

make
nvidia-smi --query-gpu=name,driver_version --format=csv
./run_games 1000000 256 100000
