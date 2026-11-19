#pragma once
// ---------------------------------------------------------------------------
// game_logic.cuh
//
// Plays ONE full game of Othello with random moves for both sides.
// Every function is HD, so the exact same code runs on the CPU and inside a
// CUDA kernel (one GPU thread = one game). Because the random numbers come
// from a seed, the CPU and GPU produce identical games, which lets us check
// that the GPU is computing the right thing.
// ---------------------------------------------------------------------------
#include "../othello.cuh"

// Result of one finished game
struct GameResult {
    uint64_t black;   // final black discs
    uint64_t white;   // final white discs
    int moves;        // discs placed (passes not counted)
    int winner;       // 0 = black, 1 = white, -1 = draw
};

// Standard start: black on d5 (27) and e4 (36), white on e5 (28) and d4 (35)
HD Board start_position() {
    Board b;
    b.black = (1ULL << 27) | (1ULL << 36);
    b.white = (1ULL << 28) | (1ULL << 35);
    b.side  = 0;
    return b;
}

// Index of the lowest set bit. x must not be 0.
HD int lowest_bit(uint64_t x) {
#ifdef __CUDA_ARCH__
    return __ffsll((long long)x) - 1;
#else
    return __builtin_ctzll(x);
#endif
}

// Small random number generator that gives the same numbers on CPU and GPU
HD uint64_t next_random(uint64_t *s) {
    uint64_t z = (*s += 0x9e3779b97f4a7c15ULL);
    z = (z ^ (z >> 30)) * 0xbf58476d1ce4e5b9ULL;
    z = (z ^ (z >> 27)) * 0x94d049bb133111ebULL;
    return z ^ (z >> 31);
}

// Pick one of the set bits in 'moves' at random. moves must not be 0.
HD int random_move(uint64_t moves, uint64_t *rng) {
    int k = (int)(next_random(rng) % (uint64_t)count_discs(moves));
    while (k--) moves &= moves - 1;   // drop the lowest set bit k times
    return lowest_bit(moves);
}

// Play game number 'game_id' from start to finish with random moves.
HD GameResult play_random_game(uint64_t seed, int game_id) {
    uint64_t rng = seed ^ ((uint64_t)game_id * 0xd1b54a32d192ed03ULL);
    Board b = start_position();
    int moves = 0;
    while (true) {
        uint64_t me    = (b.side == 0) ? b.black : b.white;
        uint64_t opp   = (b.side == 0) ? b.white : b.black;
        uint64_t legal = legal_moves(me, opp);
        if (legal == 0) {
            if (legal_moves(opp, me) == 0) break;   // nobody can move: game over
            make_move(b, -1);                        // pass
            continue;
        }
        make_move(b, random_move(legal, &rng));
        moves++;
    }
    GameResult r;
    r.black  = b.black;
    r.white  = b.white;
    r.moves  = moves;
    r.winner = winner(b);
    return r;
}
