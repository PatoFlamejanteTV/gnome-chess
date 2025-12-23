import sys
import re

def parse_pgn(pgn_text):
    """
    Parses a PGN string and extracts headers and moves.
    """
    headers = {}
    moves = []

    lines = pgn_text.strip().split('\n')

    header_regex = re.compile(r'\[(\w+) "(.+)"\]')

    move_text = ""

    for line in lines:
        line = line.strip()
        if not line:
            continue

        header_match = header_regex.match(line)
        if header_match:
            key, value = header_match.groups()
            headers[key] = value
        else:
            # Handle comments that go to end of line
            line = re.sub(r';.*', '', line)
            if line.strip():
                move_text += " " + line

    # Clean up move text
    # Remove block comments
    move_text = re.sub(r'\{[^}]*\}', '', move_text)

    # Extract moves
    # Simple regex to find move numbers and moves.
    # 1. e4 e5 2. Nf3 ...
    tokens = move_text.split()
    for token in tokens:
        if token.endswith('.'):
            continue
        # Results like "1-0", "1/2-1/2", "*" are end of game markers
        if token in ["1-0", "0-1", "1/2-1/2", "*"]:
            headers["Result"] = token
            continue

        moves.append(token)

    return headers, moves

if __name__ == "__main__":
    if len(sys.argv) > 1:
        with open(sys.argv[1], 'r') as f:
            content = f.read()
            headers, moves = parse_pgn(content)
            print("Headers:")
            for k, v in headers.items():
                print(f"  {k}: {v}")
            print("\nMoves:")
            print(" ".join(moves))
    else:
        print("Usage: python3 pgn_parser.py <pgn_file>")
        print("Running with sample PGN:")
        sample_pgn = """
[Event "F/S Return Match"]
[Site "Belgrade, Serbia JUG"]
[Date "1992.11.04"]
[Round "29"]
[White "Fischer, Robert J."]
[Black "Spassky, Boris V."]
[Result "1/2-1/2"]

1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 4. Ba4 Nf6 5. O-O Be7 6. Re1 b5 7. Bb3 d6 8. c3 O-O 9. h3 Nb8 10. d4 Nbd7
11. c4 c6 12. cxb5 axb5 13. Nc3 Bb7 14. Bg5 b4 15. Nb1 h6 16. Bh4 c5 17. dxe5 Nxe4 18. Bxe7 Qxe7 19. exd6 Qf6
20. Nbd2 Nxd6 21. Nc4 Nxc4 22. Bxc4 Nb6 23. Ne5 Rae8 24. Bxf7+ Rxf7 25. Nxf7 Rxe1+ 26. Qxe1 Kxf7 27. Qe3 Qg5
28. Qxg5 hxg5 29. b3 Ke6 30. a3 Kd6 31. axb4 cxb4 32. Ra5 Nd5 33. f3 Bc8 34. Kf2 Bf5 35. Ra7 g6 36. Ra6+ Kc5
37. Ke1 Nf4 38. g3 Nxh3 39. Kd2 Kb5 40. Rd6 Kc5 41. Ra6 Nf2 42. g4 Bd3 43. Re6 1/2-1/2
"""
        headers, moves = parse_pgn(sample_pgn)
        print("Headers:")
        for k, v in headers.items():
            print(f"  {k}: {v}")
        print("\nMoves:")
        print(" ".join(moves))
