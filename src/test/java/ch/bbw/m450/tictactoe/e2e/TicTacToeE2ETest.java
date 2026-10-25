package ch.bbw.m450.tictactoe.e2e;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.concurrent.CountDownLatch;

import org.assertj.core.api.WithAssertions;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.Timeout;
import org.junitpioneer.jupiter.ReadsStdIo;
import org.junitpioneer.jupiter.StdIo;
import org.junitpioneer.jupiter.StdOut;
import org.junitpioneer.jupiter.WritesStdIo;
import org.opentest4j.AssertionFailedError;

import ch.bbw.m450.tictactoe.TicTacToeMain;
import ch.bbw.m450.tictactoe.TicTacToePlayer;
import ch.bbw.m450.tictactoe.TicTacToePlayer.Stone;
import ch.bbw.m450.tictactoe.TicTacToeTestHelpers;
import ch.bbw.m450.tictactoe.players.GreedyPlayer;
import ch.bbw.m450.tictactoe.players.HumanPlayer;

import static org.junit.jupiter.api.Assertions.assertTimeoutPreemptively;

/**
 * End-to-end tests: the real {@link HumanPlayer} entry point, reading moves via
 * {@code System.in} exactly as the shipped {@code main()} does ({@code HumanPlayer} vs
 * {@code GreedyPlayer}), driven through {@code @StdIo} (JUnit Pioneer) instead of a
 * {@code ScriptedPlayer} test double. Scope, rationale and the full expected/actual-behaviour
 * catalogue are documented in {@code doc/TESTKONZEPT.md} §7.4.
 */
@Tag("e2e")
class TicTacToeE2ETest implements WithAssertions {

    //region full game flow: first input to result (Sieg X, Sieg O, Unentschieden)

    @StdIo({"0", "2", "4", "6"})
    @Test
    void givenMovesViaStdin_whenPlayingFullGame_thenCrossWinsAntiDiagonal(StdOut out) {
        // GIVEN a real HumanPlayer reading X's moves from (simulated) stdin, O played by GreedyPlayer
        // WHEN a full game is played (same anti-diagonal trace as TESTS.md Test 5: 0, 2, 4, 6)
        var winner = TicTacToeMain.play(new HumanPlayer(), new GreedyPlayer());

        // THEN CROSS wins and the result is both returned and printed
        assertThat(winner).as("X completes the anti-diagonal 2-4-6").isEqualTo(Stone.CROSS);
        assertThat(out.capturedString()).as("the winner is announced on stdout").contains("winner is: CROSS");
    }

    @StdIo({"3", "5", "6"})
    @Test
    void givenMovesViaStdin_whenPlayingFullGame_thenCircleWinsTopRow(StdOut out) {
        // GIVEN X (human) deliberately plays away from the top row, letting greedy O fill it
        // WHEN a full game is played
        var winner = TicTacToeMain.play(new HumanPlayer(), new GreedyPlayer());

        // THEN O/CIRCLE wins via the top row (0,1,2), picked up automatically by GreedyPlayer
        assertThat(winner).as("GreedyPlayer completes the top row once X stops contesting it").isEqualTo(Stone.CIRCLE);
        assertThat(out.capturedString()).as("the winner is announced on stdout").contains("winner is: CIRCLE");
    }

    @StdIo({"1", "3", "4", "6", "8"})
    @Test
    void givenMovesViaStdin_whenPlayingFullGame_thenGameEndsInADraw(StdOut out) {
        // GIVEN X's 5 moves, interleaved with greedy O's forced lowest-free-field responses,
        //       fill the board as O X O / X X O / X O X - no line for either colour
        // WHEN a full game is played
        var winner = TicTacToeMain.play(new HumanPlayer(), new GreedyPlayer());

        // THEN the game ends without a winner
        assertThat(winner).as("the full board has no three-in-a-line for either colour").isNull();
        assertThat(out.capturedString()).as("the draw is announced on stdout").contains("it's a draw!");
    }

    //endregion

    //region invalid user input - syntactically not a number -> NumberFormatException

    @StdIo({"abc"})
    @Test
    void givenNonNumericInput_whenHumanPlayerReadsMove_thenThrowsNumberFormatException() {
        var human = new HumanPlayer();

        assertThatThrownBy(() -> human.play(TicTacToeTestHelpers.emptyBoard(), Stone.CROSS))
                .as("plain text is not a valid field number")
                .isInstanceOf(NumberFormatException.class);
    }

    @StdIo({""})
    @Test
    void givenEmptyInput_whenHumanPlayerReadsMove_thenThrowsNumberFormatException() {
        var human = new HumanPlayer();

        assertThatThrownBy(() -> human.play(TicTacToeTestHelpers.emptyBoard(), Stone.CROSS))
                .as("an empty line is not a valid field number")
                .isInstanceOf(NumberFormatException.class);
    }

    @StdIo({" 3 "})
    @Test
    void givenWhitespacePaddedInput_whenHumanPlayerReadsMove_thenThrowsNumberFormatException() {
        var human = new HumanPlayer();

        // Integer.parseInt does not trim - unlike a human reader, leading/trailing spaces are rejected
        assertThatThrownBy(() -> human.play(TicTacToeTestHelpers.emptyBoard(), Stone.CROSS))
                .as("Integer.parseInt does not trim whitespace")
                .isInstanceOf(NumberFormatException.class);
    }

    @StdIo({"3.5"})
    @Test
    void givenDecimalInput_whenHumanPlayerReadsMove_thenThrowsNumberFormatException() {
        var human = new HumanPlayer();

        assertThatThrownBy(() -> human.play(TicTacToeTestHelpers.emptyBoard(), Stone.CROSS))
                .as("field numbers are integers, not decimals")
                .isInstanceOf(NumberFormatException.class);
    }

    @StdIo({"99999999999999999999"})
    @Test
    void givenOverflowingNumericInput_whenHumanPlayerReadsMove_thenThrowsNumberFormatException() {
        var human = new HumanPlayer();

        // 20 digits overflow a 32-bit int; Integer.parseInt detects this and fails fast (no hang, no wraparound)
        assertThatThrownBy(() -> human.play(TicTacToeTestHelpers.emptyBoard(), Stone.CROSS))
                .as("a number outside the int range must not silently wrap around")
                .isInstanceOf(NumberFormatException.class);
    }

    @StdIo({"'; DROP TABLE players; --"})
    @Test
    void givenSqlInjectionStyleInput_whenHumanPlayerReadsMove_thenThrowsNumberFormatException() {
        var human = new HumanPlayer();

        // the move is only ever used as Integer.parseInt input, never interpolated into a query or command,
        // so injection-shaped text is just another invalid number - documented here as a verified non-issue
        assertThatThrownBy(() -> human.play(TicTacToeTestHelpers.emptyBoard(), Stone.CROSS))
                .as("SQL-injection-shaped text is rejected as an invalid field number, nothing is executed")
                .isInstanceOf(NumberFormatException.class);
    }

    @StdIo({"<script>alert(1)</script>"})
    @Test
    void givenHtmlScriptInjectionStyleInput_whenHumanPlayerReadsMove_thenThrowsNumberFormatException() {
        var human = new HumanPlayer();

        assertThatThrownBy(() -> human.play(TicTacToeTestHelpers.emptyBoard(), Stone.CROSS))
                .as("the move is a console int, never rendered as HTML - injection-shaped text is just invalid input")
                .isInstanceOf(NumberFormatException.class);
    }

    // Note: Integer.parseInt() also accepts non-ASCII Unicode decimal digits (e.g. the full-width
    // '8', U+FF18) via Character.digit() - confirmed with a standalone experiment outside this suite.
    // Not automated here: JUnit Pioneer's @StdIo and HumanPlayer's explicit UTF-8 Scanner decode
    // such multi-byte input through different charset paths depending on the platform's native
    // encoding, which made an automated case for this flaky across environments. Documented as a
    // curiosity (not a vulnerability - the result is still a plain in-range int) in doc/TESTKONZEPT.md §7.4.

    //endregion

    //region invalid / malicious user input - syntactically valid, semantically rejected by play()

    @StdIo({"-1"})
    @Test
    void givenNegativeMoveIndex_whenPlay_thenThrowsIllegalStateException() {
        assertThatThrownBy(() -> TicTacToeMain.play(new HumanPlayer(), new GreedyPlayer()))
                .as("a negative field index must be rejected by the game loop")
                .isInstanceOf(IllegalStateException.class)
                .hasMessage("cannot play to position -1");
    }

    @StdIo({"9"})
    @Test
    void givenMoveIndexEqualToBoardSize_whenPlay_thenThrowsIllegalStateException() {
        assertThatThrownBy(() -> TicTacToeMain.play(new HumanPlayer(), new GreedyPlayer()))
                .as("the board only has indices 0-8")
                .isInstanceOf(IllegalStateException.class)
                .hasMessage("cannot play to position 9");
    }

    @StdIo({"0", "0"})
    @Test
    void givenReplayOfAnAlreadyOccupiedCell_whenPlay_thenThrowsIllegalStateException() {
        // GIVEN X plays field 0, greedy O auto-plays field 1, then X maliciously/mistakenly replays field 0
        assertThatThrownBy(() -> TicTacToeMain.play(new HumanPlayer(), new GreedyPlayer()))
                .as("an already-occupied field must be rejected, even if syntactically a valid index")
                .isInstanceOf(IllegalStateException.class)
                .hasMessage("cannot play to position 0");
    }

    //endregion

    //region Denial of Service: behaviour that can hang the process, secured with test timeouts

    /**
     * A player implementation that never returns, simulating a hung/misbehaving {@link TicTacToePlayer}.
     */
    private static final class ForeverBlockingPlayer implements TicTacToePlayer {
        @Override
        public int play(Stone[] board, Stone colorToPlay) {
            try {
                new CountDownLatch(1).await(); // never counts down: blocks until interrupted
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
            }
            return 0; // unreachable within the timeouts used by these tests
        }
    }

    @Test
    @Timeout(10) // safety net: fail the test method itself if the preemptive guard below is ever bypassed
    void givenAForeverBlockingPlayerImplementation_whenPlay_thenEngineEnforcesNoTimeoutAndHangs() {
        // GIVEN a player whose play() never returns (e.g. a stuck remote opponent, an infinite-loop bug)
        var hanging = new ForeverBlockingPlayer();
        var greedy = new GreedyPlayer();

        // WHEN / THEN TicTacToeMain.play() provides no per-move timeout of its own, so it blocks forever;
        // this test documents that finding while the outer assertTimeoutPreemptively keeps THIS test fast
        assertThatThrownBy(() -> assertTimeoutPreemptively(Duration.ofMillis(300), () -> TicTacToeMain.play(hanging, greedy)))
                .as("a misbehaving player hangs the whole game - the engine has no built-in move timeout (documented finding, not fixed; see doc/TESTKONZEPT.md §5.5/§7.4)")
                .isInstanceOf(AssertionFailedError.class);
    }

    /**
     * An input stream that never completes a line and never reaches EOF, simulating a client
     * (interactive or piped) that stops sending data mid-line.
     */
    private static final class NeverCompletesALineInputStream extends InputStream {
        @Override
        public int read() throws IOException {
            try {
                Thread.sleep(30_000); // long but finite, and interruptible - avoids leaking a forever-blocked thread
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                throw new IOException("blocked read interrupted", e);
            }
            return '0';
        }
    }

    @Test
    @Timeout(10)
    @WritesStdIo // never run in parallel with other tests that touch System.in/out
    void givenStdinThatNeverCompletesALine_whenHumanPlayerReadsMove_thenBlocksIndefinitely() {
        // GIVEN stdin that delivers no newline and never closes (e.g. an attacker-controlled pipe)
        var originalIn = System.in;
        System.setIn(new NeverCompletesALineInputStream());
        try {
            var human = new HumanPlayer();
            var board = TicTacToeTestHelpers.emptyBoard();

            // WHEN / THEN Scanner#nextLine() blocks forever waiting for a line terminator that never
            // arrives - a trivial Denial of Service against HumanPlayer if stdin is attacker-controlled.
            // Documented finding, not fixed (see doc/TESTKONZEPT.md §5.5/§7.4); this test stays fast
            // thanks to assertTimeoutPreemptively.
            assertThatThrownBy(() -> assertTimeoutPreemptively(Duration.ofMillis(300), () -> human.play(board, Stone.CROSS)))
                    .as("HumanPlayer enforces no read timeout on stdin")
                    .isInstanceOf(AssertionFailedError.class);
        } finally {
            System.setIn(originalIn);
        }
    }

    @Test
    @Timeout(20) // safety net well above the budget below, to absorb slow/loaded CI runners
    @ReadsStdIo
    void givenAnExtremelyLongSingleLineOfInput_whenHumanPlayerReadsMove_thenFailsFastWithoutHanging() {
        // GIVEN a single, absurdly long line (2 million digits - clearly out of int range) terminated
        //       normally, unlike the two tests above. In isolation this parses in well under 100ms
        //       (measured); the generous budget below only guards against CI/IO noise, not the SUT.
        var hugeLine = "9".repeat(2_000_000) + "\n";
        var originalIn = System.in;
        System.setIn(new ByteArrayInputStream(hugeLine.getBytes(StandardCharsets.UTF_8)));
        try {
            var human = new HumanPlayer();
            var board = TicTacToeTestHelpers.emptyBoard();

            // WHEN / THEN parsing fails fast (NumberFormatException), far below the 30s+ used by the
            // genuinely-hanging DoS tests above - this particular vector is NOT a practical DoS:
            // no quadratic blow-up, no unbounded hang, no OOM.
            assertTimeoutPreemptively(Duration.ofSeconds(15), () ->
                    assertThatThrownBy(() -> human.play(board, Stone.CROSS))
                            .as("an oversized numeric line is still rejected, just like a normal overflow")
                            .isInstanceOf(NumberFormatException.class));
        } finally {
            System.setIn(originalIn);
        }
    }

    //endregion
}
