# Cool Snippets

This directory contains useful non-Vala code snippets for working with Chess data and engines.

## pgn_parser.py (Python)

A simple PGN (Portable Game Notation) parser.
Usage:
```bash
python3 pgn_parser.py <path_to_pgn_file>
```
If no file is provided, it runs with a sample game.

## fen_validator.js (JavaScript)

A JavaScript function to validate FEN (Forsyth–Edwards Notation) strings.
Usage:
```bash
node fen_validator.js "<fen_string>"
```

## engine_connector.c (C)

A C program demonstrating how to fork and exec a process to communicate with a chess engine via pipes.
Compile with:
```bash
gcc engine_connector.c -o engine_connector
```
Usage:
```bash
./engine_connector <path_to_engine>
```
