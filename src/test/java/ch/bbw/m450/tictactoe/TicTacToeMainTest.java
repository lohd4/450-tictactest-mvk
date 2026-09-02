package ch.bbw.m450.tictactoe;

import org.assertj.core.api.WithAssertions;
import org.junit.jupiter.api.Test;

import ch.bbw.m450.tictactoe.TicTacToePlayer.Stone;
import ch.bbw.m450.tictactoe.players.GreedyPlayer;

public class TicTacToeMainTest implements WithAssertions {

    @Test
    void givenTopRowFilledWithCross_whenIsWinForCross_thenReturnsTrue() {
        // GIVEN a board whose top row is completely filled with CROSS
        var board = TicTacToeTestHelpers.board("""
                X X X
                . O .
                O . .
                """);

        // WHEN ask whether CROSS has won
        var crossWins = TicTacToeMain.isWin(board, Stone.CROSS);

        // THEN the row counts as a win for CROSS
        assertThat(crossWins)
                .as("three CROSS in the top row must be a win")
                .isTrue();
    }

    @Test
    void givenMainDiagonalFilledWithCircle_whenIsWinForCircle_thenReturnsTrue() {
        // GIVEN a board with CIRCLE on all three fields of the main diagonal (0, 4, 8)
        var board = TicTacToeTestHelpers.board("""
                O X .
                X O .
                . . O
                """);

        // WHEN ask whether CIRCLE has won
        var circleWins = TicTacToeMain.isWin(board, Stone.CIRCLE);

        // THEN the diagonal counts as a win for CIRCLE
        assertThat(circleWins)
                .as("three CIRCLE on the main diagonal must be a win")
                .isTrue();
    }

    @Test
    void givenTopRowFilledWithCircle_whenIsWinForCross_thenReturnsFalse() {
        // GIVEN a board where CIRCLE (not CROSS) owns a full top row
        var board = TicTacToeTestHelpers.board("""
                O O O
                X X .
                . . .
                """);

        // WHEN ask whether CROSS has won
        var crossWins = TicTacToeMain.isWin(board, Stone.CROSS);

        // THEN CROSS has not won - isWin must not mix up the colours
        assertThat(crossWins)
                .as("a CIRCLE row must never be reported as a CROSS win")
                .isFalse();
    }

    @Test
    void givenSamePlayerInstanceForBothSides_whenPlay_thenThrowsIllegalArgumentException() {
        // GIVEN one single player instance used as both the X and the O player
        var player = new GreedyPlayer();

        // WHEN a game is started with that instance on both sides
        // THEN the game refuses to start and explains why
        assertThatThrownBy(() -> TicTacToeMain.play(player, player))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("players must differ");
    }

    @Test
    void givenTwoGreedyPlayers_whenPlay_thenCrossWins() {
        // GIVEN two independent Players (each always takes the lowest free field)
        var xPlayer = new GreedyPlayer();
        var oPlayer = new GreedyPlayer();

        // WHEN they play a complete game (X starts)
        var winner = TicTacToeMain.play(xPlayer, oPlayer);

        // THEN X / CROSS wins via the anti-diagonal fields 2, 4, 6
        assertThat(winner)
                .as("the starting player must win this deterministic game")
                .isEqualTo(Stone.CROSS);
    }
}
