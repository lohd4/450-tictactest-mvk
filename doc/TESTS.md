# Test Documentation – TicTac-Toe

---

## Test 1 – `givenTopRowFilledWithCross_whenIsWinForCross_thenReturnsTrue`

**Summary:** A top row completely filled with the same colour is
recognised as a win.

| Phase | Description |
| --- | --- |
| **GIVEN** | A board whose top row (fields 0, 1, 2) is completely filled with `X`: `X X X / . O . / O . .` |
| **WHEN** | `TicTacToeMain.isWin(board, Stone.CROSS)` is called |
| **THEN** | The result is `true` – three `X` in a row is a win for `CROSS` |

---

## Test 2 – `givenMainDiagonalFilledWithCircle_whenIsWinForCircle_thenReturnsTrue`

**Summary:** Three of the same colour on the main diagonal
(fields 0, 4, 8) are recognised as a win.

| Phase | Description |
| --- | --- |
| **GIVEN** | A board with `O` on all three fields of the main diagonal: `O X . / X O . / . . O` |
| **WHEN** | `TicTacToeMain.isWin(board, Stone.CIRCLE)` is called |
| **THEN** | The result is `true` – the diagonal counts as a win for `CIRCLE` |

---

## Test 3 – `givenTopRowFilledWithCircle_whenIsWinForCross_thenReturnsFalse`

**Summary:** A completed line of the opponent's colour must not be
reported as one's own win (no colour mix-up).

| Phase | Description |
| --- | --- |
| **GIVEN** | A board where `O` – not `X` – owns a full top row: `O O O / X X . / . . .` |
| **WHEN** | `TicTacToeMain.isWin(board, Stone.CROSS)` is called |
| **THEN** | The result is `false` – the `O` row is not a win for `CROSS` |

---

## Test 4 – `givenSamePlayerInstanceForBothSides_whenPlay_thenThrowsIllegalArgumentException`

**Summary:** Passing the same player instance for both sides makes
`play` refuse to start.

| Phase | Description |
| --- | --- |
| **GIVEN** | A single `GreedyPlayer` instance meant to act as both the X **and** the O player |
| **WHEN** | `TicTacToeMain.play(player, player)` is called with that instance on both sides |
| **THEN** | An `IllegalArgumentException` with the message `"players must differ"` is thrown |

---

## Test 5 – `givenTwoGreedyPlayers_whenPlay_thenCrossWins`

**Summary:** A complete, deterministic game between two
`GreedyPlayer`s ends with a win for X.

| Phase | Description |
| --- | --- |
| **GIVEN** | Two independent `GreedyPlayer`s (each always plays the lowest free field) |
| **WHEN** | `TicTacToeMain.play(xPlayer, oPlayer)` plays a complete game (X starts) |
| **THEN** | The return value is `Stone.CROSS` – X wins via the anti-diagonal fields 2, 4, 6 |

### Game trace (for traceability)

| Round | Move | Board afterwards |
| --- | --- | --- |
| 0 | X → 0 | `X . . / . . . / . . .` |
| 1 | O → 1 | `X O . / . . . / . . .` |
| 2 | X → 2 | `X O X / . . . / . . .` |
| 3 | O → 3 | `X O X / O . . / . . .` |
| 4 | X → 4 | `X O X / O X . / . . .` |
| 5 | O → 5 | `X O X / O X O / . . .` |
| 6 | X → 6 | `X O X / O X O / X . .` → **X wins (2, 4, 6)** |

---

## Overview

| # | Test method | Method under test | Verifies |
| --- | --- | --- | --- |
| 1 | `givenTopRowFilledWithCross_whenIsWinForCross_thenReturnsTrue` | `isWin` | Win via a row |
| 2 | `givenMainDiagonalFilledWithCircle_whenIsWinForCircle_thenReturnsTrue` | `isWin` | Win via a diagonal |
| 3 | `givenTopRowFilledWithCircle_whenIsWinForCross_thenReturnsFalse` | `isWin` | No colour mix-up |
| 4 | `givenSamePlayerInstanceForBothSides_whenPlay_thenThrowsIllegalArgumentException` | `play` | Validation of identical players |
| 5 | `givenTwoGreedyPlayers_whenPlay_thenCrossWins` | `play` | Full game flow + winner determination |
