/* -*- Mode: vala; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- */

public void test_debug_print_board ()
{
    try
    {
        var game = new ChessGame ();
        print ("\nTesting print_board:\n");
        ChessDebug.print_board (game.current_state);
    }
    catch (Error e)
    {
        warning ("Failed to create game: %s", e.message);
        assert_not_reached ();
    }
}

public void test_timer ()
{
    var timer = new ChessDebug.Timer ();
    Thread.usleep (10000); // Sleep 10ms
    double elapsed = timer.elapsed ();
    // Allow small margin of error/jitter
    assert (elapsed > 0.0);
    timer.print_elapsed ("Test Timer");
}

public int main (string[] args)
{
    Test.init (ref args);

    Test.add_func ("/ChessDebug/print_board", test_debug_print_board);
    Test.add_func ("/ChessDebug/timer", test_timer);

    return Test.run ();
}
