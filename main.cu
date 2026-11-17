#include "othello.cuh"
#include <cstdio>

// Print the board: X = black, O = white, . = legal move, - = empty
void print_board(const Board& b) {
    uint64_t me    = (b.side == 0) ? b.black : b.white;
    uint64_t opp   = (b.side == 0) ? b.white : b.black;
    uint64_t legal = legal_moves(me, opp);

    printf("  a b c d e f g h\n");
    for (int row = 0; row < 8; row++) {
        printf("%d ", 8 - row);                    // row 0 is the top (rank 8)
        for (int col = 0; col < 8; col++) {
            uint64_t bit = 1ULL << (row * 8 + col);
            if      (b.black & bit) printf("X ");
            else if (b.white & bit) printf("O ");
            else if (legal   & bit) printf(". ");
            else                    printf("- ");
        }
        printf("\n");
    }
    printf("%s to move\n\n", b.side == 0 ? "Black (X)" : "White (O)");
}

int main() {
    Board b = { (1ULL << 27) | (1ULL << 36),   // black: d5, e4
                (1ULL << 28) | (1ULL << 35),   // white: e5, d4
                0 };                           // black to move
    print_board(b);

    char in[8];
    printf("Your move (like d3): ");
    while (scanf("%7s", in) == 1) {
        int col = in[0] - 'a';                 // 'd' -> 3
        int row = 8 - (in[1] - '0');           // '3' -> row 5
        int sq  = row * 8 + col;

        uint64_t me    = (b.side == 0) ? b.black : b.white;
        uint64_t opp   = (b.side == 0) ? b.white : b.black;
        uint64_t legal = legal_moves(me, opp);

        if (col < 0 || col > 7 || row < 0 || row > 7 || !(legal & (1ULL << sq))) {
            printf("Not a legal move, try again: ");
            continue;
        }
        make_move(b, sq);

        // If the next player has no moves: pass, or stop if nobody can move
        me  = (b.side == 0) ? b.black : b.white;
        opp = (b.side == 0) ? b.white : b.black;
        if (!legal_moves(me, opp)) {
            if (!legal_moves(opp, me)) {
                print_board(b);
                printf("Game over! Black (X): %d  White (O): %d\n",
                       count_discs(b.black), count_discs(b.white));
                int w = winner(b);
                if      (w == 0) printf("Black (X) wins!\n");
                else if (w == 1) printf("White (O) wins!\n");
                else             printf("It's a draw!\n");
                break;
            }
            printf("No moves, pass!\n");
            make_move(b, -1);
        }
        print_board(b);
        printf("Your move: ");
    }
}
