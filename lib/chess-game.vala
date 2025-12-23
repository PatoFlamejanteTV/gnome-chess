/* -*- Mode: vala; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*-
 *
 * Copyright (C) 2010-2014 Robert Ancell
 * Copyright (C) 2015-2016 Sahil Sareen
 *
 * This program is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free Software
 * Foundation, either version 3 of the License, or (at your option) any later
 * version. See http://www.gnu.org/copyleft/gpl.html the full text of the
 * license.
 */

public enum ChessResult
{
    IN_PROGRESS,
    WHITE_WON,
    BLACK_WON,
    DRAW,
    BUG
}

public enum ChessRule
{
    UNKNOWN,
    CHECKMATE,
    STALEMATE,
    FIFTY_MOVES,
    SEVENTY_FIVE_MOVES,
    TIMEOUT,
    THREE_FOLD_REPETITION,
    FIVE_FOLD_REPETITION,
    INSUFFICIENT_MATERIAL,
    RESIGN,
    ABANDONMENT,
    DEATH,
    KING_OF_THE_HILL,
    BUG
}

public class ChessGame : Object
{
    public bool is_started;
    public ChessResult result;
    public ChessRule rule;
    public bool king_of_the_hill;
    public bool enable_table_punch;
    public int table_punch_chance;
    public bool is_cylinder;
    public List<ChessState> move_stack;

    /* Cached number of moves in the stack. Used to avoid O(N) length() calls.
     * Note: This must be kept in sync with move_stack modifications.
     * move_stack length is always _n_moves + 1 (for the initial state). */
    private uint _n_moves = 0;
    private int hold_count = 0;

    public const string STANDARD_SETUP = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1";

    public signal void turn_started (ChessPlayer player);
    public signal void moved (ChessMove move);
    public signal void paused ();
    public signal void unpaused ();
    public signal void undo ();
    public signal void ended ();

    public bool is_paused { get; private set; default = false; }
    public bool should_show_paused_overlay { get; private set; default = false; }

    public ChessState current_state
    {
       get { return move_stack.data; }
    }

    public ChessPlayer white
    {
        get { return current_state.players[Color.WHITE]; }
    }
    public ChessPlayer black
    {
        get { return current_state.players[Color.BLACK]; }
    }
    public ChessPlayer current_player
    {
        get { return current_state.current_player; }
    }
    public ChessPlayer opponent
    {
        get { return current_state.opponent; }
    }
    private ChessClock? _clock;
    public ChessClock? clock
    {
        get { return _clock; }
        set
        {
            if (is_started)
                return;
            _clock = value;
        }
    }

    public ChessGame (string fen = STANDARD_SETUP, string[]? moves = null, bool king_of_the_hill = false, bool is_chess960 = false, bool is_dunsany = false, bool is_cylinder = false) throws PGNError
    {
        string start_fen = fen;
        if (is_chess960 && start_fen == STANDARD_SETUP)
        {
             start_fen = get_chess960_fen ();
        }
        else if (is_dunsany && start_fen == STANDARD_SETUP)
        {
             start_fen = get_dunsany_fen ();
        }
        this.king_of_the_hill = king_of_the_hill;
        is_started = false;
        var start_state = new ChessState (start_fen);
        if (is_chess960)
            start_state.is_chess960 = true;
        if (is_dunsany)
            start_state.is_dunsany = true;
        if (is_cylinder)
            start_state.is_cylinder = true;
        move_stack.prepend (start_state);
        result = ChessResult.IN_PROGRESS;

        if (moves != null)
        {
            for (var i = 0; i < moves.length; i++)
            {
                if (!do_move (current_player, moves[i], true))
                {
                    /* Message when the game cannot be loaded due to an invalid move in the file. */
                    throw new PGNError.LOAD_ERROR (_("Failed to load PGN: move %s is invalid."), moves[i]);
                }
            }
        }

        white.do_move.connect (move_cb);
        white.do_undo.connect (undo_cb);
        white.do_resign.connect (resign_cb);
        white.do_claim_draw.connect (claim_draw_cb);
        black.do_move.connect (move_cb);
        black.do_undo.connect (undo_cb);
        black.do_resign.connect (resign_cb);
        black.do_claim_draw.connect (claim_draw_cb);
    }

    ~ChessGame ()
    {
        if (_clock != null)
            _clock.stop ();
    }

    private bool move_cb (ChessPlayer player, string move, bool apply)
    {
        if (!is_started)
            return false;

        return do_move (player, move, apply);
    }

    private bool do_move (ChessPlayer player, string? move, bool apply)
    {
        if (player != current_player)
            return false;

        var state = current_state.copy ();
        state.number++;
        if (!state.move (move, apply))
            return false;

        if (!apply)
            return true;

        move_stack.prepend (state);
        _n_moves++;
        if (state.last_move.victim != null)
            state.last_move.victim.died ();
        state.last_move.piece.moved ();
        if (state.last_move.castling_rook != null)
            state.last_move.castling_rook.moved ();

        /* Table Punch Mechanic */
        if (enable_table_punch && (white.local_human != black.local_human))
        {
             /* Only if Human vs AI */
             /* Trigger chance */
             if (Random.int_range (0, 100) < table_punch_chance)
             {
                 /* Punch the table! */
                 state.scramble_pieces ();
             }
        }

        moved (state.last_move);
        complete_move ();

        return true;
    }

    public void add_hold ()
    {
        hold_count++;
    }

    public void remove_hold ()
    {
        return_if_fail (hold_count > 0);

        hold_count--;
        if (hold_count == 0)
            complete_move ();
    }

    private void complete_move ()
    {
        /* Wait until the hold is removed */
        if (hold_count > 0)
            return;

        if (!is_started)
            return;

        ChessRule rule;
        var result = current_state.get_result (out rule);
        if (result != ChessResult.IN_PROGRESS)
        {
            stop (result, rule);
            return;
        }

        if (current_state.is_dunsany)
        {
             /* Dunsany Win Condition: Black wins if White has no pawns left */
             /* Note: White might promote all pawns? No, capture all 32 pawns. */
             /* Technically if White has NO PIECES, Black wins. */
             if (current_state.piece_masks[Color.WHITE] == 0)
             {
                 stop (ChessResult.BLACK_WON, ChessRule.CHECKMATE); // Or custom rule? Using Checkmate for simplicity as "歼灭" (Annihilation)
                 return;
             }
             /* White wins by Checkmate (handled by standard get_result) */
        }

        if (king_of_the_hill && is_king_on_hill (opponent))
        {
            if (opponent.color == Color.WHITE)
                stop (ChessResult.WHITE_WON, ChessRule.KING_OF_THE_HILL);
            else
                stop (ChessResult.BLACK_WON, ChessRule.KING_OF_THE_HILL);
            return;
        }

        if (is_five_fold_repeat ())
        {
            stop (ChessResult.DRAW, ChessRule.FIVE_FOLD_REPETITION);
            return;
        }

        /* Note this test must occur after the test for checkmate in current_state.get_result (). */
        if (is_seventy_five_move_rule_fulfilled ())
        {
            stop (ChessResult.DRAW, ChessRule.SEVENTY_FIVE_MOVES);
            return;
        }

        if (_clock != null)
            _clock.active_color = current_player.color;
        turn_started (current_player);
    }

    private void undo_cb (ChessPlayer player)
    {
        /* If this players turn undo their opponents move first */
        if (player == current_player)
            undo_cb (opponent);

        /* Don't pop off starting move */
        if (move_stack.next == null)
            return;

        /* Pop off the move state */
        move_stack.remove_link (move_stack);
        _n_moves--;

        /* Restart the game if undo was done after end of the game */
        if (result != ChessResult.IN_PROGRESS)
        {
            result = ChessResult.IN_PROGRESS;
            start ();
        }

        /* Notify */
        undo ();
    }

    private bool resign_cb (ChessPlayer player)
    {
        if (!is_started)
            return false;

        if (player.color == Color.WHITE)
            stop (ChessResult.BLACK_WON, ChessRule.RESIGN);
        else
            stop (ChessResult.WHITE_WON, ChessRule.RESIGN);

        return true;
    }

    private int state_repeated_times (ChessState s1)
    {
        var count = 1;
        var limit = s1.halfmove_clock;
        var checked = 0;

        foreach (var s2 in move_stack)
        {
            if (s1 == s2)
                continue;

            /* Optimization: No need to search beyond the last irreversible move */
            if (checked >= limit)
                break;
            checked++;

            if (s1.equals (s2))
                count++;
        }

        return count;
    }

    public bool is_three_fold_repeat ()
    {
        var repeated = state_repeated_times (current_state);
        return repeated == 3 || repeated == 4;
    }

    public bool is_five_fold_repeat ()
    {
        return state_repeated_times (current_state) >= 5;
    }

    public bool is_fifty_move_rule_fulfilled ()
    {
        /* Fifty moves *per player* without capture or pawn advancement */
        return current_state.halfmove_clock >= 100 && current_state.halfmove_clock < 150;
    }

    public bool is_seventy_five_move_rule_fulfilled ()
    {
        /* 75 moves *per player* without capture or pawn advancement */
        return current_state.halfmove_clock >= 150;
    }

    public bool can_claim_draw ()
    {
        return is_fifty_move_rule_fulfilled () || is_three_fold_repeat ();
    }

    private void claim_draw_cb ()
        requires (can_claim_draw ())
    {
        if (is_fifty_move_rule_fulfilled ())
            stop (ChessResult.DRAW, ChessRule.FIFTY_MOVES);
        else if (is_three_fold_repeat ())
            stop (ChessResult.DRAW, ChessRule.THREE_FOLD_REPETITION);
    }

    public void start ()
    {
        if (result != ChessResult.IN_PROGRESS)
            return;

        if (is_started)
            return;
        is_started = true;

        if (_clock != null)
        {
            _clock.expired.connect (clock_expired_cb);
            _clock.active_color = current_player.color;
        }

        turn_started (current_player);
    }

    private void clock_expired_cb (ChessClock clock)
    {
        if (clock.white_remaining_seconds <= 0)
            stop (ChessResult.BLACK_WON, ChessRule.TIMEOUT);
        else if (clock.black_remaining_seconds <= 0)
            stop (ChessResult.WHITE_WON, ChessRule.TIMEOUT);
        else
            assert_not_reached ();
    }

    public ChessState get_state (int move_number = -1)
    {
        /* Optimization: Most calls are for the current state (move_number = -1) */
        if (move_number == -1)
            return current_state;

        /* If move_number is negative, it's relative to the end.
         * Original: move_number += length().
         * Optimized: move_number += _n_moves + 1. */
        if (move_number < 0)
            move_number += (int) (_n_moves + 1);

        /* Original: nth_data (length() - move_number - 1).
         * Optimized: nth_data ((_n_moves + 1) - move_number - 1) => nth_data (_n_moves - move_number). */
        return move_stack.nth_data ((uint) _n_moves - move_number);
    }

    public ChessPiece? get_piece (int rank, int file, int move_number = -1)
    {
        var state = get_state (move_number);
        return state.board[state.get_index (rank, file)];
    }

    public uint n_moves
    {
        get { return _n_moves; }
    }

    public void pause (bool show_overlay = true)
    {
        if (clock != null && result == ChessResult.IN_PROGRESS && !is_paused)
        {
            clock.pause ();
            is_paused = true;
            should_show_paused_overlay = show_overlay;
            paused ();
        }
    }

    public void unpause ()
    {
        if (clock != null && result == ChessResult.IN_PROGRESS && is_paused)
        {
            clock.unpause ();
            is_paused = false;
            should_show_paused_overlay = false;
            unpaused ();
        }
    }

    public void stop (ChessResult result, ChessRule rule)
    {
        if (!is_started)
            return;
        this.result = result;
        this.rule = rule;
        is_started = false;
        if (_clock != null)
            _clock.stop ();
        ended ();
    }

    public bool is_king_under_attack_at_position (int rank, int file)
    {
        /* Optimization: Use check_state which is pre-calculated */
        if (current_state.check_state == CheckState.NONE)
            return false;

        var piece = get_piece (rank, file);
        if (piece == null || piece.type != PieceType.KING)
            return false;

        if (piece.player.color == Color.WHITE && current_player.color == Color.WHITE)
            return true;

        if (piece.player.color == Color.BLACK && current_player.color == Color.BLACK)
            return true;

        return false;
    }

    public bool is_piece_at_position_threatening_check (int rank, int file)
    {
        int[] threatening_rank, threatening_file;

        if (current_state.get_positions_threatening_king (current_player, out threatening_rank, out threatening_file))
        {
            assert (threatening_rank.length == threatening_file.length);
            for (int i = 0; i < threatening_rank.length; i++)
            {
                if (threatening_rank[i] == rank && threatening_file[i] == file)
                    return true;
            }
        }

        return false;
    }
    public bool is_king_on_hill (ChessPlayer player)
    {
        var hill_indices = new int[] { 27, 28, 35, 36 };
        foreach (var index in hill_indices)
        {
            var piece = current_state.board[index];
            if (piece != null && piece.type == PieceType.KING && piece.player == player)
                return true;
        }
        return false;
    }

    public static string get_chess960_fen ()
    {
        var placement = new string[8];
        for (int i = 0; i < 8; i++) placement[i] = "";

        // Algorithm to place pieces
        // 1. Bishops on opposite colors
        int b1_idx = Random.int_range (0, 4) * 2; // 0, 2, 4, 6
        int b2_idx = Random.int_range (0, 4) * 2 + 1; // 1, 3, 5, 7
        placement[b1_idx] = "B";
        placement[b2_idx] = "B";

        // 2. Queen
        int q_idx = -1;
        while (true)
        {
            q_idx = Random.int_range (0, 8);
            if (placement[q_idx] == "") break;
        }
        placement[q_idx] = "Q";

        // 3. Knights
        for (int k = 0; k < 2; k++)
        {
            int n_idx = -1;
            while (true)
            {
                n_idx = Random.int_range (0, 8);
                if (placement[n_idx] == "") break;
            }
            placement[n_idx] = "N";
        }

        // 4. Rooks and King (R K R pattern on remaining squares)
        var remaining = new int[3];
        int r_count = 0;
        for (int i = 0; i < 8; i++)
        {
            if (placement[i] == "")
            {
               remaining[r_count] = i;
               r_count++;
            }
        }
        
        placement[remaining[0]] = "R";
        placement[remaining[1]] = "K";
        placement[remaining[2]] = "R";

        // Build FEN string
        var row = "";
        for (int i = 0; i < 8; i++) row += placement[i];
        
        var white_row = row;
        var black_row = row.down ();

        // Standard FEN logic for other fields
        // Since we are starting fresh, full castling rights (KQkq) are available.
        // NOTE: In current engine, KQkq implies outer Rooks if standard.
        // But for 960 we rely on the flags being true.
        // Our 'is_960' flag in ChessState will enforce correct checks.
        
        return "%s/pppppppp/8/8/8/8/PPPPPPPP/%s w KQkq - 0 1".printf (black_row, white_row);
    }

    public static string get_dunsany_fen ()
    {
        /* Dunsany's Chess:
         * Black: Standard (rnbqkbnr/pppppppp/...)
         * White: 32 Pawns on ranks 1-4.
         * Black moves first.
         * FEN: rnbqkbnr/pppppppp/......../......../PPPPPPPP/PPPPPPPP/PPPPPPPP/PPPPPPPP b KQkq - 0 1
         * Wait, standard FEN order is Rank 8 down to Rank 1.
         * Rank 8: rnbqkbnr (Black pieces)
         * Rank 7: pppppppp (Black pawns)
         * Rank 6: 8
         * Rank 5: 8
         * Rank 4: PPPPPPPP (White pawns)
         * Rank 3: PPPPPPPP (White pawns)
         * Rank 2: PPPPPPPP (White pawns)
         * Rank 1: PPPPPPPP (White pawns)
         * Active color: b
         */
         return "rnbqkbnr/pppppppp/8/8/PPPPPPPP/PPPPPPPP/PPPPPPPP/PPPPPPPP b KQkq - 0 1";
    }
}
