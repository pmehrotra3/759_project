// ---------------------------------------------------------------------------
// run_games.cu
//
// Plays N random Othello games on the GPU, prints the results and the
// throughput, then replays some of the same games on the CPU to check that
// the GPU got exactly the same answers (and to compare speed).
//
// Usage: ./run_games [num_games] [threads_per_block] [games_to_check_on_cpu] [seed]
// ---------------------------------------------------------------------------
#include <chrono>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include "gpu_game_runner.cuh"

static void print_stats(const char *label, const GameStats &s) {
    double g = (double)s.games();
    printf("%s\n", label);
    printf("  games played : %lld\n", s.games());
    printf("  black wins   : %lld (%.2f%%)\n", s.black_wins, 100.0 * s.black_wins / g);
    printf("  white wins   : %lld (%.2f%%)\n", s.white_wins, 100.0 * s.white_wins / g);
    printf("  draws        : %lld (%.2f%%)\n", s.draws, 100.0 * s.draws / g);
    printf("  avg moves    : %.2f\n", s.total_moves / g);
}

int main(int argc, char **argv) {
    int num_games      = argc > 1 ? atoi(argv[1]) : 1000000;
    int threads        = argc > 2 ? atoi(argv[2]) : 256;
    int cpu_check      = argc > 3 ? atoi(argv[3]) : 100000;
    uint64_t seed      = argc > 4 ? strtoull(argv[4], nullptr, 10) : 759;
    if (cpu_check > num_games) cpu_check = num_games;

    // ---- which GPU are we on? ----
    int device_count = 0;
    if (cudaGetDeviceCount(&device_count) != cudaSuccess || device_count == 0) {
        printf("No NVIDIA GPU found.\n");
        return 1;
    }
    cudaDeviceProp prop;
    CUDA_CHECK(cudaGetDeviceProperties(&prop, 0));
    printf("GPU: %s (compute %d.%d, %d SMs)\n\n", prop.name, prop.major, prop.minor,
           prop.multiProcessorCount);

    GpuGameRunner runner(num_games, threads);
    runner.run(seed + 1);                 // warm-up launch (not timed)
    float gpu_ms = runner.run(seed);      // the timed run
    GameStats gpu = runner.stats();

    print_stats("=== GPU results ===", gpu);
    printf("  kernel time  : %.3f ms  (%d threads/block)\n", gpu_ms, threads);
    printf("  throughput   : %.3e games/s, %.3e moves/s\n\n",
           num_games / (gpu_ms / 1e3), gpu.total_moves / (gpu_ms / 1e3));

    // ---- replay the first cpu_check games on the CPU and compare ----
    if (cpu_check > 0) {
        GameStats cpu;
        int mismatches = 0;
        auto t0 = std::chrono::high_resolution_clock::now();
        for (int i = 0; i < cpu_check; i++) {
            GameResult r = play_random_game(seed, i);
            cpu.add(r);
            const GameResult &g = runner.results()[i];
            if (r.black != g.black || r.white != g.white || r.moves != g.moves || r.winner != g.winner)
                mismatches++;
        }
        auto t1 = std::chrono::high_resolution_clock::now();
        double cpu_ms = std::chrono::duration<double, std::milli>(t1 - t0).count();

        print_stats("=== CPU check (same seeds) ===", cpu);
        printf("  cpu time     : %.3f ms\n", cpu_ms);
        printf("  throughput   : %.3e games/s (1 core)\n", cpu_check / (cpu_ms / 1e3));
        printf("  speedup      : %.1fx (GPU vs 1 CPU core)\n",
               (num_games / gpu_ms) / (cpu_check / cpu_ms));
        printf("  GPU == CPU   : %s (%d / %d games differ)\n",
               mismatches == 0 ? "PASS" : "FAIL", mismatches, cpu_check);
        if (mismatches) return 1;
    }
    return 0;
}
