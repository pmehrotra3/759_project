#pragma once
// ---------------------------------------------------------------------------
// rules_extra.cuh 
//
// Small helpers the search needs that are not in othello.cuh yet:
// start position, game over, final result, passing, and a random generator.
// When your teammate's versions land, swap these out.
// ---------------------------------------------------------------------------
#include "../othello.cuh"

// An "action" is what the search and the net talk about:
//   0..63 = place a disc on that square,  64 = pass.
#define NUM_ACTIONS 65
#define PASS_ACTION 64

// ---- bit tricks (different names on CPU and GPU) ---------------------------
HD int popcount64(uint64_t x) {
#ifdef __CUDA_ARCH__
    return __popcll(x);
#else
    return __builtin_popcountll(x);
#endif
}
// Index of the lowest set bit. x must not be 0.
HD int lowest_square(uint64_t x) {
#ifdef __CUDA_ARCH__
    return __ffsll(x) - 1;
#else
    return __builtin_ctzll(x);
#endif
}

// ---- positions --------------------------------------------------------------
HD Board start_board() {
    Board b;
    b.black = (1ULL << 28) | (1ULL << 35);
    b.white = (1ULL << 27) | (1ULL << 36);
    b.side  = 0;                       // black moves first
    return b;
}

// Legal moves for whoever is to move in b (bit i set = square i is legal).
HD uint64_t legal_now(const Board &b) {
    return b.side == 0 ? legal_moves(b.black, b.white)
                       : legal_moves(b.white, b.black);
}

// The game is over when neither player has a legal move.
HD bool is_game_over(const Board &b) {
    return legal_moves(b.black, b.white) == 0 && legal_moves(b.white, b.black) == 0;
}

// Final result seen by the player TO MOVE in b: +1 win, 0 draw, -1 loss.
HD float result_for_side_to_move(const Board &b) {
    int diff = popcount64(b.black) - popcount64(b.white);   // > 0 means black is ahead
    if (b.side == 1) diff = -diff;
    return diff > 0 ? 1.0f : (diff < 0 ? -1.0f : 0.0f);
}

// Return the board after playing 'action' (0..63, or PASS_ACTION).
// The side to move always switches, also on a pass.
HD Board apply_action(Board b, int action) {
    make_move(b, action == PASS_ACTION ? -1 : action);
    return b;
}

// ---- random numbers ---------------------------------------------------------
// Tiny generator that gives the same numbers on CPU and GPU.
HD uint64_t splitmix64(uint64_t *s) {
    uint64_t z = (*s += 0x9e3779b97f4a7c15ULL);
    z = (z ^ (z >> 30)) * 0xbf58476d1ce4e5b9ULL;
    z = (z ^ (z >> 27)) * 0x94d049bb133111ebULL;
    return z ^ (z >> 31);
}

// Pick one set bit of 'moves' uniformly at random. moves must not be 0.
HD int random_square(uint64_t moves, uint64_t *rng) {
    int k = (int)(splitmix64(rng) % (uint64_t)popcount64(moves));
    while (k--) moves &= moves - 1;    // drop the lowest set bit k times
    return lowest_square(moves);
}
