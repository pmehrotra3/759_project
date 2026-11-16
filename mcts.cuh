#pragma once
// ---------------------------------------------------------------------------
// mcts.cuh
//
// The AlphaZero search for ONE game, in plain C++.
// Every function is marked HD, so later the exact same code can run inside a
// CUDA kernel with one thread per game. To keep that possible:
//   - no new / malloc / std::vector / pointers between nodes
//   - no recursion
//   - everything lives in fixed-size arrays
//
// THE IDEA IN FIVE LINES
//   The tree remembers positions we have looked at. Node 0 (the "root") is the
//   real position on the board. One "simulation" does three things:
//     1. SELECT : walk down from the root, picking the most promising action
//                 at each node, until we step off the tree. Add ONE new node.
//     2. EVALUATE: ask the net how good that new position is.
//     3. BACKUP : go back up the same path and record that result on the way.
//   After a few hundred simulations, the action tried most often at the root
//   is the move we play.
//
// THE ONE RULE ABOUT VALUES (most bugs come from this)
//   A value is always seen by the player TO MOVE in that position.
//   +1 = that player wins, -1 = that player loses.
//   The player to move switches on every action (also on a pass), so a value
//   changes sign every time it moves one step up the tree.
// ---------------------------------------------------------------------------
#include <cmath>
#include "rules_extra.cuh"
#include "fake_net.cuh"

#define MAX_NODES 512     // room for the root + one new node per simulation
#define MAX_DEPTH 128     // a game cannot be longer than this many actions
#define C_PUCT    1.5f    // how much the search explores (bigger = more exploring)

// One position in the tree, plus statistics about each action from it.
// The arrays are indexed by action: 0..63 = square, 64 = pass.
struct Node {
    Board    board;                   // the position
    uint64_t legal;                   // legal moves for the player to move (0 = must pass, or game over)
    int      terminal;                // 1 if the game is over in this position
    float    terminal_value;          // if terminal: result seen by the player to move here
    int      total_visits;            // how many simulations went through this node and took an action
    int      child[NUM_ACTIONS];      // index of the node that action a leads to, -1 = not in the tree yet
    int      visits[NUM_ACTIONS];     // N(a): how many simulations took action a
    float    value_sum[NUM_ACTIONS];  // W(a): sum of the results of those simulations,
                                      //       seen by the player to move in THIS node
    float    prior[NUM_ACTIONS];      // P(a): the net's guess of how promising action a is
};

// The whole tree is one array. Nodes 0 .. count-1 are in use. Node 0 is the root.
struct Tree {
    int  count;
    Node nodes[MAX_NODES];
};

// The route one simulation took from the root: at node[i] it took action[i].
struct Path {
    int depth;                 // how many steps are stored
    int node[MAX_DEPTH];
    int action[MAX_DEPTH];
};

// Steps:
//   - the new node's index is tree.count; then increase tree.count by 1
//   - fill in board, legal (use legal_now), terminal (use is_game_over)
//   - terminal_value = result_for_side_to_move(board) if terminal, else 0
//   - total_visits = 0
//   - for every action a: child = -1, visits = 0, value_sum = 0, prior = 0
HD int add_node(Tree &tree, const Board &board) {
    int count = tree.count;
    tree.count++;
    Node &cur = tree.nodes[count];   // write straight into the array (no 1 KB copy)
    cur.board = board;
    cur.legal = legal_now(board);
    cur.terminal = is_game_over(board);
    if (cur.terminal){
        cur.terminal_value = result_for_side_to_move(board);
    } else{
        cur.terminal_value = 0;
    }
    cur.total_visits = 0;
    for (int i = 0; i < NUM_ACTIONS;i++){
        cur.child[i] = -1;
        cur.visits[i] = 0;
        cur.value_sum[i] = 0;
        cur.prior[i] = 0;
    }
    return count;

}

//   Q = value_sum[a] / visits[a]          average result so far (use 0 if visits[a] == 0)
//   U = C_PUCT * prior[a] * sqrt(total_visits + 1) / (1 + visits[a])
//   score = Q + U
// Q says "this has worked well". U says "the net likes this and we have not
// tried it much". U shrinks as visits[a] grows, so the search moves on.
// Use sqrtf, and cast the ints to float before dividing.
HD float puct_score(const Node &n, int a) {
    float Q = 0;
    if (n.visits[a] != 0){
        Q = n.value_sum[a] / (float)n.visits[a];
    }
    float U = C_PUCT * n.prior[a] * sqrtf((float)n.total_visits + 1.0f) / (1.0f + (float)n.visits[a]);
    return Q+U;
}

// ---------------------------------------------------------------------------
// TODO 3: pick the legal action with the highest puct_score
// ---------------------------------------------------------------------------
//   - if n.legal == 0 the player must pass: return PASS_ACTION
//   - otherwise loop over the set bits of n.legal:
//         for (uint64_t m = n.legal; m; m &= m - 1) { int a = lowest_square(m); ... }
//   - on a tie keep the first one found (use > and not >=), so results are reproducible
// This is only called on nodes that are not terminal.
HD int select_action(const Node &n) {
    // TODO 3
    return -1;
}

// ---------------------------------------------------------------------------
// TODO 4: SELECT - walk down the tree and add one new node
// ---------------------------------------------------------------------------
// Start with cur = 0 (the root) and path.depth = 0. Then repeat:
//   a. if node cur is terminal: stop and return cur (nothing is added)
//   b. a = select_action(node cur)
//   c. store the step: path.node[path.depth] = cur, path.action[path.depth] = a,
//      then increase path.depth
//   d. if child[a] is -1: make the new position with apply_action(board, a),
//      add it with add_node, store the new index in child[a], and return it
//   e. otherwise move down: cur = child[a]
// Returns the index of the leaf: a brand-new node, or an old terminal one.
HD int select_leaf(Tree &tree, Path &path) {
    path.depth = 0;
    // TODO 4
    return 0;
}

// ---------------------------------------------------------------------------
// TODO 5: EXPAND - copy the net's priors into the leaf node
// ---------------------------------------------------------------------------
// One loop over all NUM_ACTIONS actions. (With the real net this is also where
// illegal moves will be masked out. The fake net has already done that.)
HD void expand(Tree &tree, int leaf, const NetOutput &out) {
    // TODO 5
}

// ---------------------------------------------------------------------------
// TODO 6: BACKUP - record the result along the path, from the bottom up
// ---------------------------------------------------------------------------
// leaf_value is seen by the player to move AT THE LEAF.
// Go through the path backwards (i = path.depth - 1 down to 0). At each step:
//   - flip the sign of the value FIRST (the node one step up belongs to the other player)
//   - in node path.node[i], for action path.action[i]:
//         visits += 1,  value_sum += value,  and the node's total_visits += 1
HD void backup(Tree &tree, const Path &path, float leaf_value) {
    // TODO 6
}

// ---------------------------------------------------------------------------
// TODO 7: the move to play = the root action with the most visits
// ---------------------------------------------------------------------------
//   - if the root has no legal moves return PASS_ACTION
//   - otherwise loop over the set bits of the root's legal mask, like TODO 3
//   - on a tie keep the first one found
HD int best_action(const Tree &tree) {
    // TODO 7
    return -1;
}

// ===========================================================================
// COMPLETE from here down. Read it: this is how the pieces fit together, and
// it is the part that will be split into kernels later.
// ===========================================================================

// Start a fresh tree whose root is the current real position.
HD void tree_init(Tree &tree, const Board &root_board, uint64_t *rng) {
    tree.count = 0;
    int root = add_node(tree, root_board);
    if (!tree.nodes[root].terminal) {
        NetOutput out;
        fake_net(root_board, rng, &out);
        expand(tree, root, out);          // the root needs priors too; its value is not used
    }
}

// One simulation. Call tree_init first, and at most MAX_NODES - 1 times per tree.
HD void run_simulation(Tree &tree, uint64_t *rng) {
    Path path;

    // 1. SELECT                              (later: kernel A, one thread per game)
    int leaf = select_leaf(tree, path);

    // 2. EVALUATE                            (later: one batched call to the real net)
    float value;
    if (tree.nodes[leaf].terminal) {
        value = tree.nodes[leaf].terminal_value;   // game over: we know the result, no net needed
    } else {
        NetOutput out;
        fake_net(tree.nodes[leaf].board, rng, &out);
        expand(tree, leaf, out);                   // (later: kernel B, together with backup)
        value = out.value;
    }

    // 3. BACKUP
    backup(tree, path, value);
}
