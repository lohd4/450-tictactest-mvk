# Changelog

Alle nennenswerten Änderungen an TicTacTest werden hier festgehalten – pro
Release ein Abschnitt, beschrieben aus Sicht von Benutzern und Entwicklern
(kein Commit-Log). Die Versionierung folgt `MAJOR.MINOR.PATCH`, die Kriterien
für einen Versionssprung stehen in [RELEASE.md](RELEASE.md#versionsnummer-festlegen).

Der Abschnitt zur jeweiligen Version wird beim Release automatisch in die
GitHub-Release-Notes übernommen – er muss **vor** dem Taggen aktualisiert sein.

## Unreleased

### Added

- TicTacTest ist als Web-App spielbar: Das unveränderte Release-Jar läuft in
  einer Web-Konsole (ttyd hinter nginx), eingebettet in eine statische Seite
  unter `frontend/`. Der Release enthält dafür neu das Frontend-Archiv
  `tictactest-frontend-<version>.zip` samt Prüfsumme.
- Die laufende Backend-Version ist unter `/version` per HTTP abfragbar und
  stammt automatisch aus dem Release-Tag.
- Infrastruktur als Code in `infra/` (**Terraform**): EC2-Instanz mit fester
  Elastic IP, Web-Konsole als systemd-Dienst, privater Artefakt-Bucket und ein
  S3-Bucket als öffentliche Static Website fürs Frontend.
- Deployment bei einem Release (`.github/workflows/deploy.yaml`): deployt nur,
  was sich seit dem vorherigen Release-Tag geändert hat, prüft danach die
  laufende Version und kann jede veröffentlichte Version gezielt erneut
  ausrollen. Ein Push auf `main` deployt nichts.
- `ops/sync-github-env.sh` überträgt die Terraform-Outputs in die
  GitHub-Variables und den Spiel-Link im README.
- `ops/local/` startet die komplette Web-App lokal aus Release-Assets.

### Documentation

- [docs/webkonsole.md](docs/webkonsole.md): Werkzeugwahl, Sicherheitsrisiken,
  Versionsabfrage, lokaler Betrieb.
- [docs/deployment.md](docs/deployment.md): Secrets-Konzept, manueller und
  automatischer Deployment-Ablauf, Robustheitsexperimente, Reflexion und
  Promotion-Strategie.

## 1.1.0 - 2026-11-18

### Added

- Kommandozeilen-Option `--help` (Kurzform `-h`) zeigt eine Kurzanleitung:
  Aufrufsyntax, verfügbare Optionen und die Nummerierung der Spielfelder. Wer
  das JAR herunterlädt, muss die Feldnummern 0–8 damit nicht mehr erraten.

### Fixed

- Tippfehler in der Zugaufforderung korrigiert: Die Eingabeaufforderung lautete
  „where to **to** put the next X?" und lautet nun „where to put the next X?".

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
