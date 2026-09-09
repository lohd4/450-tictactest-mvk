# Testkonzept – TicTac-Toe (M450)

> **Status:** Grundlage / lebendes Dokument. Mit _TODO_ markierte Punkte sind
> Platzhalter, die mit der Testsuite mitwachsen.
> **Abgrenzung:** Dieses Dokument beschreibt das *Warum*, *Was* und *Wie* des
> Testens. Die ausführlichen Einzel-Testbeschreibungen (Given/When/Then) stehen
> in [`TESTS.md`](./TESTS.md); dieses Konzept verweist darauf.

**Inhalt**

1. [Einleitung (Projekt, Version, Rollen)](#1-einleitung-projekt-version-rollen)
2. [Testziele](#2-testziele)
3. [Teststrategie und Teststufen](#3-teststrategie-und-teststufen)
4. [Testobjekte und Testabdeckung](#4-testobjekte-und-testabdeckung)
5. [Testrahmen und Erfolgskriterien](#5-testrahmen-und-erfolgskriterien)
6. [Testumgebung und Testinfrastruktur](#6-testumgebung-und-testinfrastruktur)
7. [Testfallbeschreibungen](#7-testfallbeschreibungen)
8. [Testplan und Zuständigkeiten](#8-testplan-und-zustandigkeiten)
9. [Anhang: Glossar](#9-anhang-glossar)

---

## 1. Einleitung (Projekt, Version, Rollen)

### 1.1 Projekt

**TicTac-Toe** ist eine kleine Konsolen-Applikation aus dem Modul **M450
(Applikationen testen)**. Zwei Spieler setzen abwechselnd Steine
(`CROSS` / `CIRCLE`) auf ein 3×3-Brett; wer zuerst drei in einer Linie hat,
gewinnt, sonst endet das Spiel unentschieden.

Die fachliche Logik ist bewusst klein und gut testbar:

- `TicTacToeMain.isWin(board, color)` – reine Funktion: hat `color` drei in
  einer Linie?
- `TicTacToeMain.play(xPlayer, oPlayer)` – Spielschleife: Züge abwechseln,
  Züge validieren, Sieg/Unentschieden erkennen.
- Spieler-Implementierungen: `GreedyPlayer` (spielt immer das kleinste freie
  Feld), `HumanPlayer` (liest von stdin).

**Technischer Rahmen:** Java 21, Gradle (`application`-Plugin), JUnit Jupiter,
AssertJ, GitHub-Actions-CI.

### 1.2 Version / Dokumenthistorie

| Version | Datum | Autor | Änderung |
| --- | --- | --- | --- |
| 0.1 | 2026-09-09 | L. Dätwyler | Erststruktur  |

- **Applikations-Stand:** Git `main` @ `2d3e4bb` (2026-09-08).
- **Dokumentablage:** `doc/TESTKONZEPT.md` im Projekt-Repository.

### 1.3 Rollen

| Rolle | Person | Verantwortung |
| --- | --- | --- |
| Testautor / Entwickler | L. Dätwyler | Testkonzept, Testfälle, Implementierung der Tests |
| Reviewer | _&lt;Name&gt;_ | Review von Code + Tests gegen die Kriterien in §5 |
| Modulverantwortung / Auftraggeber | BBW M450 (Dozent) | Vorgaben, Abnahme des Testkonzepts |
| CI | GitHub Actions (automatisiert) | Build + Test bei jedem Push / PR |

### 1.4 Referenzierte Dokumente

| Dokument | Inhalt |
| --- | --- |
| [`TESTS.md`](./TESTS.md) | Detailbeschreibung einzelner Testfälle inkl. Spielverlauf |
| `src/main/java/ch/bbw/m450/tictactoe/**` | System under Test |
| `src/test/java/ch/bbw/m450/tictactoe/**` | Testcode, Fixtures, Helpers |
| `.github/workflows/CI.yaml` | CI-Pipeline |

---

## 2. Testziele

### 2.1 Qualitätsziele (priorisiert)

| # | Qualitätsziel | Warum hier relevant | Wie getestet |
| --- | --- | --- | --- |
| 1 | **Funktionale Korrektheit** der Siegerkennung | Ein falsches `isWin` zerstört das ganze Spiel | Entscheidungstabelle + parametrisierte Linien-Tests |
| 2 | **Korrekter Spielablauf** (Zugreihenfolge, Endbedingungen, Sieger/Unentschieden) | Kernanwendungsfall | Skriptbasierte / vollständige Partie-Tests |
| 3 | **Robustheit** gegen ungültige Eingaben & fehlerhafte Spieler | `play` sichert sich explizit dagegen ab | Negativtests, Grenzwerttests |
| 4 | **Determinismus / Reproduzierbarkeit** der Tests | Tests dürfen nicht flaky sein | Feste Fixtures, skriptbasierte Spieler, keine Zufallszahlen, kein echtes stdin |
| 5 | **Wartbarkeit des Testcodes** selbst | Die Suite ist ebenfalls ein Liefergegenstand | Namenskonvention, Fixtures, Helpers, Review |

### 2.2 Messbare Testziele

- Jede der 8 Siegeslinien ist für **beide** Farben abgedeckt (Positiv- **und**
  Negativfall).
- Jeder Fehlerpfad in `play` (`players must differ`, ungültiger Zug, Sieg,
  Unentschieden) hat mindestens einen Test.
- Branch-Coverage von `isWin` = 100 %, Line-Coverage `TicTacToeMain` ≥ 90 %
  (sobald JaCoCo eingebunden, siehe §6).
- CI ist bei jedem Push auf `main` grün.
- Jeder Testfall ist auf eine Technik aus §3.4 zurückführbar.

### 2.3 Nicht-Ziele

Performance, Nebenläufigkeit, Sicherheit, GUI/UX, Persistenz – die Applikation
hat diese Aspekte nicht. `HumanPlayer`-stdin-Parsing und die exakte
ANSI-Ausgabe von `toString` werden bewusst **nicht** getestet (Begründung in
§4.4).

---

## 3. Teststrategie und Teststufen

### 3.1 Grundhaltung

- **Automatisiert zuerst:** alle Testfälle sind JUnit-Tests, die lokal und in
  der CI laufen.
- **Techniken-getrieben:** kein Testfall ohne begründende Technik (§3.4).
- **Deterministisch & isoliert:** kein `Random`, keine Uhr, kein echtes
  `System.in`; jeder Test startet über `@BeforeEach` von einem frischen Brett.
- **Lesbar als Doku:** Brett-Layouts in Tests sind menschenlesbar
  (`"X X X / . O . / O . ."`) und dienen zugleich als Spezifikation.
- **Keine Mocking-Library:** die Kollaborateure sind klein und deterministisch;
  handgeschriebene Test-Doubles (`ScriptedPlayer`) sind klarer.

### 3.2 Teststufen

| Stufe | Bedeutung in diesem Projekt | Beispiele |
| --- | --- | --- |
| **Unit** | Eine Methode, keine Kollaborateure, Brett im Speicher | `isWin`-Linien-Tests, `GreedyPlayer.play`, `Stone.opponent` |
| **Integration / Komponente** | `play` orchestriert eine ganze Partie mit echten Spieler-Objekten | `givenTwoGreedyPlayers_whenPlay_thenCrossWins`, skriptbasierte Partien |
| **System** | Gepackte App über `main` end-to-end | _TODO_ – optional: via Gradle `run` mit gepiptem stdin |

### 3.3 Testarten

| Art | Einsatz |
| --- | --- |
| Funktionaler Test | Soll-Verhalten von `isWin` / `play` |
| Grenzwerttest | Zugpositionen `-1 / 0 / 8 / 9`, Brett mit 0 / 8 / 9 Zügen |
| Negativtest / Fehlerfall | gleiche Spieler-Instanz, ungültiger Zug, brett-mutierender Spieler |
| Regressionstest | gesamte Suite läuft bei jedem Push (CI) |
| Explorativer Test | manuell via `./gradlew run` bei grösseren Änderungen (nicht Teil der Abnahme) |

### 3.4 Testdesign-Techniken

#### Äquivalenzklassen (ÄK)

| Eingabe | Klassen |
| --- | --- |
| Brettfeld | `CROSS` · `CIRCLE` · leer (`null`) |
| `isWin`-Argument `color` | `CROSS` · `CIRCLE` · `null` (undefiniert – siehe §5.5) |
| Zug-Rückgabe eines Spielers | gültig & leer · gültig & belegt · negativ · `>= 9` |
| Brett an `play` | in ≤ 9 Zügen gewinnbar · endet unentschieden |

#### Grenzwertanalyse (GWA)

Validierung `playTo < 0 || playTo >= 9` in `play`:

| Wert | Erwartung |
| --- | --- |
| `-1` | `IllegalStateException` |
| `0` | akzeptiert (falls leer) |
| `8` | akzeptiert (falls leer) |
| `9` | `IllegalStateException` |

Füllstand-Grenzwerte: 0 Züge (leer), 8 Züge (ein Feld frei), 9 Züge (voll).

#### Entscheidungstabelle – `isWin`

Bedingung: existiert für `color` eine Linie, in der alle drei Felder `color` sind?

| Regel | Volle Linie von `color` | Volle Linie des Gegners | Keine volle Linie | `isWin(color)` |
| --- | --- | --- | --- | --- |
| R1 | ja | – | – | **true** |
| R2 | nein | ja | – | **false** (keine Farbverwechslung) |
| R3 | nein | nein | ja | **false** |
| R4 | – | – | leeres Brett | **false** |

#### Zustandsübergang – Spielschleife `play`

Zustände: `X am Zug → O am Zug → X am Zug → …`, Austritt nach ≤ 9 Übergängen
in `X gewinnt`, `O gewinnt` oder `Unentschieden`. Erzwungen durch
skriptbasierte Zugfolgen.

#### Parametrisierung / kombinatorisch

`@ParameterizedTest` statt Copy-Paste: `@MethodSource` für strukturierte
Layouts, `@CsvSource` für kompakte Bretter, `@ValueSource` / `@EnumSource`
für Skalar-Sweeps. Alle 8 Linien × 2 Farben werden **generiert**, nicht von
Hand geschrieben.

---

## 4. Testobjekte und Testabdeckung

### 4.1 Testobjekte (System under Test)

| Komponente | Datei | Verantwortung | Priorität |
| --- | --- | --- | --- |
| `TicTacToeMain.isWin` | `TicTacToeMain.java` | Reine Funktion: drei in einer Linie? | **Hoch** |
| `TicTacToeMain.play` | `TicTacToeMain.java` | Spielschleife, Zug-Validierung, Sieg/Unentschieden | **Hoch** |
| `TicTacToeMain.toString` | `TicTacToeMain.java` | Brett als Text (ANSI) rendern | Tief (kosmetisch) |
| `TicTacToePlayer` / `Stone` | `TicTacToePlayer.java` | Vertrag + `opponent()` | Mittel |
| `GreedyPlayer` | `players/GreedyPlayer.java` | Spielt immer das kleinste freie Feld | Mittel |
| `HumanPlayer` | `players/HumanPlayer.java` | Liest einen Zug von stdin | Tief (I/O, dünn) |

### 4.2 Brettmodell (gemeinsames Vokabular)

Das Brett ist ein `Stone[9]`, zeilenweise. `null` = leer.

```
 0 | 1 | 2
---+---+---
 3 | 4 | 5
---+---+---
 6 | 7 | 8
```

Die 8 Siegeslinien: Zeilen `{0,1,2} {3,4,5} {6,7,8}`, Spalten
`{0,3,6} {1,4,7} {2,5,8}`, Diagonalen `{0,4,8} {2,4,6}`.

### 4.3 Testabdeckung

#### Rückverfolgbarkeitsmatrix (Feature → Technik → Testfall)

| Feature | Technik | Testfall-IDs (§7) | Status |
| --- | --- | --- | --- |
| Sieg über eine Linie | Entscheidungstabelle R1, kombinatorisch | W-01 | ✅ |
| Keine Farbverwechslung | Entscheidungstabelle R2 | W-02 | ✅ |
| Kein Sieg ohne Linie | Entscheidungstabelle R3, ÄK | W-03, W-04, W-05 | ✅ |
| `isWin` mit `null` / falscher Brettgrösse | Fehlerfall, Grenzwert | W-06, W-07 | 🔲 |
| Doppelte Siegeslinie | kombinatorisch | W-08 | 🔲 |
| Gleiche Spieler-Instanz abgewiesen | Negativtest | P-01 | ✅ |
| Vollständige deterministische Partie | Integration | P-02, P-03 | ✅ |
| X beginnt / Zugwechsel | Zustandsübergang | P-04 | 🔲 |
| Ungültiger Zug (belegt / ausserhalb) | Negativtest, GWA | P-05, P-06 | 🔲 |
| Seiteneffekt-Schutz (Brettkopie) | Isolation | P-07 | 🔲 |
| Unentschieden → `null` | GWA | P-08 | ✅ |
| Frühzeitiger Spielabbruch bei Sieg | Zustandsübergang | P-09 | 🔲 |
| GreedyPlayer wählt kleinstes freies Feld | ÄK, Sweep | G-01 | ✅ |
| GreedyPlayer auf vollem Brett | Negativtest | G-02 | 🔲 |
| `Stone.opponent()` symmetrisch | ÄK | S-01 | 🔲 |

#### Abdeckungsziele und -metriken

| Metrik | Ziel | Werkzeug |
| --- | --- | --- |
| Line-Coverage `TicTacToeMain` | ≥ 90 % | _TODO_ – JaCoCo in `build.gradle` |
| Branch-Coverage `isWin` | 100 % (8 Linien, beide Farben) | bereits erfüllt via Parametrisierung |
| Branch-Coverage `play`-Guards | 100 % | teilweise – siehe Lücken in §7 |
| Mutation Score (optional) | ≥ 80 % | _TODO_ – PIT |
| CI | grün bei jedem Push / PR auf `main`, `develop` | GitHub Actions |

> Coverage ist **Wegweiser, kein Ziel**: 100 % Line-Coverage mit schwachen
> Assertions ist schlechter als 85 % mit starken.

### 4.4 Abgrenzung (in / ausserhalb Scope)

**In Scope:** alle öffentlichen Methoden von `TicTacToeMain`, die
`GreedyPlayer`-Strategie, `Stone.opponent()`, End-to-End-Partien über
deterministische Spieler, Eingabevalidierung / Fehlerpfade von `play`.

| Nicht getestet | Grund | Abhilfe |
| --- | --- | --- |
| `HumanPlayer` stdin-Parsing | Erfordert Steuerung von `System.in`; Logik ist ein `parseInt`-Einzeiler | Mit injiziertem `Scanner`/Reader nachrüstbar (§5.5) |
| exakte ANSI-Ausgabe von `toString` | kosmetisch, brüchig gegenüber Escape-Codes | optionaler Smoke-Test: enthält erwartete Ziffern/Buchstaben |
| Konsolenausgabe von `play` (`System.out`) | Seitenkanal, kein Ergebnis | stattdessen Rückgabewert prüfen |
| Performance / Last | fixe 9-Feld-Partie, irrelevant | — |

---

## 5. Testrahmen und Erfolgskriterien

### 5.1 Eintrittskriterien (Testbeginn sinnvoll)

- Code kompiliert (`./gradlew build -x test`).
- Neues Verhalten hat – wo praktikabel – zuerst einen fehlschlagenden Test (TDD).

### 5.2 Austritts- / Erfolgskriterien (Definition of Done einer Änderung)

- Alle Tests lokal **und** in der CI grün.
- Neues/geändertes Verhalten durch einen Test abgedeckt, der auf eine Technik
  in §3.4 zurückführbar ist.
- [`TESTS.md`](./TESTS.md) für nicht-triviale Fälle aktualisiert;
  Testfall-Katalog (§7) im Status nachgeführt.
- Keine Verschlechterung der Coverage (sobald JaCoCo eingebunden).

### 5.3 Pass-/Fail-Kriterien

- **Einzeltest:** grün = erfüllt; rot = Fehler in SUT oder Test, muss vor Merge
  behoben sein.
- **Gesamt:** ein Release/Merge ist zulässig, wenn 100 % der Tests grün sind und
  §5.2 erfüllt ist. Kein „bekannt roter“ Test wird toleriert (stattdessen
  `@Disabled` mit Begründung + Ticket).

### 5.4 Abbruch- / Wiederaufnahmekriterien

- **Abbruch:** Build kompiliert nicht, oder > 25 % der Tests rot → keine
  weiteren Tests, zuerst Ursache beheben.
- **Wiederaufnahme:** Build grün und Basissuite (`isWin`, `play`-Happy-Path)
  wieder grün.

### 5.5 Risiken und offene Punkte

| Risiko / Frage | Auswirkung | Massnahme |
| --- | --- | --- |
| `isWin(board, null)`: eine komplett leere Zeile macht `b[0] == color && b[0] == b[1] …` **true** | latenter Bug: `null`-Farbe „gewinnt“ auf leerem Brett | Test, der das aktuelle Verhalten dokumentiert; entscheiden, ob `isWin` gegen `null` absichern soll (heute kann `play` nie `null` übergeben) |
| `isWin` setzt `board.length == 9` voraus | `ArrayIndexOutOfBounds` bei kürzerem Array | Grenzwerttest mit falscher Array-Grösse; Vorbedingung dokumentieren |
| `HumanPlayer` ungetestet | schlechtes stdin → `NumberFormatException`; Bereichsprüfung nur in `play` | Refactoring auf injizierbare Eingabequelle, dann Parsing-Unit-Test |
| `play` schreibt auf `System.out` | schwer prüfbar, lautes Testlog | so belassen (Rückgabewert prüfen); optional stdout für Smoke-Test einfangen |
| Unentschieden nur implizit getestet | Regression könnte Phantom-Sieger liefern | expliziter skriptbasierter Unentschieden-Test (vorhanden: Partie #4) – behalten und ausbauen |

### 5.6 Liefergegenstände

- Dieses Testkonzept (`doc/TESTKONZEPT.md`).
- Testfallbeschreibungen (`doc/TESTS.md`).
- Automatisierte Testsuite (`src/test/**`).
- CI-Konfiguration + grüner CI-Lauf.
- Testberichte der CI (JUnit-XML / HTML, siehe §6.4).

---

## 6. Testumgebung und Testinfrastruktur

### 6.1 Umgebung

| Element | Wert |
| --- | --- |
| Sprache / JDK | Java 21 (CI: Temurin 21; lokal ≥ 21) |
| Build | Gradle Wrapper (`./gradlew`), Plugins `java`, `application` |
| Testframework | JUnit Jupiter 6.1.3 (`useJUnitPlatform()`) |
| Assertions | AssertJ 3.27.7 (`WithAssertions`) |
| Betriebssystem | OS-unabhängig; CI: `ubuntu-latest`, Entwicklung: Windows/macOS/Linux |
| Ausführung lokal | `./gradlew test` |

### 6.2 CI-Pipeline (`.github/workflows/CI.yaml`)

- Trigger: jeder `push` sowie `pull_request` auf `main` / `develop`.
- Schritte: `checkout` → `setup-java` (Temurin 21) → `./gradlew build -x test`
  → `./gradlew test`.
- Fehlschlag bricht den Lauf ab und blockiert den Merge.

### 6.3 Testinfrastruktur (Testcode)

| Mechanismus | Datei | Zweck |
| --- | --- | --- |
| `board(String layout)` | `TicTacToeTestHelpers` | Brett aus `"X X X / . O . / O . ."` oder `"XX.OO...."` bauen |
| `emptyBoard()` | `TicTacToeTestHelpers` | frisches `Stone[9]` aus `null` |
| `ScriptedPlayer(int... moves)` | `TicTacToeTestHelpers` | deterministischer Spieler nach fixer Zugliste |
| `@BeforeEach` leeres Brett | `TicTacToeTestFixtures` | jeder Test startet sauber und isoliert |
| `@AfterEach` Aufräumen | `TicTacToeTestFixtures` | kein geteilter veränderlicher Zustand leckt |
| `givenBoard(layout)` | `TicTacToeTestFixtures` | Fixture-Hook zum Setzen des Bretts im Test |

**Konventionen des Testcodes**

- Methodenname: `given<Kontext>_when<Aktion>_then<ErwartetesErgebnis>`.
- Rumpf: `// GIVEN … // WHEN … // THEN …` (AAA / Given-When-Then).
- Gruppierung: `//region <Feature>` pro getesteter Methode.
- **Ein Verhalten pro Test.** Ein parametrisierter Test deckt ein Verhalten über
  viele Eingaben ab, nicht viele Verhalten.
- Assertions tragen eine `.as(...)`-Beschreibung des erwarteten Verhaltens.

### 6.4 Testberichte

| Bericht | Ort |
| --- | --- |
| HTML | `build/reports/tests/test/index.html` |
| JUnit-XML | `build/test-results/test/*.xml` |
| Coverage (nach JaCoCo-Einbindung) | `build/reports/jacoco/test/html/index.html` |

---

## 7. Testfallbeschreibungen

Legende: ✅ implementiert · 🔲 geplant / Lücke.
Ausführliche Given/When/Then-Beschreibungen ausgewählter Fälle: [`TESTS.md`](./TESTS.md).

### 7.1 `isWin`

| ID | Verhalten | Technik | Status | Testmethode |
| --- | --- | --- | --- | --- |
| W-01 | Jede der 8 Linien ist ein Sieg für ihren Eigentümer | Entscheidungstabelle R1, kombinatorisch | ✅ | `givenAWinningLine_whenIsWin_thenOnlyTheLineOwnerWins` |
| W-02 | Eine Linie der Farbe A ist nie ein Sieg für Farbe B | Entscheidungstabelle R2 | ✅ | dieselbe |
| W-03 | Kein Drei-in-einer-Linie → niemand gewinnt | Entscheidungstabelle R3, ÄK | ✅ | `givenABoardWithoutThreeInALine_whenIsWin_thenNeitherColourWins` |
| W-04 | Leeres Brett → `false` für beide Farben | Entscheidungstabelle R4, GWA (0 Züge) | ✅ | `givenAnEmptyBoard_whenIsWin_thenReturnsFalse` |
| W-05 | Volles Brett ohne Linie → `false` | GWA (9 Züge) | ✅ | via W-03, Zeile `full board draw` |
| W-06 | `isWin(board, null)` – Verhalten definiert & dokumentiert | Fehlerfall / ÄK | 🔲 | _TODO_ |
| W-07 | Falsch dimensioniertes Brett-Array → dokumentiertes Verhalten | Grenzwert | 🔲 | _TODO_ |
| W-08 | Zwei gleichzeitige Siegeslinien derselben Farbe → weiterhin `true` | kombinatorisch | 🔲 | _TODO_ |

### 7.2 `play`

| ID | Verhalten | Technik | Status | Testmethode |
| --- | --- | --- | --- | --- |
| P-01 | Gleiche Instanz auf beiden Seiten → `IllegalArgumentException` | Negativtest | ✅ | `givenSamePlayerInstanceForBothSides_whenPlay_thenThrowsIllegalArgumentException` |
| P-02 | Zwei GreedyPlayer → CROSS gewinnt (deterministisch) | Integration | ✅ | `givenTwoGreedyPlayers_whenPlay_thenCrossWins` |
| P-03 | Skriptbasierte Zugfolgen → erwarteter Sieger / Unentschieden | Zustandsübergang | ✅ | `givenScriptedMoves_whenPlay_thenExpectedPlayerWins` |
| P-04 | X zieht immer zuerst | Zustandsübergang | 🔲 | _TODO_ |
| P-05 | Zug auf belegtes Feld → `IllegalStateException` | Negativtest | 🔲 | _TODO_ (ScriptedPlayer wiederholt belegtes Feld) |
| P-06 | Zug ausserhalb (`-1`, `9`) → `IllegalStateException` | GWA | 🔲 | _TODO_ |
| P-07 | Spieler, der seine Brettkopie mutiert, beeinflusst das Spiel nicht | Negativtest / Isolation | 🔲 | _TODO_ |
| P-08 | Volles Brett ohne Sieger → Rückgabe `null` (Unentschieden) | GWA | ✅ | skriptbasierte Partie #4 in `scriptedGames()` |
| P-09 | Sieger wird zurückgegeben, sobald die Linie voll ist (Spiel stoppt früh) | Zustandsübergang | 🔲 | _TODO_ |

### 7.3 Spieler / Modell

| ID | Verhalten | Technik | Status | Testmethode |
| --- | --- | --- | --- | --- |
| G-01 | GreedyPlayer wählt das kleinste freie Feld | ÄK, Sweep | ✅ | `givenLowerFieldsTaken_whenGreedyPlayerPlays_thenPicksLowestFreeField` |
| G-02 | GreedyPlayer auf vollem Brett → `IllegalStateException` | Negativtest | 🔲 | _TODO_ |
| S-01 | `Stone.opponent()` ist symmetrisch (`CROSS ↔ CIRCLE`) | ÄK | 🔲 | _TODO_ (`@EnumSource`) |

### 7.4 Vorlage für neue Testfälle (🔲 schliessen)

```
## <ID> – <given…_when…_then…>

| Phase | Beschreibung |
| --- | --- |
| GIVEN | <Ausgangszustand / Fixture / Brett-Layout> |
| WHEN  | <aufgerufene Methode mit Argumenten> |
| THEN  | <erwartetes Ergebnis / erwartete Exception + Message> |

Technik: <ÄK | GWA | Entscheidungstabelle | Zustandsübergang | Negativtest>
Deckt ab: <Feature aus der Matrix §4.3>
```

Beispiel für **P-06** (auszuformulieren und zu implementieren):

| Phase | Beschreibung |
| --- | --- |
| GIVEN | `ScriptedPlayer` für X mit erstem Zug `9`, beliebiger O-Spieler |
| WHEN | `TicTacToeMain.play(xPlayer, oPlayer)` |
| THEN | `IllegalStateException` mit Text `"cannot play to position 9"` |

---

## 8. Testplan und Zuständigkeiten

### 8.1 Vorgehen / Iterationen

| Iteration | Inhalt | Ergebnis |
| --- | --- | --- |
| 1 (erledigt) | Basissuite: `isWin`-Linien, Farbverwechslung, Happy-Path `play` | ✅ Tests 1–5 in `TESTS.md` |
| 2 (erledigt) | Parametrisierung, Fixtures + Helpers, skriptbasierte Partien | ✅ aktueller Stand `main` |
| 3 (offen) | Robustheit `play`: P-05, P-06, P-07, P-09 | 🔲 |
| 4 (offen) | `isWin`-Randfälle W-06 – W-08, Modell S-01, G-02 | 🔲 |
| 5 (offen) | JaCoCo in CI, optional PIT-Mutationstest | 🔲 |

### 8.2 Zuständigkeiten (RACI)

| Aufgabe | Testautor | Reviewer | Dozent | CI |
| --- | --- | --- | --- | --- |
| Testkonzept pflegen | R/A | C | I | – |
| Testfälle entwerfen & implementieren | R/A | C | I | – |
| Review Code + Tests | C | R/A | I | – |
| Regression bei jedem Push ausführen | I | I | – | R/A |
| Abnahme des Testkonzepts | I | C | R/A | – |

_R = Responsible, A = Accountable, C = Consulted, I = Informed._

### 8.3 Berichterstattung

- **Automatisch:** CI-Status pro Push/PR (grün/rot) + Testbericht als Artefakt.
- **Manuell:** bei Abgabe – kurze Zusammenfassung (Anzahl Tests, Coverage,
  offene 🔲-Fälle mit Begründung) am Ende dieses Dokuments oder im PR-Text.

### 8.4 Backlog / nächste Schritte

1. **JaCoCo** einbinden und Coverage in der CI ausweisen.
2. 🔲-Lücken in §7 schliessen, Start mit P-05 / P-06 / P-07 (Robustheit `play`).
3. Semantik von `isWin(_, null)` festlegen und dokumentieren (W-06).
4. `HumanPlayer` auf testbare Eingabe umbauen, Parsing-Tests ergänzen.
5. Optional: **PIT-Mutationstest** zur Prüfung der Assertion-Stärke.

---

## 9. Anhang: Glossar

| Begriff | Bedeutung |
| --- | --- |
| SUT | System under Test – hier `TicTacToeMain` und die Spieler |
| ÄK | Äquivalenzklassen(-bildung) |
| GWA | Grenzwertanalyse |
| AAA | Arrange–Act–Assert (auch Given–When–Then) |
| Fixture | fester Ausgangszustand, der vor jedem Test aufgebaut wird |
| Test-Double | Ersatz für einen echten Kollaborateur (`ScriptedPlayer`) |
| Linie | eine der 8 Dreier-Reihen/-Spalten/-Diagonalen, die das Spiel gewinnen |
| Flaky Test | Test, der ohne Codeänderung mal grün, mal rot ist |
| Regressionstest | Test, der sicherstellt, dass bestehendes Verhalten erhalten bleibt |
