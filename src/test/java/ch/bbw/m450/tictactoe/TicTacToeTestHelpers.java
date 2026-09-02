package ch.bbw.m450.tictactoe;

import ch.bbw.m450.tictactoe.TicTacToePlayer.Stone;

public final class TicTacToeTestHelpers {

    private TicTacToeTestHelpers() {
    }

    public static Stone[] board(String layout) {
        var compact = layout.replaceAll("\\s", "");
        if (compact.length() < TicTacToeMain.BOARD_SIZE) {
            throw new IllegalArgumentException(
                    "layout needs " + TicTacToeMain.BOARD_SIZE + " fields but got " + compact.length());
        }

        var board = new Stone[TicTacToeMain.BOARD_SIZE];
        for (var i = 0; i < TicTacToeMain.BOARD_SIZE; i++) {
            board[i] = switch (compact.charAt(i)) {
                case 'X', 'x' -> Stone.CROSS;
                case 'O', 'o' -> Stone.CIRCLE;
                default -> null;
            };
        }
        return board;
    }


    public static Stone[] emptyBoard() {
        return new Stone[TicTacToeMain.BOARD_SIZE];
    }

    public static final class ScriptedPlayer implements TicTacToePlayer {

        private final int[] moves;

        private int cursor;

        public ScriptedPlayer(int... moves) {
            this.moves = moves;
        }

        @Override
        public int play(Stone[] board, Stone colorToPlay) {
            if (cursor >= moves.length) {
                throw new IllegalStateException("scripted player ran out of moves");
            }
            return moves[cursor++];
        }
    }
}
