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

public class ChessView : Gtk.DrawingArea
{
    private int border = 6;
    private int square_size;
    private int selected_square_size;
    private Cairo.ImageSurface? model_surface;
    private Cairo.Surface? selected_model_surface;
    private string loaded_theme_name = "";

    private ChessScene _scene;
    public ChessScene scene
    {
        get { return _scene; }
        construct set
        {
            _scene = value;
            _scene.changed.connect (scene_changed_cb);
            queue_draw ();
        }
    }

    private double border_size
    {
        get { return square_size / 2; }
    }

    public ChessView (ChessScene scene)
    {
        Object (scene: scene);

        var click_controller = new Gtk.GestureClick (); // only reacts to Gdk.BUTTON_PRIMARY
        click_controller.pressed.connect (on_click);
        add_controller (click_controller);

        set_draw_func (draw);

        hexpand = true;
        vexpand = true;
        set_size_request (100, 100);
    }

    public override void resize (int width, int height)
    {
        int short_edge = int.min (width, height);

        square_size = (int) Math.floor ((short_edge - 2 * border) / 9.0);
        var extra = square_size * 0.1;
        if (extra < 3)
            extra = 3;
        selected_square_size = square_size + 2 * (int) (extra + 0.5);
    }

    private void render_piece (Cairo.Context c1, Cairo.Context c2, string name, int offset)
    {
        Rsvg.Handle handle;
        try
        {
            var stream = resources_open_stream (Path.build_path ("/", "/org/gnome/Chess/pieces", scene.theme_name, name + ".svg"), ResourceLookupFlags.NONE);
            handle = new Rsvg.Handle.from_stream_sync (stream, null, Rsvg.HandleFlags.FLAGS_NONE, null);
        }
        catch (Error e)
        {
            warning ("Failed to load piece SVG: %s", e.message);
            return;
        }

        try
        {
            handle.render_document (c1, Rsvg.Rectangle () { height = square_size, width = square_size, x = square_size * offset, y = 0 });
            handle.render_document (c2, Rsvg.Rectangle () { height = selected_square_size, width = selected_square_size, x = selected_square_size * offset, y = 0 });
        }
        catch (Error e)
        {
            warning ("Failed to render piece SVG: %s", e.message);
        }
    }

    private void load_theme (Cairo.Context c)
    {
        /* Skip if already loaded */
        if (scene.theme_name == loaded_theme_name && model_surface != null && square_size == model_surface.get_height ())
            return;

        model_surface = new Cairo.ImageSurface (Cairo.Format.ARGB32, 12 * square_size, square_size);
        selected_model_surface = new Cairo.Surface.similar (c.get_target (), Cairo.Content.COLOR_ALPHA, 12 * selected_square_size, selected_square_size);

        var c1 = new Cairo.Context (model_surface);
        var c2 = new Cairo.Context (selected_model_surface);
        render_piece (c1, c2, "whitePawn", 0);
        render_piece (c1, c2, "whiteRook", 1);
        render_piece (c1, c2, "whiteKnight", 2);
        render_piece (c1, c2, "whiteBishop", 3);
        render_piece (c1, c2, "whiteQueen", 4);
        render_piece (c1, c2, "whiteKing", 5);
        render_piece (c1, c2, "blackPawn", 6);
        render_piece (c1, c2, "blackRook", 7);
        render_piece (c1, c2, "blackKnight", 8);
        render_piece (c1, c2, "blackBishop", 9);
        render_piece (c1, c2, "blackQueen", 10);
        render_piece (c1, c2, "blackKing", 11);

        loaded_theme_name = scene.theme_name;
    }

    public void draw (Gtk.DrawingArea self, Cairo.Context c, int width, int height)
    {
        load_theme (c);

        c.translate (get_width () / 2, get_height () / 2);
        c.rotate (Math.PI * scene.board_angle / 180.0);

        int board_size = (int) Math.ceil (square_size * 4 + border_size);
        c.set_source_rgb (0x2e/255.0, 0x34/255.0, 0x36/255.0);
        c.rectangle (-board_size, -board_size, board_size * 2, board_size * 2);
        c.fill ();

        bool[] attacked_squares = null;
        bool in_check = false;
        int[] threatening_ranks = null;
        int[] threatening_files = null;

        if (!scene.animating && scene.game != null)
        {
            if (scene.show_attacked_squares)
            {
                // Calculate attacked squares by the opponent
                scene.game.current_state.get_attacked_squares (scene.game.opponent, out attacked_squares);
            }

            // Optimization: Pre-calculate check status and threatening pieces once per frame
            // instead of calling is_king_under_attack_at_position and is_piece_at_position_threatening_check
            // 64 times inside the loop.
            if (scene.game.current_state.check_state != CheckState.NONE)
            {
                in_check = true;
                scene.game.current_state.get_positions_threatening_king (scene.game.current_player, out threatening_ranks, out threatening_files);
            }
        }

        for (int file = 0; file < 8; file++)
        {
            for (int rank = 0; rank < 8; rank++)
            {
                int x = (int) ((file - 4) * square_size);
                int y = (int) ((3 - rank) * square_size);

                c.rectangle (x, y, square_size, square_size);
                if (scene.disco_mode)
                {
                    double time = (double) GLib.get_monotonic_time () / 1000000.0;
                    double hue = (time * 50.0) % 360.0;
                    double r, g, b;
                    
                    if ((file + rank) % 2 == 0)
                        hsv_to_rgb (hue, 0.6, 0.8, out r, out g, out b);
                    else
                        hsv_to_rgb ((hue + 180.0) % 360.0, 0.6, 0.8, out r, out g, out b);
                        
                    c.set_source_rgb (r, g, b);
                    
                    // Keep animating
                    queue_draw ();
                }
                else if ((file + rank) % 2 == 0)
                    c.set_source_rgb (0xba/255.0, 0xbd/255.0, 0xb6/255.0);
                else
                    c.set_source_rgb (0xee/255.0, 0xee/255.0, 0xec/255.0);

                bool highlight_red = false;
                if (in_check)
                {
                    // Check if King
                    // Optimization: access board directly to avoid O(moves) get_piece() call in get_piece
                    var state = scene.game.current_state;
                    var piece = state.board[state.get_index (rank, file)];
                    if (piece != null && piece.type == PieceType.KING && piece.player == scene.game.current_player)
                    {
                        highlight_red = true;
                    }
                    else
                    {
                        // Check threatening pieces
                        for (int i = 0; i < threatening_ranks.length; i++)
                        {
                            if (threatening_ranks[i] == rank && threatening_files[i] == file)
                            {
                                highlight_red = true;
                                break;
                            }
                        }
                    }
                }

                if (highlight_red)
                    c.set_source_rgb (0xd4/255.0, 0x97/255.0, 0x95/255.0);
                
                if (attacked_squares != null && attacked_squares[rank * 8 + file])
                {
                    // Tint red for attacked squares
                    c.fill ();
                    c.rectangle (x, y, square_size, square_size);
                    c.set_source_rgba (1.0, 0.0, 0.0, 0.2);
                }

                c.fill ();
            }
        }

        if (scene.show_numbering)
        {
            /* Files are centered individiual glyph width and combined glyph height,
             * ranks are centered on individual glyph widths and heights */

            c.set_source_rgb (0x88/255.0, 0x8a/255.0, 0x85/255.0);
            c.set_font_size (border_size * 0.6);
            c.select_font_face ("sans-serif", Cairo.FontSlant.NORMAL, Cairo.FontWeight.BOLD);

            Cairo.TextExtents extents;
            c.text_extents ("abcdefgh", out extents);
            double y_offset = (square_size / 2 - extents.height) / 2 + extents.height + extents.y_bearing;
            double top = -(square_size * 4 + y_offset);
            double bottom = square_size * 4 + border_size - y_offset;

            double file_offset = -(square_size * 3.5);
            double rank_offset = -(square_size * 3.5);

            string[] files;
            string[] ranks;

            Cairo.Matrix matrix = c.get_matrix ();

            if (scene.board_angle == 180.0)
            {
                files = { "h", "g", "f", "e", "d", "c", "b", "a" };
                ranks = { "1", "2", "3", "4", "5", "6", "7", "8" };

                matrix.scale (-1, -1);
            }
            else
            {
                files = { "a", "b", "c", "d", "e", "f", "g", "h" };
                ranks = { "8", "7", "6", "5", "4", "3", "2", "1" };
            }

            c.save ();
            c.set_matrix (matrix);

            for (int i = 0; i < 8; i++)
            {
                c.text_extents (ranks[i], out extents);

                /* Black file */
                c.save ();
                c.move_to (file_offset - extents.width / 2, top);
                c.show_text (files[i]);
                c.restore ();

                /* White file */
                c.save ();
                c.move_to (file_offset - extents.width / 2, bottom);
                c.show_text (files[i]);
                c.restore ();

                c.text_extents (ranks[i], out extents);
                y_offset = -(extents.y_bearing + extents.height / 2);

                /* Left rank */
                c.save ();
                c.move_to (-((double) square_size * 4 + border_size - (border_size - extents.width) / 2), rank_offset + y_offset);
                c.show_text (ranks[i]);
                c.restore ();

                /* Right rank */
                c.save ();
                c.move_to ((double) square_size * 4 + (border_size - extents.width) / 2, rank_offset + y_offset);
                c.show_text (ranks[i]);
                c.restore ();

                file_offset += square_size;
                rank_offset += square_size;
            }

            c.restore ();
        }

        /* Draw pause overlay */
        if (scene.game.should_show_paused_overlay)
        {
            c.rotate (Math.PI * scene.board_angle / 180.0);
            draw_paused_overlay (c);
            return;
        }

        /* Draw the pieces */
        if (!scene.blindfold_mode)
        {
            foreach (var model in scene.pieces)
            {
                c.save ();
                c.translate ((model.x - 4) * square_size, (3 - model.y) * square_size);
                c.translate (square_size / 2, square_size / 2);
                c.rotate (-Math.PI * scene.board_angle / 180.0);

                draw_piece (c,
                            model.is_selected ? selected_model_surface : model_surface,
                            model.is_selected ? selected_square_size : square_size,
                            model.piece, model.under_threat ? 0.8 : 1.0);

                c.restore ();
            }
        }

        /* Draw shadow piece on squares that can be moved to */
        for (int rank = 0; rank < 8; rank++)
        {
            for (int file = 0; file < 8; file++)
            {
                if (scene.can_move (rank, file))
                {
                    c.save ();
                    c.translate ((file - 4) * square_size, (3 - rank) * square_size);
                    c.translate (square_size / 2, square_size / 2);
                    c.rotate (-Math.PI * scene.board_angle / 180.0);

                    draw_piece (c, model_surface, square_size, scene.get_selected_piece (), 0.1);

                    c.restore ();
                }
            }
        }
    }

    private void hsv_to_rgb (double h, double s, double v, out double r, out double g, out double b)
    {
        if (s == 0)
        {
            r = g = b = v;
            return;
        }

        h /= 60.0;
        int i = (int) Math.floor (h);
        double f = h - i;
        double p = v * (1.0 - s);
        double q = v * (1.0 - s * f);
        double t = v * (1.0 - s * (1.0 - f));

        switch (i)
        {
        case 0: r = v; g = t; b = p; break;
        case 1: r = q; g = v; b = p; break;
        case 2: r = p; g = v; b = t; break;
        case 3: r = p; g = q; b = v; break;
        case 4: r = t; g = p; b = v; break;
        default: r = v; g = p; b = q; break;
        }
    }

    private void draw_piece (Cairo.Context c, Cairo.Surface surface, int size, ChessPiece piece, double alpha)
    {
        c.translate (-size / 2, -size / 2);

        int offset = piece.type;
        if (piece.color == Color.BLACK)
            offset += 6;
        c.set_source_surface (surface, -offset * size, 0);
        c.rectangle (0, 0, size, size);
        c.clip ();
        c.paint_with_alpha (alpha);
    }

    private void on_click (Gtk.GestureClick _click_controller, int n_press, double event_x, double event_y)
    {
        if (scene.game == null || scene.game.should_show_paused_overlay)
            return;

        // If the game is over, disable selection of pieces
        if (scene.game.result != ChessResult.IN_PROGRESS)
            return;

        int file = (int) Math.floor ((event_x - 0.5 * get_width () + square_size * 4) / square_size);
        int rank = 7 - (int) Math.floor ((event_y - 0.5 * get_height () + square_size * 4) / square_size);

        // FIXME: Use proper Cairo rotation matrix
        if (scene.board_angle == 180.0)
        {
            rank = 7 - rank;
            file = 7 - file;
        }

        if (file < 0 || file >= 8 || rank < 0 || rank >= 8)
            return;

        scene.select_square (file, rank);
    }

    private void scene_changed_cb (ChessScene scene)
    {
        queue_draw ();
    }

    protected void draw_paused_overlay (Cairo.Context c)
    {
        c.save ();

        c.set_source_rgba (0, 0, 0, 0.75);
        c.paint ();

        c.select_font_face ("Sans", Cairo.FontSlant.NORMAL, Cairo.FontWeight.BOLD);
        c.set_font_size (get_width () * 0.125);

        var text = _("Paused");
        Cairo.TextExtents extents;
        c.text_extents (text, out extents);
        c.move_to (-extents.width / 2.0, extents.height / 2.0);
        c.set_source_rgb (1, 1, 1);
        c.show_text (text);

        c.restore ();
    }
}
