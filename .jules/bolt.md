## 2024-05-23 - Render Loop Optimization in ChessView

**Learning:** In Vala (and likely other GLib-based languages), frequent access to `List.nth_data` (O(N)) inside a rendering loop (O(64)) creates a significant performance penalty (O(64 * Moves)). This pattern appeared in `ChessGame.get_piece` which was called indirectly 64 times per frame.

**Action:** When optimizing rendering loops, look for hidden O(N) lookups in helper methods. Pre-calculating values (like "in check" status and threatening pieces) outside the loop reduced complexity from potentially O(64 * Moves * Complexity) to O(Complexity) + O(64). Always prefer direct array access (`board[index]`) over list traversal when index is known.
## 2025-12-18 - [Optimized Move Validation]
**Learning:** In ,  was converting coordinates to indexes, while its hot-loop callers (like ) were converting indexes to coordinates. This round-trip conversion (multiplication/division) happened thousands of times during validation loops.
**Action:** Created  to handle validation using 0-63 indices directly. Rank/File coordinates are now only calculated lazily if the move passes initial bitboard validation masks, saving significant CPU cycles in hot paths.
## 2025-12-18 - [Optimized Move Validation]
**Learning:** In `ChessState`, `move_with_coords` was converting coordinates to indexes, while its hot-loop callers (like `is_in_checkmate`) were converting indexes to coordinates. This round-trip conversion (multiplication/division) happened thousands of times during validation loops.
**Action:** Created `move_with_index` to handle validation using 0-63 indices directly. Rank/File coordinates are now only calculated lazily if the move passes initial bitboard validation masks, saving significant CPU cycles in hot paths.
