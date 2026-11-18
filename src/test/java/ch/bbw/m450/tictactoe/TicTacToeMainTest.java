package ch.bbw.m450.tictactoe;

import java.util.stream.Stream;

import org.assertj.core.api.WithAssertions;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.Arguments;
import org.junit.jupiter.params.provider.CsvSource;
import org.junit.jupiter.params.provider.EnumSource;
import org.junit.jupiter.params.provider.MethodSource;
import org.junit.jupiter.params.provider.NullSource;
import org.junit.jupiter.params.provider.ValueSource;
import org.junitpioneer.jupiter.StdIo;
import org.junitpioneer.jupiter.StdOut;

import ch.bbw.m450.tictactoe.TicTacToePlayer.Stone;
import ch.bbw.m450.tictactoe.TicTacToeTestHelpers.ScriptedPlayer;
import ch.bbw.m450.tictactoe.players.GreedyPlayer;

public class TicTacToeMainTest extends TicTacToeTestFixtures implements WithAssertions {

    //region isWin

    //region isWin - winning lines

    static Stream<Arguments> winningLines() {
        return Stream.of(
                Arguments.of("top row", """
                        X X X
                        . O .
                        O . .
                        """),
                Arguments.of("middle row", """
                        O . O
                        X X X
                        . . .
                        """),
                Arguments.of("bottom row", """
                        O . .
                        . O .
                        X X X
                        """),
                Arguments.of("left column", """
                        X O .
                        X O .
                        X . .
                        """),
                Arguments.of("middle column", """
                        O X .
                        . X O
                        . X .
                        """),
                Arguments.of("right column", """
                        . O X
                        . . X
                        O . X
                        """),
                Arguments.of("main diagonal", """
                        X O .
                        O X .
                        . . X
                        """),
                Arguments.of("anti diagonal", """
                        . O X
                        O X .
                        X . .
                        """));
    }

    private static String swapColours(String layout) {
        var swapped = new StringBuilder(layout.length());
        for (var c : layout.toCharArray()) {
            swapped.append(switch (c) {
                case 'X' -> 'O';
                case 'O' -> 'X';
                default -> c;
            });
        }
        return swapped.toString();
    }

    @ParameterizedTest(name = "{0}: only the line owner wins")
    @MethodSource("winningLines")
    void givenAWinningLine_whenIsWin_thenOnlyTheLineOwnerWins(String description, String crossLayout) {
        // GIVEN the line owned by CROSS
        var crossBoard = givenBoard(crossLayout);

        // THEN CROSS wins and CIRCLE does not - isWin must not mix up the colours
        assertThat(TicTacToeMain.isWin(crossBoard, Stone.CROSS))
                .as("the %s must be a win for CROSS", description)
                .isTrue();
        assertThat(TicTacToeMain.isWin(crossBoard, Stone.CIRCLE))
                .as("a CROSS %s must never be reported as a CIRCLE win", description)
                .isFalse();

        // GIVEN the same line with the colours swapped, now owned by CIRCLE
        var circleBoard = givenBoard(swapColours(crossLayout));

        // THEN CIRCLE wins and CROSS does not
        assertThat(TicTacToeMain.isWin(circleBoard, Stone.CIRCLE))
                .as("the %s must be a win for CIRCLE", description)
                .isTrue();
        assertThat(TicTacToeMain.isWin(circleBoard, Stone.CROSS))
                .as("a CIRCLE %s must never be reported as a CROSS win", description)
                .isFalse();
    }

    //endregion

    //region isWin - no winner

    @ParameterizedTest(name = "no winner on: {0}")
    @CsvSource(delimiter = '|', textBlock = """
            empty board       | .........
            two in a row only | XX.OO....
            partial diagonal  | X...X....
            full board draw   | XXOOOXXOX
            """)
    void givenABoardWithoutThreeInALine_whenIsWin_thenNeitherColourWins(String description, String compactLayout) {
        // GIVEN a board that contains no complete line for either colour
        var board = givenBoard(compactLayout);

        // WHEN ask whether either colour has won
        var crossWins = TicTacToeMain.isWin(board, Stone.CROSS);
        var circleWins = TicTacToeMain.isWin(board, Stone.CIRCLE);

        // THEN nobody has won
        assertThat(crossWins || circleWins)
                .as("%s must not be a win for anybody", description)
                .isFalse();
    }

    @ParameterizedTest(name = "an empty board is not a win for {0}")
    @EnumSource(Stone.class)
    void givenAnEmptyBoard_whenIsWin_thenReturnsFalse(Stone color) {
        // GIVEN the empty board provided fresh by the fixture's @BeforeEach

        // WHEN ask whether the given colour has won
        var win = TicTacToeMain.isWin(board, color);

        // THEN an empty board can never be a win
        assertThat(win)
                .as("an empty board must not be a win for %s", color)
                .isFalse();
    }

    //endregion

    //endregion

    //region GreedyPlayer

    @ParameterizedTest(name = "GreedyPlayer plays field {0} when everything below it is taken")
    @ValueSource(ints = {0, 1, 2, 3, 4, 5, 6, 7, 8})
    void givenLowerFieldsTaken_whenGreedyPlayerPlays_thenPicksLowestFreeField(int firstFreeField) {
        // GIVEN the fixture's fresh empty board, with fields below firstFreeField taken by CIRCLE
        for (var i = 0; i < firstFreeField; i++) {
            board[i] = Stone.CIRCLE;
        }

        // WHEN the GreedyPlayer decides on a move
        var move = new GreedyPlayer().play(board, Stone.CROSS);

        // THEN it always takes the lowest still-free field
        assertThat(move)
                .as("GreedyPlayer must play the lowest free field")
                .isEqualTo(firstFreeField);
    }

    //endregion

    //region play - full games

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

    static Stream<Arguments> scriptedGames() {
        return Stream.of(
                // xMoves, oMoves, expected winner (null -> draw)
                Arguments.of(new int[] {0, 1, 2}, new int[] {3, 4}, Stone.CROSS),
                Arguments.of(new int[] {4, 0, 8}, new int[] {1, 2}, Stone.CROSS),
                Arguments.of(new int[] {0, 1, 5, 8}, new int[] {4, 2, 6}, Stone.CIRCLE),
                Arguments.of(new int[] {0, 2, 3, 7, 8}, new int[] {1, 4, 5, 6}, null));
    }

    @ParameterizedTest(name = "scripted game #{index} -> winner {2}")
    @MethodSource("scriptedGames")
    void givenScriptedMoves_whenPlay_thenExpectedPlayerWins(int[] xMoves, int[] oMoves, Stone expectedWinner) {
        // GIVEN two players following a fixed move script
        var xPlayer = new ScriptedPlayer(xMoves);
        var oPlayer = new ScriptedPlayer(oMoves);

        // WHEN they play a full game (X starts)
        var winner = TicTacToeMain.play(xPlayer, oPlayer);

        // THEN the game ends with the expected winner (or a draw)
        assertThat(winner)
                .as("scripted game must end with %s", expectedWinner == null ? "a draw" : expectedWinner)
                .isEqualTo(expectedWinner);
    }

    //endregion

    //region command line - version flag

    @ParameterizedTest(name = "\"{0}\" asks for the version")
    @ValueSource(strings = {"--version", "-v"})
    void givenVersionFlag_whenIsVersionRequest_thenReturnsTrue(String flag) {
        // GIVEN the version flag as the first (and only) argument
        // WHEN the arguments are classified
        // THEN they are recognised as a version request, not as a game start
        assertThat(TicTacToeMain.isVersionRequest(new String[] {flag}))
                .as("%s must print the version instead of starting a game", flag)
                .isTrue();
    }

    @Test
    void givenNoArguments_whenIsVersionRequest_thenReturnsFalse() {
        // GIVEN an empty argument array (the normal `java -jar tictactest.jar` case)
        // WHEN the arguments are classified
        // THEN a game is started, not the version output
        assertThat(TicTacToeMain.isVersionRequest(new String[0])).isFalse();
    }

    @Test
    void givenNullArguments_whenIsVersionRequest_thenReturnsFalse() {
        // GIVEN no argument array at all (defensive: a caller invoking main(null))
        // WHEN the arguments are classified
        // THEN this is not a version request and no NullPointerException escapes
        assertThat(TicTacToeMain.isVersionRequest(null)).isFalse();
    }

    @ParameterizedTest(name = "\"{0}\" is not the version flag")
    @ValueSource(strings = {"--help", "version", "-V", "--versionx", ""})
    void givenOtherArgument_whenIsVersionRequest_thenReturnsFalse(String argument) {
        // GIVEN some other first argument
        // WHEN the arguments are classified
        // THEN only the exact flags count as a version request
        assertThat(TicTacToeMain.isVersionRequest(new String[] {argument})).isFalse();
    }

    @Test
    void givenAManifestVersion_whenVersionInfo_thenReportsThatVersion() {
        // GIVEN a released jar whose manifest carries the version the build took from the git tag
        // WHEN the version string is assembled
        // THEN exactly that version is reported
        assertThat(TicTacToeMain.versionInfo("1.0.0"))
                .as("a released jar must report the version baked in by the build")
                .isEqualTo("TicTacTest 1.0.0");
    }

    @ParameterizedTest(name = "manifest version \"{0}\" -> development build")
    @NullSource
    @ValueSource(strings = {"", "   "})
    void givenNoUsableManifestVersion_whenVersionInfo_thenReportsDevelopmentBuild(String manifestVersion) {
        // GIVEN no (or a blank) Implementation-Version, as when running from plain classes
        // WHEN the version string is assembled
        // THEN it falls back to the development marker instead of printing an empty version
        assertThat(TicTacToeMain.versionInfo(manifestVersion))
                .as("an unversioned build must say so rather than print nothing")
                .isEqualTo("TicTacTest " + TicTacToeMain.DEVELOPMENT_VERSION);
    }

    @Test
    void givenNoManifest_whenVersionInfo_thenReadsTheVersionFromThePackage() {
        // GIVEN the test classpath, where the classes come from build output without a jar manifest
        // WHEN the no-argument version string is assembled
        // THEN it reads the package's Implementation-Version and reports a development build
        assertThat(TicTacToeMain.versionInfo())
                .as("version is read from the jar manifest, which only a released jar has")
                .isEqualTo("TicTacTest " + TicTacToeMain.DEVELOPMENT_VERSION);
    }

    @StdIo
    @Test
    void givenVersionFlag_whenMain_thenPrintsVersionAndDoesNotStartAGame(StdOut out) {
        // GIVEN the released entry point called with --version
        // WHEN main runs
        TicTacToeMain.main(new String[] {"--version"});

        // THEN it prints exactly the version line and no board (no stdin is consumed)
        assertThat(out.capturedLines())
                .as("--version must print one line and return instead of starting a game")
                .containsExactly(TicTacToeMain.versionInfo());
    }

    //endregion

    //region command line - help flag

    @ParameterizedTest(name = "\"{0}\" asks for the usage text")
    @ValueSource(strings = {"--help", "-h"})
    void givenHelpFlag_whenIsHelpRequest_thenReturnsTrue(String flag) {
        // GIVEN the help flag as the first argument
        // WHEN the arguments are classified
        // THEN they are recognised as a help request
        assertThat(TicTacToeMain.isHelpRequest(new String[] {flag}))
                .as("%s must print the usage text instead of starting a game", flag)
                .isTrue();
    }

    @ParameterizedTest(name = "\"{0}\" is not the help flag")
    @NullSource
    @ValueSource(strings = {"--version", "help", "-H", "--helpme", ""})
    void givenOtherArgument_whenIsHelpRequest_thenReturnsFalse(String argument) {
        // GIVEN some other first argument (or none at all)
        // WHEN the arguments are classified
        // THEN only the exact flags count as a help request
        var args = argument == null ? new String[0] : new String[] {argument};
        assertThat(TicTacToeMain.isHelpRequest(args)).isFalse();
    }

    @StdIo
    @Test
    void givenHelpFlag_whenMain_thenPrintsUsageAndDoesNotStartAGame(StdOut out) {
        // GIVEN the released entry point called with --help
        // WHEN main runs
        TicTacToeMain.main(new String[] {"--help"});

        // THEN it explains how to start a game and which options exist, without consuming stdin
        assertThat(out.capturedString())
                .as("--help must document how the application is used")
                .isEqualToIgnoringNewLines(TicTacToeMain.USAGE)
                .contains("java -jar tictactest-<version>.jar")
                .contains("--version");
    }

    //endregion
}
