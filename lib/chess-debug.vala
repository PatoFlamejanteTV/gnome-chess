/* -*- Mode: vala; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- */

public class ChessDebug : Object
{
    /**
     * Prints the current board state to stdout using ASCII characters.
     */
    public static void print_board (ChessState state)
    {
        print ("  a b c d e f g h\n");
        print ("  ---------------\n");
        for (int rank = 7; rank >= 0; rank--)
        {
            print ("%d|", rank + 1);
            for (int file = 0; file < 8; file++)
            {
                var piece = state.board[state.get_index (rank, file)];
                if (piece == null)
                    print (" .");
                else
                {
                    unichar symbol = piece.symbol;
                    print (" %s", symbol.to_string ());
                }
            }
            print (" |%d\n", rank + 1);
        }
        print ("  ---------------\n");
        print ("  a b c d e f g h\n");
        print ("Active Player: %s\n", state.current_player.color == Color.WHITE ? "White" : "Black");
        print ("FEN: %s\n", state.get_fen ());
    }

    /**
     * Timer class for benchmarking code blocks.
     */
    public class Timer
    {
        private int64 start_time;

        public Timer ()
        {
            start ();
        }

        public void start ()
        {
            start_time = get_monotonic_time ();
        }

        public double elapsed ()
        {
            return (get_monotonic_time () - start_time) / 1000000.0;
        }

        public void print_elapsed (string label)
        {
            print ("%s: %.6f s\n", label, elapsed ());
        }
    }
}
