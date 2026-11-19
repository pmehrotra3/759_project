# Build:  make            (or: make ARCH=sm_80 to target a specific GPU)
# Run:    ./run_games [num_games] [threads_per_block] [games_to_check_on_cpu] [seed]
NVCC  ?= nvcc
ARCH  ?=
FLAGS  = -O3 -std=c++17 $(if $(ARCH),-arch=$(ARCH),)

run_games: run_games.cu gpu_game_runner.cuh game_logic.cuh ../othello.cuh
	$(NVCC) $(FLAGS) run_games.cu -o run_games

clean:
	rm -f run_games

.PHONY: clean
