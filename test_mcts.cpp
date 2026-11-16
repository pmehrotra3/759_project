// ---------------------------------------------------------------------------
// test_mcts.cpp
//
// Build and run from this folder:
//     g++ -O2 -std=c++17 -Wall test_mcts.cpp -o test_mcts && ./test_mcts
//
// The checks run in order and stop at the first failure, so fix them one at a
// time. Each check names the TODO in mcts.cuh it is testing.
// ---------------------------------------------------------------------------
#include <cstdio>
#include <cstdlib>
#include <memory>
#include "mcts.cuh"

static void check(bool ok, const char *what) {
    if (ok) { printf("  ok    %s\n", what); return; }
    printf("  FAIL  %s\n", what);
    exit(1);
}

// One game: the search plays 'mcts_side' (0 black, 1 white), random plays the other.
// Returns the result seen by the search: +1 win, 0 draw, -1 loss.
static float play_game(Tree &tree, int mcts_side, int sims, uint64_t seed) {
    uint64_t rng = seed;
    Board b = start_board();
    while (!is_game_over(b)) {
        uint64_t legal = legal_now(b);
        int action;
        if (legal == 0) {
            action = PASS_ACTION;
        } else if (b.side == mcts_side) {
            tree_init(tree, b, &rng);
            for (int s = 0; s < sims; s++) run_simulation(tree, &rng);
            action = best_action(tree);
            if (action < 0 || action > 63 || !((legal >> action) & 1)) {
                printf("  FAIL  best_action returned %d, which is not a legal move\n", action);
                exit(1);
            }
        } else {
            action = random_square(legal, &rng);
        }
        b = apply_action(b, action);
    }
    float r = result_for_side_to_move(b);
    return b.side == mcts_side ? r : -r;
}

int main() {
    auto holder = std::make_unique<Tree>();   // a Tree is big, so keep it off the stack
    Tree &tree = *holder;
    uint64_t rng = 12345;

    printf("Check 0: the helper rules\n");
    check(popcount64(legal_now(start_board())) == 4, "start position has 4 legal moves");

    printf("Check 1: add_node (TODO 1)\n");
    tree_init(tree, start_board(), &rng);
    const Node &root = tree.nodes[0];
    check(tree.count == 1, "tree has exactly one node after tree_init");
    check(root.legal == legal_now(start_board()), "root.legal is the legal-move mask");
    check(root.terminal == 0 && root.total_visits == 0, "root is not terminal and has 0 visits");
    bool clean = true;
    for (int a = 0; a < NUM_ACTIONS; a++)
        if (root.child[a] != -1 || root.visits[a] != 0 || root.value_sum[a] != 0.0f) clean = false;
    check(clean, "every child is -1 and every count is 0");

    printf("Check 2: expand (TODO 5)\n");
    float psum = 0;
    for (int a = 0; a < NUM_ACTIONS; a++) psum += root.prior[a];
    check(psum > 0.999f && psum < 1.001f, "root priors sum to 1");

    printf("Check 3: one simulation (TODO 2, 3, 4)\n");
    run_simulation(tree, &rng);
    check(tree.count == 2, "one simulation adds exactly one node");
    check(root.total_visits == 1, "root has 1 visit after one simulation");
    int visited = -1;
    for (int a = 0; a < NUM_ACTIONS; a++) if (root.visits[a] == 1) visited = a;
    check(visited >= 0 && ((root.legal >> visited) & 1), "the visited action is a legal move");
    check(root.child[visited] == 1, "that action's child is the new node");
    check(tree.nodes[1].board.side == 1, "the child position has white to move");

    printf("Check 4: bookkeeping after 200 simulations (TODO 4, 6)\n");
    for (int s = 1; s < 200; s++) run_simulation(tree, &rng);
    check(tree.count == 201, "200 simulations from the start add 200 nodes");
    check(root.total_visits == 200, "root has 200 visits");
    bool sums_ok = true, parent_ok = true, range_ok = true;
    for (int i = 0; i < tree.count; i++) {
        const Node &n = tree.nodes[i];
        int sum = 0;
        for (int a = 0; a < NUM_ACTIONS; a++) {
            sum += n.visits[a];
            if (n.value_sum[a] > n.visits[a] + 1e-3f || n.value_sum[a] < -n.visits[a] - 1e-3f) range_ok = false;
            // An edge visited N times: the first visit created the child, the
            // other N-1 visits went on through the child.
            if (n.child[a] >= 0 && !tree.nodes[n.child[a]].terminal &&
                tree.nodes[n.child[a]].total_visits != n.visits[a] - 1) parent_ok = false;
        }
        if (sum != n.total_visits) sums_ok = false;
    }
    check(sums_ok, "in every node, visits[] adds up to total_visits");
    check(parent_ok, "every child has (visits of the edge into it) - 1 visits");
    check(range_ok, "every value_sum[a] is between -visits[a] and +visits[a]");

    printf("Check 5: the sign of the values (TODO 6)\n");
    // Black to move, one move left (the top-left corner), and it wins the game.
    Board w;
    w.black = 0x0000000ffffffffcULL;   // 34 discs
    w.white = 0xfffffff000000002ULL;   // 29 discs, square 0 is empty
    w.side  = 0;
    tree_init(tree, w, &rng);
    for (int s = 0; s < 20; s++) run_simulation(tree, &rng);
    check(tree.nodes[0].visits[0] == 20, "all 20 simulations go to the only move");
    check(tree.nodes[0].value_sum[0] == 20.0f, "a winning move has value_sum = +visits (not -visits)");

    printf("Check 6: playing strength (TODO 7, and everything together)\n");
    int games = 100, sims = 100;
    float points = 0;
    for (int g = 0; g < games; g++) {
        float r = play_game(tree, g % 2, sims, 1000 + g);
        points += (r + 1.0f) / 2.0f;          // win 1, draw 0.5, loss 0
    }
    printf("        search (%d sims) vs random: %.1f / %d points\n", sims, points, games);
    check(points >= 85.0f, "search scores at least 85 of 100 against random");

    printf("\nALL CHECKS PASSED\n");
    return 0;
}
