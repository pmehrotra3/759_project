#pragma once // read this file only once even if it is included multiple times
#include <cstdint> // this gives us uint64_t
#ifdef __CUDACC__ // if gpu compiler is reading the file
#define HD  __host__ __device__ __forceinline__ // this means the function can be called from both CPU and GPU
#define HDR __host__ __device__        // recursive functions cannot be force-inlined
#else                                  // compiling with g++
#define HD  static inline
#define HDR static
#endif

// ---------------------------------------------------------------------------
// Step 1: the board as two 64-bit numbers
// ---------------------------------------------------------------------------
struct Board{
    uint64_t black;
    uint64_t white;
    int side;   // 0 = black to move, 1 = white to move
};

// Squares are numbered sq = row * 8 + col (0 = top-left, 63 = bottom-right)

// ---------------------------------------------------------------------------
// Step 2: shift a bitboard one step in a direction
// ---------------------------------------------------------------------------
// Masks that stop discs wrapping from one edge of the board to the other
#define NOT_COL0 0xfefefefefefefefeULL   // every square except column 0
#define NOT_COL7 0x7f7f7f7f7f7f7f7fULL   // every square except column 7

// Move every bit one step in direction d (0..7)
HD uint64_t shift(uint64_t b, int d) {
    switch (d) {
        case 0: return (b << 1) & NOT_COL0;  // right
        case 1: return (b >> 1) & NOT_COL7;  // left
        case 2: return  b << 8;              // down
        case 3: return  b >> 8;              // up
        case 4: return (b << 9) & NOT_COL0;  // down-right
        case 5: return (b << 7) & NOT_COL7;  // down-left
        case 6: return (b >> 7) & NOT_COL0;  // up-right
        default:return (b >> 9) & NOT_COL7;  // up-left
    }
}

// ---------------------------------------------------------------------------
// Step 3: which discs flip
// ---------------------------------------------------------------------------
// Which opponent discs flip if 'me' plays on square sq
HD uint64_t get_flips(uint64_t me, uint64_t opp, int sq) {
    uint64_t move  = 1ULL << sq;
    uint64_t flips = 0;
    for (int d = 0; d < 8; d++) {
        uint64_t line = 0;
        uint64_t x = shift(move, d);
        while (x & opp) {          // keep walking over opponent discs
            line |= x;
            x = shift(x, d);
        }
        if (x & me) flips |= line; // the line ends on our disc, so it is captured
    }
    return flips;
}

// ---------------------------------------------------------------------------
// Step 4: make a move
// ---------------------------------------------------------------------------
// Assumes the move is legal. sq = -1 means pass.
HD void make_move(Board &b, int sq) {
    if (sq >= 0) {
        uint64_t &me  = (b.side == 0) ? b.black : b.white;
        uint64_t &opp = (b.side == 0) ? b.white : b.black;
        uint64_t flips = get_flips(me, opp, sq);
        me  |= (1ULL << sq) | flips;  // place the new disc and take the flipped ones
        opp &= ~flips;                // the opponent loses the flipped discs
    }
    b.side ^= 1;                      // switch turns
}

// ---------------------------------------------------------------------------
// Step 5: legal move generation
// ---------------------------------------------------------------------------
// Returns a bitboard with a 1 on every square 'me' can legally play
HD uint64_t legal_moves(uint64_t me, uint64_t opp) {
    uint64_t empty = ~(me | opp), moves = 0;
    for (int d = 0; d < 8; d++) {
        uint64_t x = shift(me, d) & opp;                      // opponent discs next to ours
        for (int i = 0; i < 5; i++) x |= shift(x, d) & opp;   // extend along the line (6 discs at most)
        moves |= shift(x, d) & empty;                         // the empty square at the end of the line
    }
    return moves;
}

HD Board makeMove(Board board, uint64_t black, uint64_t white, int side) {
    return {black, white, side};
}





