# Changelog

Alle nennenswerten Änderungen an TicTacTest werden hier festgehalten – pro
Release ein Abschnitt, beschrieben aus Sicht von Benutzern und Entwicklern
(kein Commit-Log). Die Versionierung folgt `MAJOR.MINOR.PATCH`, die Kriterien
für einen Versionssprung stehen in [RELEASE.md](RELEASE.md#versionsnummer-festlegen).

Der Abschnitt zur jeweiligen Version wird beim Release automatisch in die
GitHub-Release-Notes übernommen – er muss **vor** dem Taggen aktualisiert sein.

## Unreleased

_Noch keine Änderungen seit dem letzten Release._

## 1.0.0 - 2026-11-18

Erste offiziell veröffentlichte Version mit definiertem Release-Prozess.

### Added

- Erste spielbare Version von TicTacTest: Mensch (`X`) gegen Computergegner
  `GreedyPlayer` (`O`) auf einem 3×3-Brett, Züge über die Feldnummern 0–8.
- Gewinnerkennung über alle acht Linien (3 Reihen, 3 Spalten, 2 Diagonalen)
  sowie Erkennung eines Unentschiedens bei vollem Brett.
- Ausführbares JAR: Die Anwendung startet mit
  `java -jar tictactest-1.0.0.jar`, ohne dass sie aus dem Quellcode gebaut
  werden muss.
- Kommandozeilen-Option `--version` (Kurzform `-v`) gibt die Version des
  laufenden JARs aus. Die Version stammt aus dem JAR-Manifest und wird beim
  Build aus dem Git-Tag abgeleitet – ein heruntergeladenes Artefakt lässt sich
  damit eindeutig einem Release zuordnen.
- Automatisierter Release-Prozess: Ein Push eines Tags `v*` baut, testet und
  veröffentlicht die Version als GitHub Release inklusive JAR und
  SHA-256-Prüfsumme (siehe [RELEASE.md](RELEASE.md)).
- Automatisierte Testsuite: Unit- und Integrationstests (JUnit 5, AssertJ),
  separate End-to-End-Tests über echtes stdin/stdout inklusive ungültiger und
  bösartiger Eingaben, dokumentiert in [doc/TESTKONZEPT.md](doc/TESTKONZEPT.md)
  und [doc/TESTS.md](doc/TESTS.md).
- Qualitäts-Gates in der CI: JaCoCo-Coverage-Schwellen (Zeilen ≥ 80 %, Branches
  der Gewinnerkennung ≥ 90 %), Mutation Testing mit PIT sowie ein
  Coverage-Verlauf auf GitHub Pages.
- Reproduzierbare Entwicklungsumgebung als versionierter DevContainer, siehe
  [doc/DEVCONTAINER_VERSIONING.md](doc/DEVCONTAINER_VERSIONING.md).

### Fixed

- `HumanPlayer` verwendet einen einzigen, wiederverwendeten `Scanner` auf
  `System.in`. Zuvor konnten bei mehreren gleichzeitig verfügbaren Eingabezeilen
  (z. B. bei umgeleiteter Eingabe) Züge verloren gehen und das Spiel mit einer
  `NoSuchElementException` abbrechen.
