## 2024-05-23 - Render Loop Optimization in ChessView

**Learning:** In Vala (and likely other GLib-based languages), frequent access to `List.nth_data` (O(N)) inside a rendering loop (O(64)) creates a significant performance penalty (O(64 * Moves)). This pattern appeared in `ChessGame.get_piece` which was called indirectly 64 times per frame.

**Action:** When optimizing rendering loops, look for hidden O(N) lookups in helper methods. Pre-calculating values (like "in check" status and threatening pieces) outside the loop reduced complexity from potentially O(64 * Moves * Complexity) to O(Complexity) + O(64). Always prefer direct array access (`board[index]`) over list traversal when index is known.
