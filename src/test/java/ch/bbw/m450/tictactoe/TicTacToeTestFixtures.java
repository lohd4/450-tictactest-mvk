package ch.bbw.m450.tictactoe;

import java.util.Arrays;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;

import ch.bbw.m450.tictactoe.TicTacToePlayer.Stone;


public class TicTacToeTestFixtures {

    protected Stone[] board;

    @BeforeEach
    void setUpBoardFixture() {
        board = TicTacToeTestHelpers.emptyBoard();
    }

    @AfterEach
    void tearDownBoardFixture() {
        if (board != null) {
            Arrays.fill(board, null);
            board = null;
        }
    }

    protected Stone[] givenBoard(String layout) {
        board = TicTacToeTestHelpers.board(layout);
        return board;
    }
}
