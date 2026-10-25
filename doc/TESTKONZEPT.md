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

## Audit: 
  - Author: Kajinth
  - Diskrepanz zwischen Priorisierung und Umsetzungsstand
    Ausgerechnet das am höchsten priorisierte Robustheits-Ziel ist am wenigsten getestet. Daneben sind mehrere Ziel-Formulierungen deskriptiv statt normativ gehalten, was den Eindruck erweckt, bereits Erreichtes zu beschreiben, wo tatsächlich noch offene Punkte bestehen.
  - Häufigkeit wann und von wem getestet wird.

- Durchgängige Rückverfolgbarkeit von Qualitätszielen über Techniken bis zu
  einzelnen Testfall-IDs, inklusive expliziter Matrix.
- Begründete Nicht-Ziele und Abgrenzung statt stillschweigender
  Lücken.
- Bekannte Applikationsschwächen (z. B. `isWin(_, null)`) werden selbst
  dokumentiert statt verschwiegen – für ein Testkonzept ungewöhnlich
  und positiv zu werten.
- Konkrete, prüfbare Grenzwerte und eine Entscheidungstabelle statt vager
  Formulierungen.
- CI ist fest im Prozess verankert, kein „nur lokal getestet“-Risiko.

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
| 0.2 | 2026-10-25 | L. Dätwyler | End-to-End-Teststufe ergänzt (JUnit Pioneer `@StdIo`, eigener Gradle-Task `e2eTest`, CI-Integration); Fehler gefunden und test-first behoben (§5.5, §7.4) |

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
| **System / E2E** | Reale Einstiegspunkte (`HumanPlayer` liest echtes `System.in`/`System.out`) statt `ScriptedPlayer`-Testdoppel | `TicTacToeE2ETest` (`@Tag("e2e")`), Details in §7.4 |

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
| Ungültiger Zug (belegt / ausserhalb) | Negativtest, GWA | P-05, P-06 | ✅ |
| Seiteneffekt-Schutz (Brettkopie) | Isolation | P-07 | 🔲 |
| Unentschieden → `null` | GWA | P-08 | ✅ |
| Frühzeitiger Spielabbruch bei Sieg | Zustandsübergang | P-09 | 🔲 |
| GreedyPlayer wählt kleinstes freies Feld | ÄK, Sweep | G-01 | ✅ |
| GreedyPlayer auf vollem Brett | Negativtest | G-02 | 🔲 |
| `Stone.opponent()` symmetrisch | ÄK | S-01 | 🔲 |
| Voller Spielablauf über echtes stdin/stdout (Sieg X/O, Unentschieden) | Integration/E2E, Zustandsübergang | E2E-01 – E2E-03 | ✅ |
| Ungültiger/böswilliger User-Input (stdin) | Negativtest, ÄK | E2E-05 – E2E-14 | ✅ |
| DoS-anfälliges Verhalten, mit Timeout abgesichert | Negativtest, Grenzwert | E2E-15 – E2E-17 | ✅ (2 Befunde dokumentiert, nicht behoben – siehe §5.5) |

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
deterministische Spieler, Eingabevalidierung / Fehlerpfade von `play`. Seit
§7.4 zusätzlich: `HumanPlayer`s stdin-Parsing über echtes `System.in`
(`TicTacToeE2ETest`, `@Tag("e2e")`), inkl. ungültigem/böswilligem Input und
DoS-anfälligem Verhalten.

| Nicht getestet | Grund | Abhilfe |
| --- | --- | --- |
| exakte ANSI-Ausgabe von `toString` | kosmetisch, brüchig gegenüber Escape-Codes | optionaler Smoke-Test: enthält erwartete Ziffern/Buchstaben |
| Performance / Last der Spiellogik selbst | fixe 9-Feld-Partie, irrelevant | — |
| Timeout-Durchsetzung bei hängenden Spielern/stdin | bewusst nicht implementiert (freiwilliger Zusatzauftrag, §8.4) | E2E-15/E2E-16 dokumentieren den Ist-Zustand, siehe §5.5 |

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

| Risiko / Frage | Auswirkung | Massnahme | Status |
| --- | --- | --- | --- |
| **F-01** `HumanPlayer` erzeugte pro `play()`-Aufruf einen neuen `Scanner(System.in)` | gepufferte, ungelesene Folgezeilen gehen verloren → `NoSuchElementException` ab dem zweiten Zug bei nicht-interaktivem/gepiptem stdin (siehe §7.4 für Details) | **behoben, test-first:** ein wiederverwendeter `Scanner` pro `HumanPlayer`-Instanz | ✅ behoben (E2E-01–03, E2E-14 belegen es) |
| **F-02** `TicTacToeMain.play()` erzwingt kein Zug-Timeout | ein hängender/bösartiger `TicTacToePlayer` friert die ganze Partie für immer ein | dokumentiert über E2E-15; echte Mitigation (z. B. Zug-Timeout im Engine-Loop) ist der freiwillige Zusatzauftrag "maximale Antwortzeit" (§8.4) | ⚠️ offen, bewusst nicht Teil dieses Fixes |
| **F-03** `HumanPlayer` erzwingt kein Lese-Timeout auf `System.in` | `Scanner#nextLine()` blockiert für immer, wenn nie ein Zeilenumbruch ankommt (z. B. kaputte/böswillige Pipe) → trivialer DoS | dokumentiert über E2E-16; Mitigation wäre ein Lese-Timeout (z. B. über einen separaten Reader-Thread) – ausserhalb des mandatorischen Scopes, siehe §8.4 | ⚠️ offen, bewusst nicht Teil dieses Fixes |
| `isWin(board, null)`: eine komplett leere Zeile macht `b[0] == color && b[0] == b[1] …` **true** | latenter Bug: `null`-Farbe „gewinnt“ auf leerem Brett | Test, der das aktuelle Verhalten dokumentiert; entscheiden, ob `isWin` gegen `null` absichern soll (heute kann `play` nie `null` übergeben) | 🔲 offen (W-06, unverändert durch diese Arbeit) |
| `isWin` setzt `board.length == 9` voraus | `ArrayIndexOutOfBounds` bei kürzerem Array | Grenzwerttest mit falscher Array-Grösse; Vorbedingung dokumentieren | 🔲 offen (W-07) |
| `play` schreibt auf `System.out` | schwer prüfbar, lautes Testlog | für Unit-Tests weiterhin nur Rückgabewert prüfen; E2E-01–03 fangen stdout zusätzlich über Pioneers `StdOut` ab | ✅ für E2E teilweise gelöst |
| Unentschieden nur implizit getestet | Regression könnte Phantom-Sieger liefern | expliziter skriptbasierter Unentschieden-Test (vorhanden: Partie #4) sowie E2E-03 über echtes stdin – behalten und ausbauen | ✅ |

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
| Sprache / JDK | Java 25 (Gradle-Toolchain, Azul Zulu; via Gradle auto-provisioniert) |
| Build | Gradle Wrapper (`./gradlew`), Plugins `java`, `application`, `jacoco`, `pitest` |
| Testframework | JUnit Jupiter 6.1.3 (`useJUnitPlatform()`) |
| E2E-Erweiterung | JUnit Pioneer 3.0.0-RC1 (`@StdIo`/`StdIn`/`StdOut` für reales `System.in`/`System.out`) – siehe §7.4 für die Versionsbegründung |
| Assertions | AssertJ 3.27.7 (`WithAssertions`) |
| Betriebssystem | OS-unabhängig; CI: `ubuntu-24.04` (Container), Entwicklung: Windows/macOS/Linux |
| Ausführung lokal | `./gradlew test` (Unit/Integration), `./gradlew e2eTest` (End-to-End) |

### 6.2 CI-Pipeline (`.github/workflows/CI.yaml`)

- Trigger: jeder `push` sowie `pull_request` auf `main` / `develop`.
- Schritte: `checkout` → `setup-gradle` → `./gradlew build -x test`
  → `./gradlew test` → `./gradlew e2eTest` → `./gradlew jacocoTestReport jacocoTestCoverageVerification`.
- Fehlschlag bricht den Lauf ab und blockiert den Merge; Testberichte werden als
  Artefakt hochgeladen.

### 6.3 Testinfrastruktur (Testcode)

| Mechanismus | Datei | Zweck |
| --- | --- | --- |
| `board(String layout)` | `TicTacToeTestHelpers` | Brett aus `"X X X / . O . / O . ."` oder `"XX.OO...."` bauen |
| `emptyBoard()` | `TicTacToeTestHelpers` | frisches `Stone[9]` aus `null` |
| `ScriptedPlayer(int... moves)` | `TicTacToeTestHelpers` | deterministischer Spieler nach fixer Zugliste |
| `@BeforeEach` leeres Brett | `TicTacToeTestFixtures` | jeder Test startet sauber und isoliert |
| `@AfterEach` Aufräumen | `TicTacToeTestFixtures` | kein geteilter veränderlicher Zustand leckt |
| `givenBoard(layout)` | `TicTacToeTestFixtures` | Fixture-Hook zum Setzen des Bretts im Test |
| `@Tag("e2e")` + `@StdIo`/`StdOut` | `TicTacToeE2ETest` | reales `HumanPlayer` über simuliertes `System.in`/`System.out` treiben, statt `ScriptedPlayer` |
| `assertTimeoutPreemptively(...)` | `TicTacToeE2ETest` | DoS-Tests fail-fast in eigenem Thread statt die Suite aufzuhängen |

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
| HTML (Unit/Integration) | `build/reports/tests/test/index.html` |
| HTML (End-to-End) | `build/reports/tests/e2eTest/index.html` |
| JUnit-XML | `build/test-results/test/*.xml`, `build/test-results/e2eTest/*.xml` |
| Coverage | `build/reports/jacoco/test/html/index.html` (nur `test`-Task; `e2eTest` fliesst bewusst nicht in das Coverage-Gate ein, siehe §7.4 Abgrenzung) |

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
| P-05 | Zug auf belegtes Feld → `IllegalStateException` | Negativtest | ✅ | E2E-14 `givenReplayOfAnAlreadyOccupiedCell_...` (§7.4) |
| P-06 | Zug ausserhalb (`-1`, `9`) → `IllegalStateException` | GWA | ✅ | E2E-12/E2E-13 (§7.4) |
| P-07 | Spieler, der seine Brettkopie mutiert, beeinflusst das Spiel nicht | Negativtest / Isolation | 🔲 | _TODO_ |
| P-08 | Volles Brett ohne Sieger → Rückgabe `null` (Unentschieden) | GWA | ✅ | skriptbasierte Partie #4 in `scriptedGames()` |
| P-09 | Sieger wird zurückgegeben, sobald die Linie voll ist (Spiel stoppt früh) | Zustandsübergang | 🔲 | _TODO_ |

### 7.3 Spieler / Modell

| ID | Verhalten | Technik | Status | Testmethode |
| --- | --- | --- | --- | --- |
| G-01 | GreedyPlayer wählt das kleinste freie Feld | ÄK, Sweep | ✅ | `givenLowerFieldsTaken_whenGreedyPlayerPlays_thenPicksLowestFreeField` |
| G-02 | GreedyPlayer auf vollem Brett → `IllegalStateException` | Negativtest | 🔲 | _TODO_ |
| S-01 | `Stone.opponent()` ist symmetrisch (`CROSS ↔ CIRCLE`) | ÄK | 🔲 | _TODO_ (`@EnumSource`) |

### 7.4 End-to-End-Testfälle (`TicTacToeE2ETest`, Tag `e2e`)

**Scope und Abgrenzung.** "End-to-End" heisst hier: der reale `HumanPlayer`
liest über ein echtes `Scanner`/`System.in` – nicht der `ScriptedPlayer`-
Testdoppel aus §6.3/§7.2. Die Spielpaarung ist überall `HumanPlayer` (X) vs.
`GreedyPlayer` (O), identisch zur Paarung in `TicTacToeMain.main()`; das macht
die Tests sowohl realistisch (gleiche Objekt-Verdrahtung wie die Applikation)
als auch deterministisch (GreedyPlayer braucht kein eigenes stdin). Die
stdin/stdout-Simulation läuft über **JUnit Pioneer** (`@StdIo`/`StdIn`/
`StdOut`), da JUnit Jupiter dafür keinen eigenen Mechanismus bietet – das ist
der in diesem Auftrag geforderte Einsatzzweck von Pioneer. Ein echter
Sub-Prozess (`ProcessBuilder` + gepipter `./gradlew run`) wurde bewusst
**nicht** gewählt: er wäre langsamer, flakier (Start/Stop-Timing, JVM-Start-
zeit) und hätte denselben Code-Pfad (`HumanPlayer.play`) nur über einen
dickeren, schwerer zu debuggenden Umweg erreicht.

Alle 16 E2E-Testfälle laufen über den eigenen Gradle-Task `e2eTest`
(`build.gradle`, gefiltert via `@Tag("e2e")`) und sind in der CI-Pipeline
als eigener Schritt verdrahtet (§6.2). `./gradlew check` zieht `e2eTest`
ebenfalls.

**Versionshinweis JUnit Pioneer.** Zum Zeitpunkt dieser Arbeit (Okt. 2026)
unterstützt die letzte stabile Pioneer-Version (2.3.0, Nov. 2023) JUnit
Jupiter 6 offiziell nicht (eigenes JPMS-Modul, Java-Baseline 17 erst ab
Pioneer 3.0). Pioneer 3.0.0-RC1 (veröffentlicht 23.10.2026) wurde praktisch
gegen das in diesem Projekt verwendete JUnit Jupiter 6.1.3 verifiziert
(`testCompileClasspath` löst auf, `@StdIo`-Smoke-Test läuft grün) und ist
daher bewusst als Abhängigkeit gewählt – als Release Candidate ein
dokumentiertes, kleines Restrisiko (API kann sich bis 3.0.0 final noch
ändern), das für die Dauer dieses Moduls vertretbar ist.

#### Vollständiger Spielablauf (E2E-01 – E2E-03)

| ID | Testmethode | Eingabe (stdin, X) | Erwartetes Verhalten | Tatsächliches Verhalten | Technik |
| --- | --- | --- | --- | --- | --- |
| E2E-01 | `givenMovesViaStdin_whenPlayingFullGame_thenCrossWinsAntiDiagonal` | `0,2,4,6` | Rückgabe `CROSS`, stdout enthält "winner is: CROSS" (Anti-Diagonale 2-4-6, identische Partie wie TESTS.md Test 5) | wie erwartet ✅ (seit Fix **F-01**, siehe unten) | Integration/E2E, Zustandsübergang |
| E2E-02 | `givenMovesViaStdin_whenPlayingFullGame_thenCircleWinsTopRow` | `3,5,6` | Rückgabe `CIRCLE`, stdout enthält "winner is: CIRCLE" (GreedyPlayer vervollständigt Zeile 0-1-2) | wie erwartet ✅ (seit Fix **F-01**) | Integration/E2E, Zustandsübergang |
| E2E-03 | `givenMovesViaStdin_whenPlayingFullGame_thenGameEndsInADraw` | `1,3,4,6,8` | Rückgabe `null`, stdout enthält "it's a draw!" (Brett `O X O / X X O / X O X`, per Brute-Force-Suche gegen die echte Spiel-Engine ermittelt) | wie erwartet ✅ (seit Fix **F-01**) | Integration/E2E, GWA (9 Züge) |

> #### Gefundener Fehler F-01 (test-first behoben): `HumanPlayer` verliert Züge bei Mehrfachaufruf
>
> E2E-01 bis E2E-03 sowie E2E-14 (unten) brauchen alle **≥ 2 Züge derselben
> `HumanPlayer`-Instanz** – und deckten damit beim ersten Schreiben dieser
> Tests (test-first, vor jeder Code-Änderung) folgenden Fehler zuverlässig auf:
>
> - **Ursache:** `HumanPlayer.play(...)` erzeugte bei **jedem** Aufruf einen
>   neuen `new Scanner(System.in, UTF_8)`. Ein `Scanner`/`InputStreamReader`
>   liest intern in Blöcken und puffert dabei typischerweise mehr Bytes aus dem
>   zugrundeliegenden Stream, als die eine zurückgegebene Zeile ausmacht. Wird
>   danach ein **neuer** `Scanner` über denselben (bereits teilweise
>   konsumierten) Stream gelegt, beginnt dieser dort, wo der rohe Stream steht
>   – die im alten, inzwischen verworfenen Scanner gepufferten, aber nie
>   gelesenen Folgezeilen sind unwiederbringlich verloren.
> - **Beobachtetes (vor dem Fix tatsächliches) Verhalten:** Sobald eine
>   `HumanPlayer`-Instanz einen zweiten Zug liefern musste, warf `nextLine()`
>   `java.util.NoSuchElementException: No line found` – das Spiel stürzte ab,
>   statt den zweiten Zug zu lesen. Reproduziert sowohl mit einem isolierten
>   Experiment (`ByteArrayInputStream` mit 5 Zeilen, 5× `new Scanner(...)`)
>   als auch live in E2E-01/02/03/14, bevor der Fix angewendet wurde.
>   Betrifft nicht nur automatisierte Tests: **jede nicht-interaktive
>   Eingabe** (Pipe, Redirect, Skript – z. B. `echo "0\n1\n2" | ./gradlew run`)
>   ist davon betroffen; nur eine zeichenweise tippende, interaktive Konsole
>   maskiert den Fehler zufällig, weil pro Tastendruck meist nur eine Zeile
>   im Stream verfügbar ist.
> - **Erwartetes Verhalten:** jeder gültige Folgezug wird gelesen, unabhängig
>   davon, ob die Eingabe interaktiv oder (teilweise) gepuffert/gepiped
>   ankommt.
> - **Fix (test-first):** `src/main/java/.../players/HumanPlayer.java` hält
>   jetzt **einen** `Scanner` als Instanzfeld, wiederverwendet über alle Züge
>   dieses Spielers hinweg, statt pro Aufruf einen neuen zu erzeugen. Für die
>   tatsächlich gespielte Paarung (`HumanPlayer` vs. `GreedyPlayer`, wie in
>   `main()`) ist das korrekt, da genau eine `HumanPlayer`-Instanz über das
>   ganze Spiel hinweg wiederverwendet wird.
> - **Nachweis:** E2E-01/02/03/14 wurden **vor** dem Fix ausgeführt und
>   schlugen reproduzierbar mit `NoSuchElementException` fehl; nach dem Fix
>   (gleicher Testcode, unverändert) sind alle vier grün. Build-Log-Belege:
>   4 von 16 E2E-Tests rot vor dem Fix, 0 von 16 danach.
> - **Nicht behoben / bewusst ausserhalb des Fixes:** zwei unabhängige
>   `HumanPlayer`-Instanzen (z. B. ein hypothetisches `HumanPlayer` vs.
>   `HumanPlayer`) könnten sich weiterhin gegenseitig Zeilen "stehlen", da
>   jede ihr eigenes `Scanner`-Feld hat. Dieser Fall kommt in der Applikation
>   nicht vor (`main()` spielt immer `HumanPlayer` vs. `GreedyPlayer`) und
>   wurde daher bewusst nicht mitgelöst, um den Fix minimal zu halten; als
>   Hinweis hier dokumentiert statt verschwiegen.

#### Ungültiger, syntaktisch falscher User-Input → `NumberFormatException` (E2E-05 – E2E-11)

| ID | Testmethode | Eingabe | Erwartetes Verhalten | Tatsächliches Verhalten |
| --- | --- | --- | --- | --- |
| E2E-05 | `givenNonNumericInput_...` | `"abc"` | `NumberFormatException` | wie erwartet ✅ |
| E2E-06 | `givenEmptyInput_...` | `""` | `NumberFormatException` | wie erwartet ✅ |
| E2E-07 | `givenWhitespacePaddedInput_...` | `" 3 "` | `NumberFormatException` (kein Trimmen) | wie erwartet ✅ |
| E2E-08 | `givenDecimalInput_...` | `"3.5"` | `NumberFormatException` | wie erwartet ✅ |
| E2E-09 | `givenOverflowingNumericInput_...` | `"99999999999999999999"` (20 Stellen) | `NumberFormatException`, kein Überlauf-Wraparound | wie erwartet ✅ |
| E2E-10 | `givenSqlInjectionStyleInput_...` | `"'; DROP TABLE players; --"` | `NumberFormatException`, Text wird nirgends interpretiert/ausgeführt | wie erwartet ✅ – kein Risiko, da der Zug ausschliesslich via `Integer.parseInt` verarbeitet wird, nie in einer Query/einem Kommando landet |
| E2E-11 | `givenHtmlScriptInjectionStyleInput_...` | `"<script>alert(1)</script>"` | `NumberFormatException` | wie erwartet ✅ – kein Risiko, da nie als HTML gerendert wird |

**Dokumentierte Kuriosität (nicht automatisiert):** `Integer.parseInt`
akzeptiert über `Character.digit(...)` auch nicht-ASCII Unicode-Dezimalziffern,
z. B. das Vollbreiten-Zeichen „８" (U+FF18) → wird zu `8` geparst. Per
eigenständigem Experiment verifiziert (ausserhalb der Suite, da Pioneers
`@StdIo` und `HumanPlayer`s explizites UTF-8-Scanner-Decoding mehrbytige
Eingaben über unterschiedliche, plattformabhängige Pfade kodieren – ein
automatisierter Testfall dafür wäre umgebungsabhängig flaky gewesen). Kein
Sicherheitsrisiko (Resultat bleibt ein gültiger, im Bereich liegender `int`),
aber überraschendes, bisher undokumentiertes Verhalten.

#### Ungültiger, semantisch falscher Input → `IllegalStateException` (E2E-12 – E2E-14)

| ID | Testmethode | Eingabe | Erwartetes Verhalten | Tatsächliches Verhalten |
| --- | --- | --- | --- | --- |
| E2E-12 | `givenNegativeMoveIndex_...` | `"-1"` | `IllegalStateException: cannot play to position -1` | wie erwartet ✅ (schliesst Lücke P-06) |
| E2E-13 | `givenMoveIndexEqualToBoardSize_...` | `"9"` | `IllegalStateException: cannot play to position 9` | wie erwartet ✅ (schliesst Lücke P-06) |
| E2E-14 | `givenReplayOfAnAlreadyOccupiedCell_...` | `"0","0"` | `IllegalStateException: cannot play to position 0` | wie erwartet ✅ (seit Fix **F-01**; schliesst Lücke P-05) |

#### Denial of Service, mit Timeout abgesichert (E2E-15 – E2E-17)

| ID | Testmethode | Szenario | Erwartetes/geprüftes Verhalten | Tatsächliches Verhalten | Abgesichert mit |
| --- | --- | --- | --- | --- | --- |
| E2E-15 | `givenAForeverBlockingPlayerImplementation_...` | `TicTacToePlayer.play()`-Implementierung, die nie zurückkehrt (z. B. hängender Gegner, Endlosschleife) | dokumentiert, **nicht** behoben: `TicTacToeMain.play()` erzwingt kein Zug-Timeout, die Partie hängt für immer | wie befürchtet ⚠️ – bestätigter Befund, siehe §5.5 | `assertTimeoutPreemptively(300ms)` im Test + `@Timeout(10)` als Netz |
| E2E-16 | `givenStdinThatNeverCompletesALine_...` | stdin liefert nie einen Zeilenumbruch und schliesst nie (z. B. Pipe von unvertrauenswürdiger Quelle) | dokumentiert, **nicht** behoben: `Scanner#nextLine()` blockiert für immer, kein Read-Timeout in `HumanPlayer` | wie befürchtet ⚠️ – bestätigter Befund, siehe §5.5 | `assertTimeoutPreemptively(300ms)` + `@Timeout(10)` |
| E2E-17 | `givenAnExtremelyLongSingleLineOfInput_...` | eine einzelne, 2 Mio. Zeichen lange (aber korrekt terminierte) Zahlenzeile | **kein** DoS: `NumberFormatException` in < 100ms (isoliert gemessen); kein quadratisches Blow-up, kein OOM, kein Hängen | wie erwartet ✅ – Negativbefund dokumentiert (dieser Vektor ist sicher) | `assertTimeoutPreemptively(15s)`, grosszügig wegen CI-/IO-Rauschen, nicht wegen der SUT |

E2E-15 und E2E-16 sind **bewusst nicht behoben** – eine echte Mitigation
(z. B. Lese-Timeout für `HumanPlayer`, Zug-Timeout im Engine-Loop) würde die
öffentliche Schnittstelle von `TicTacToePlayer`/`play()` ändern und ist im
freiwilligen Zusatzauftrag "maximale Antwortzeit für den perfekten Player"
vorgesehen (§8.4). Hier: bewusst dokumentiertes Risiko statt stillschweigender
Lücke.

### 7.5 Vorlage für neue Testfälle (🔲 schliessen)

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
| 3 (erledigt) | JaCoCo + Coverage-Gate, PIT-Mutationstest in `build.gradle` | ✅ |
| 4 (erledigt) | **End-to-End-Teststufe:** JUnit Pioneer, `TicTacToeE2ETest` (voller Spielablauf, ungültiger/böswilliger Input, DoS+Timeouts), eigener Gradle-Task `e2eTest`, CI-Schritt; schliesst P-05/P-06; Fehler **F-01** gefunden und test-first behoben, **F-02**/**F-03** dokumentiert | ✅ §7.4 |
| 5 (offen) | Restliche Robustheit `play`: P-04, P-07, P-09 | 🔲 |
| 6 (offen) | `isWin`-Randfälle W-06 – W-08, Modell S-01, G-02 | 🔲 |

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

1. ~~JaCoCo einbinden~~ ✅ erledigt (`build.gradle`, Coverage-Gate in `check`).
2. ~~HumanPlayer auf testbare Eingabe umbauen~~ ✅ erledigt über `@StdIo`
   (JUnit Pioneer) + Scanner-Reuse-Fix (F-01) – kein Konstruktor-Umbau nötig.
3. ~~PIT-Mutationstest~~ ✅ bereits in `build.gradle` konfiguriert.
4. Restliche 🔲-Lücken in §7 schliessen: P-04, P-07, P-09 (Robustheit `play`),
   W-06 – W-08 (`isWin`-Randfälle), S-01, G-02.
5. Semantik von `isWin(_, null)` festlegen und dokumentieren (W-06).
6. **Freiwillige Zusatzaufträge** (siehe Auftragsblatt), priorisiert nach
   Nutzen für die hier dokumentierten offenen Befunde:
   - Maximale Antwortzeit für den perfekten Player festlegen und prüfen →
     würde **F-02** direkt beheben (Zug-Timeout im Engine-Loop).
   - Fuzzing mit Jazzer auf `HumanPlayer`/`Integer.parseInt`-Grenzen.
   - Property-based Tests (jqwik) für Spielablauf-Invarianten.
   - Mutation-Coverage-Vergleich Unit- vs. E2E-Tests mit PITest.

> **Abgabe-Zusammenfassung (Stand 2026-10-25, siehe §1.2 v0.2):** 29
> Unit-/Integrationstests (`./gradlew test`) + 16 End-to-End-Tests
> (`./gradlew e2eTest`), beide Tasks sowie Coverage-Gate grün in CI.
> 1 Fehler gefunden und test-first behoben (**F-01**, §7.4/§5.5); 2 weitere
> Befunde dokumentiert statt verschwiegen (**F-02**, **F-03** – DoS-Risiken
> ohne Timeout-Durchsetzung, bewusst ausserhalb des mandatorischen Scopes,
> siehe §8.4). Offene 🔲-Lücken (P-04, P-07, P-09, W-06 – W-08, S-01, G-02)
> sind vorbestehend, unverändert durch diese Arbeit und in §7/§8.4 begründet.

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
