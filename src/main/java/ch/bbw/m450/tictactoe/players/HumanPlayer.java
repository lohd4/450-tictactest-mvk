package ch.bbw.m450.tictactoe.players;

import java.nio.charset.StandardCharsets;
import java.util.Scanner;

import ch.bbw.m450.tictactoe.TicTacToeMain;
import ch.bbw.m450.tictactoe.TicTacToePlayer;

/**
 * Simple human-player taking input from stdin.
 */
public class HumanPlayer implements TicTacToePlayer {

	// One Scanner per player, reused across every move: creating a fresh Scanner(System.in) on
	// each call is unsafe, because a Scanner may read (and internally buffer) more of the
	// underlying stream than the single line it returns. A second, newly constructed Scanner
	// resumes reading the raw stream *after* that already-buffered data, silently losing it -
	// observable as soon as more than one line is available at once (e.g. piped/redirected
	// input), surfacing as java.util.NoSuchElementException on the next move.
	private final Scanner scanner = new Scanner(System.in, StandardCharsets.UTF_8);

	@Override
	public int play(Stone[] board, Stone colorToPlay) {
		System.out.println(TicTacToeMain.toString(board) + "where to to put the next " + colorToPlay + "? (0-8): ");
		return Integer.parseInt(scanner.nextLine());
	}
}
