/**
 * Validates a FEN (Forsyth-Edwards Notation) string.
 *
 * A FEN string contains 6 fields separated by space:
 * 1. Piece placement (from rank 8 to 1)
 * 2. Active color ('w' or 'b')
 * 3. Castling availability ('-', 'K', 'Q', 'k', 'q')
 * 4. En passant target square ('-' or coordinate)
 * 5. Halfmove clock
 * 6. Fullmove number
 *
 * @param {string} fen The FEN string to validate.
 * @returns {object} { valid: boolean, error: string }
 */
function validateFEN(fen) {
    if (!fen) {
        return { valid: false, error: "Empty string" };
    }

    const parts = fen.split(' ');
    if (parts.length !== 6) {
        return { valid: false, error: `Invalid number of fields: expected 6, got ${parts.length}` };
    }

    // 1. Piece placement
    const rows = parts[0].split('/');
    if (rows.length !== 8) {
        return { valid: false, error: `Invalid number of ranks: expected 8, got ${rows.length}` };
    }

    for (let i = 0; i < 8; i++) {
        let files = 0;
        for (let j = 0; j < rows[i].length; j++) {
            const char = rows[i][j];
            if (/[1-8]/.test(char)) {
                files += parseInt(char, 10);
            } else if (/[prnbqkPRNBQK]/.test(char)) {
                files += 1;
            } else {
                return { valid: false, error: `Invalid character in piece placement: ${char}` };
            }
        }
        if (files !== 8) {
            return { valid: false, error: `Invalid number of files in rank ${8 - i}: expected 8, got ${files}` };
        }
    }

    // 2. Active color
    if (!/^[wb]$/.test(parts[1])) {
        return { valid: false, error: `Invalid active color: ${parts[1]}` };
    }

    // 3. Castling availability
    if (!/^(-|[KQkq]{1,4})$/.test(parts[2])) {
        return { valid: false, error: `Invalid castling availability: ${parts[2]}` };
    }
    // Check for duplicates in castling string if not '-'
    if (parts[2] !== '-' && (new Set(parts[2]).size !== parts[2].length)) {
        return { valid: false, error: `Duplicate characters in castling availability` };
    }

    // 4. En passant target square
    if (!/^(-|[a-h][36])$/.test(parts[3])) {
        return { valid: false, error: `Invalid en passant target: ${parts[3]}` };
    }

    // 5. Halfmove clock
    if (!/^\d+$/.test(parts[4])) {
        return { valid: false, error: `Invalid halfmove clock: ${parts[4]}` };
    }

    // 6. Fullmove number
    if (!/^\d+$/.test(parts[5]) || parseInt(parts[5], 10) <= 0) {
        return { valid: false, error: `Invalid fullmove number: ${parts[5]}` };
    }

    return { valid: true, error: null };
}

// Example usage if running in node
if (typeof module !== 'undefined' && !module.parent) {
    const fen = process.argv[2] || "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1";
    console.log(`Validating FEN: "${fen}"`);
    const result = validateFEN(fen);
    if (result.valid) {
        console.log("Valid FEN");
    } else {
        console.error("Invalid FEN:", result.error);
        process.exit(1);
    }
} else if (typeof module !== 'undefined') {
    module.exports = validateFEN;
}
