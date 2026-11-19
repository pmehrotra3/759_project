#pragma once
// ---------------------------------------------------------------------------
// gpu_game_runner.cuh
//
// GpuGameRunner: plays many Othello games at once on the GPU.
// One CUDA thread plays one whole game. The class owns the GPU memory,
// launches the kernel, times it, and copies the results back.
//
//   GpuGameRunner runner(1000000);      // room for 1M games
//   float ms = runner.run(seed);        // play them, returns kernel time in ms
//   GameStats s = runner.stats();       // wins / draws / moves
// ---------------------------------------------------------------------------
#include <cstdio>
#include <cstdlib>
#include <vector>
#include <cuda_runtime.h>
#include "game_logic.cuh"

#define CUDA_CHECK(call)                                                      \
    do {                                                                      \
        cudaError_t err_ = (call);                                            \
        if (err_ != cudaSuccess) {                                            \
            fprintf(stderr, "CUDA error %s at %s:%d\n",                       \
                    cudaGetErrorString(err_), __FILE__, __LINE__);            \
            exit(1);                                                          \
        }                                                                     \
    } while (0)

// One thread = one game
__global__ void play_games_kernel(GameResult *out, int num_games, uint64_t seed) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < num_games) out[i] = play_random_game(seed, i);
}

// Totals over a batch of games
struct GameStats {
    long long black_wins = 0, white_wins = 0, draws = 0, total_moves = 0;

    void add(const GameResult &r) {
        if (r.winner == 0)      black_wins++;
        else if (r.winner == 1) white_wins++;
        else                    draws++;
        total_moves += r.moves;
    }
    long long games() const { return black_wins + white_wins + draws; }
};

class GpuGameRunner {
public:
    explicit GpuGameRunner(int num_games, int threads_per_block = 256)
        : num_games_(num_games), threads_(threads_per_block), host_(num_games) {
        CUDA_CHECK(cudaMalloc(&dev_, sizeof(GameResult) * num_games_));
        CUDA_CHECK(cudaEventCreate(&start_));
        CUDA_CHECK(cudaEventCreate(&stop_));
    }

    ~GpuGameRunner() {
        cudaFree(dev_);
        cudaEventDestroy(start_);
        cudaEventDestroy(stop_);
    }

    GpuGameRunner(const GpuGameRunner &) = delete;
    GpuGameRunner &operator=(const GpuGameRunner &) = delete;

    // Play all games on the GPU and copy the results back.
    // Returns the time spent in the kernel only, in milliseconds.
    float run(uint64_t seed) {
        int blocks = (num_games_ + threads_ - 1) / threads_;
        CUDA_CHECK(cudaEventRecord(start_));
        play_games_kernel<<<blocks, threads_>>>(dev_, num_games_, seed);
        CUDA_CHECK(cudaEventRecord(stop_));
        CUDA_CHECK(cudaGetLastError());
        CUDA_CHECK(cudaEventSynchronize(stop_));
        float ms = 0;
        CUDA_CHECK(cudaEventElapsedTime(&ms, start_, stop_));
        CUDA_CHECK(cudaMemcpy(host_.data(), dev_, sizeof(GameResult) * num_games_,
                              cudaMemcpyDeviceToHost));
        return ms;
    }

    const std::vector<GameResult> &results() const { return host_; }
    int num_games() const { return num_games_; }

    GameStats stats() const {
        GameStats s;
        for (const GameResult &r : host_) s.add(r);
        return s;
    }

private:
    int num_games_;
    int threads_;
    GameResult *dev_ = nullptr;
    std::vector<GameResult> host_;
    cudaEvent_t start_, stop_;
};
