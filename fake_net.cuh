#pragma once
// ---------------------------------------------------------------------------
// fake_net.cuh
//
// Stands in for the neural net until the real one exists.
// A net takes a board and returns two things:
//   prior[a] : how promising each action looks (sums to 1 over legal actions)
//   value    : who is winning, from -1 to +1, seen by the player TO MOVE
//
// This fake version says "every legal move is equally promising" and gets the
// value by playing random moves to the end of the game. That turns the search
// into classic Monte Carlo tree search, which is strong enough to test with.
// ---------------------------------------------------------------------------
#include "rules_extra.cuh"

struct NetOutput {
    float prior[NUM_ACTIONS];
    float value;
};

HD void fake_net(const Board &board, uint64_t *rng, NetOutput *out) {
    // ---- prior: uniform over legal moves (or all on "pass") ----
    for (int a = 0; a < NUM_ACTIONS; a++) out->prior[a] = 0.0f;
    uint64_t legal = legal_now(board);
    if (legal == 0) {
        out->prior[PASS_ACTION] = 1.0f;
    } else {
        float p = 1.0f / (float)popcount64(legal);
        for (uint64_t m = legal; m; m &= m - 1) out->prior[lowest_square(m)] = p;
    }

    // ---- value: one random playout to the end of the game ----
    Board b = board;
    while (!is_game_over(b)) {
        uint64_t m = legal_now(b);
        b = apply_action(b, m ? random_square(m, rng) : PASS_ACTION);
    }
    float v = result_for_side_to_move(b);        // seen by the mover in the FINAL board
    out->value = (b.side == board.side) ? v : -v; // convert to the mover in 'board'
}
