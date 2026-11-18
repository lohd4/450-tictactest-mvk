# Release-Prozess TicTacTest

Diese Datei beschreibt vollständig, wie aus einem bestimmten Stand des
Git-Repositories eine nachvollziehbare, reproduzierbare und kontrolliert
veröffentlichte Version von TicTacTest entsteht. Sie ist so geschrieben, dass
eine andere Person den Release ohne Rückfragen durchführen kann.

## Überblick

```
Entwicklung (Feature-Branch)
        ↓  Pull Request
Änderungen nach main           ← CI: Build + Tests + Coverage-Gate
        ↓
CHANGELOG.md aktualisieren     ← manuell, beschreibt die Änderungen
        ↓
Version festlegen (MAJOR.MINOR.PATCH)
        ↓
Git-Tag erstellen  (git tag -a v1.0.0)
        ↓
Tag zu GitHub pushen (git push origin v1.0.0)
        ↓
GitHub Actions "Release" startet   ← nur durch den Tag, nie durch einen Push auf main
        ↓
Tests (Unit, E2E, Coverage-Gate)   ← schlägt etwas fehl: Abbruch, kein Release
        ↓
Build → ausführbares JAR (tictactest-1.0.0.jar)
        ↓
Smoke-Test des JARs (java -jar … --version)
        ↓
GitHub Release erstellen + JAR und SHA-256 anhängen
        ↓
JAR von der Release-Seite herunterladen und starten
```

## Die wichtigsten Fragen auf einen Blick

| Frage | Antwort |
| --- | --- |
| **Wann wird ein Release erstellt?** | Wenn bewusst entschieden wird, dass ein Stand auf `main` veröffentlicht werden soll – z. B. nach Abschluss eines Features oder nach einem wichtigen Bugfix. Nicht bei jeder Änderung. |
| **Wer bzw. was startet einen Release?** | Ein Mensch, indem er einen Tag `vMAJOR.MINOR.PATCH` auf einen Commit auf `main` setzt und diesen Tag pusht. Technisch startet der Tag-Push den Workflow [`.github/workflows/release.yaml`](.github/workflows/release.yaml). Alternativ kann derselbe Workflow für einen bereits existierenden Tag manuell über *Actions → Release → Run workflow* gestartet werden (`workflow_dispatch`, z. B. wenn der erste Lauf an einem Infrastrukturfehler gescheitert ist). |
| **Warum löst nicht jeder Push auf `main` einen Release aus?** | Nicht jeder Stand auf `main` ist veröffentlichungsreif: `main` sammelt auch Zwischenstände, Refactorings und Dokumentationsänderungen. Ein automatischer Release pro Push würde eine Flut bedeutungsloser Versionen erzeugen, die Versionsnummer hätte keine Aussagekraft mehr, und das Changelog liesse sich nicht sinnvoll pflegen. Die Veröffentlichung ist deshalb eine **bewusste Entscheidung**; der Workflow reagiert ausschliesslich auf `push.tags: v*` – kein Branch-Trigger. |
| **Wie wird die Versionsnummer festgelegt?** | Nach `MAJOR.MINOR.PATCH`, siehe [Versionsnummer festlegen](#versionsnummer-festlegen). Die Person, die den Release macht, legt sie anhand der Einträge im Changelog fest. |
| **Wie wird ein Release-Tag erstellt?** | `git tag -a v1.0.0 -m "Release v1.0.0"` und `git push origin v1.0.0`, siehe [Schritt für Schritt](#schritt-für-schritt). |
| **Welcher Commit gehört zu einem Release?** | Genau der Commit, auf den der Tag zeigt (`git rev-list -n 1 v1.0.0`). Der Workflow checkt exakt diesen Tag aus (`ref: <tag>`), und die Commit-ID steht zusätzlich in den Release-Notes. Jedes Artefakt ist damit eindeutig einem Commit zuordenbar. |
| **Wie wird das JAR gebaut?** | Mit Gradle: `./gradlew clean jar` erzeugt `build/libs/tictactest-<version>.jar`. Das `jar`-Target schreibt `Main-Class` ins Manifest, dadurch ist das JAR direkt startbar. Es gibt keine Laufzeit-Abhängigkeiten, deshalb reicht das normale JAR (kein Fat-Jar nötig). |
| **Wo kann das JAR heruntergeladen werden?** | Auf der GitHub-Release-Seite unter *Assets*: <https://github.com/lohd4/450-tictactest-mvk/releases> – dort `tictactest-<version>.jar` (und optional die Datei `.sha256` zur Prüfung). |
| **Was enthält das Changelog?** | Pro Version: Versionsnummer, Release-Datum sowie die Abschnitte `Added` (neue Funktionen), `Changed` (Änderungen bestehender Funktionen) und `Fixed` (behobene Fehler) – verständlich formuliert, kein Commit-Log. Siehe [CHANGELOG.md](CHANGELOG.md). |
| **Was passiert, wenn beim Release ein Test fehlschlägt?** | Der Workflow bricht ab. Tests laufen **vor** dem Build- und Release-Schritt, deshalb entsteht weder ein GitHub Release noch ein veröffentlichtes JAR. Der Tag bleibt bestehen, zeigt aber auf einen Stand ohne Release. Vorgehen: Fehler auf `main` beheben, Changelog ggf. anpassen und einen **neuen** Tag mit erhöhter PATCH-Nummer setzen. Einen bereits gepushten Tag zu verschieben ist nicht erlaubt – ein Tag bezeichnet dauerhaft genau einen Commit. |

## Versionsnummer festlegen

Es gilt `MAJOR.MINOR.PATCH`, der Git-Tag trägt zusätzlich ein `v`
(Version `1.0.0` → Tag `v1.0.0`).

| Teil | Wird erhöht, wenn … | Beispiel bei TicTacTest |
| --- | --- | --- |
| **MAJOR** | eine Änderung nicht abwärtskompatibel ist: bestehendes Verhalten, auf das sich Benutzer verlassen, entfällt oder ändert sich grundlegend. | Die Feldnummerierung wechselt von `0–8` auf Koordinaten `a1–c3`; eine bestehende Kommandozeilen-Option wird entfernt. |
| **MINOR** | neue Funktionalität dazukommt, bestehendes Verhalten aber unverändert bleibt. | Eine neue Option wie `--help`; ein zusätzlicher Computergegner; eine Option, um die Seiten zu tauschen. |
| **PATCH** | nur Fehler behoben oder interne Details verbessert werden, ohne Funktionsumfang zu ändern. | Falsche Gewinnerkennung in einer Diagonale korrigiert; Tippfehler in einer Ausgabe; Abbruch bei ungültiger Eingabe abgefangen. |

Faustregel: Steht im Changelog-Abschnitt etwas unter `Added`, ist es mindestens
MINOR; steht dort nur `Fixed`, genügt PATCH; entfällt oder ändert sich
bestehendes Verhalten, ist es MAJOR.

Reine Änderungen an Tests, CI-Konfiguration oder Dokumentation rechtfertigen
für sich genommen **keinen** Release.

### Woher das JAR seine Version bezieht

Es gibt nur eine Quelle der Wahrheit: den **Git-Tag**. Die Version ist nirgends
im Quellcode hartcodiert.

1. Der Workflow liest den gepushten Tag (`v1.0.0`) und gibt ihn als
   `RELEASE_VERSION` an Gradle weiter.
2. `build.gradle` entfernt das führende `v` und setzt daraus `project.version`.
   Ohne `RELEASE_VERSION` wird der Tag verwendet, der lokal exakt auf `HEAD`
   zeigt; existiert auch dieser nicht, ist die Version `0.0.0-SNAPSHOT`.
3. Daraus entstehen Dateiname (`tictactest-1.0.0.jar`) und der Manifest-Eintrag
   `Implementation-Version`.
4. `java -jar tictactest-1.0.0.jar --version` gibt genau diesen Wert aus.

Damit gilt: gleicher Commit + gleicher Tag → gleiche Version. Und jedes
heruntergeladene JAR kann selbst Auskunft geben, aus welchem Release es stammt.

## Bedingungen vor einem Release

Alle folgenden Punkte müssen erfüllt sein. Die rechte Spalte zeigt, wie das
überprüft wird – das meiste prüft die Automatisierung, nicht der Mensch.

| Bedingung | Prüfung |
| --- | --- |
| Die Anwendung befindet sich auf dem gewünschten Stand und alle vorgesehenen Änderungen sind auf `main`. | `git switch main && git pull`, danach `git log --oneline -5` und Abgleich mit den geplanten Änderungen. Auf `main` kommt Code nur über Pull Requests. |
| Das Projekt lässt sich erfolgreich bauen. | Lokal `./gradlew clean build`; zusätzlich baut die CI (`.github/workflows/CI.yaml`) jeden Push und jeden PR. Der Release-Workflow baut den getaggten Stand erneut von Grund auf. |
| Alle automatisierten Tests sind erfolgreich. | Lokal `./gradlew test e2eTest`; im Release-Workflow laufen `test`, `e2eTest` und das JaCoCo-Coverage-Gate **vor** dem Build-Schritt – schlägt eines fehl, entsteht kein Release. |
| Das Changelog wurde aktualisiert. | Der Abschnitt zur Zielversion existiert in `CHANGELOG.md`. Der Workflow erzwingt das: Fehlt der Abschnitt, bricht die Erstellung der Release-Notes mit einem Fehler ab. |
| Die gewünschte Versionsnummer wurde festgelegt. | Nach den Kriterien oben aus den Changelog-Einträgen abgeleitet; sie darf noch nicht als Tag existieren (`git tag -l` bzw. die Releases-Seite). |
| Das JAR startet tatsächlich. | Lokal `java -jar build/libs/tictactest-<version>.jar --version`; im Workflow läuft derselbe Smoke-Test, bevor das Release angelegt wird. |

## Schritt für Schritt

### 1. Stand prüfen

```bash
git switch main
git pull
./gradlew clean build          # kompiliert, testet und prüft die Coverage
```

### 2. Changelog aktualisieren

In [`CHANGELOG.md`](CHANGELOG.md) einen neuen Abschnitt direkt unter
`## Unreleased` anlegen:

```markdown
## 1.1.0 - 2026-11-18

### Added
- Neue Option `--help` …

### Fixed
- Tippfehler in der Zugaufforderung korrigiert (#42)
```

Überschrift exakt im Format `## <version> - <YYYY-MM-DD>` – der Release-Workflow
schneidet genau diesen Abschnitt heraus und verwendet ihn als Release-Notes.
Die Änderung wird (über einen Pull Request) nach `main` gebracht.

### 3. Version festlegen und taggen

```bash
git switch main
git pull
git tag -a v1.1.0 -m "Release v1.1.0"
git push origin v1.1.0
```

Der Tag wird auf dem Commit gesetzt, der veröffentlicht werden soll – in der
Regel der aktuelle `HEAD` von `main`. Soll ein älterer Stand veröffentlicht
werden, wird die Commit-ID angehängt: `git tag -a v1.1.0 <commit> -m "…"`.

### 4. Workflow beobachten

Unter *Actions → Release* läuft der Workflow an. Er checkt den Tag aus, führt
Tests und Coverage-Gate aus, baut das JAR, testet dessen Start, berechnet die
SHA-256-Prüfsumme und legt das GitHub Release an.

### 5. Release testen

Dieser Schritt gehört zwingend dazu – ein Release gilt erst als erfolgreich,
wenn das **veröffentlichte** Artefakt geprüft wurde:

```bash
# JAR von der Release-Seite herunterladen, dann:
java -jar tictactest-1.1.0.jar --version   # muss die Release-Version ausgeben
java -jar tictactest-1.1.0.jar             # Spiel muss startbar sein
sha256sum -c tictactest-1.1.0.jar.sha256   # optional: Integrität prüfen
```

Die Anwendung muss laufen, ohne dass sie erneut aus dem Quellcode gebaut wird.

## Inhalt eines Releases

Jedes GitHub Release enthält:

- **Tag** – z. B. `v1.1.0`
- **Commit-ID** – der exakte Stand, aus dem gebaut wurde
- **Änderungen** – der Abschnitt aus `CHANGELOG.md`
- **Artefakt** – `tictactest-<version>.jar` plus `.sha256`-Prüfsumme

## Wenn etwas schiefgeht

| Situation | Vorgehen |
| --- | --- |
| Ein Test schlägt im Release-Workflow fehl. | Kein Release wird erstellt. Fehler auf `main` beheben und mit erhöhter PATCH-Version neu taggen (z. B. `v1.1.1`). |
| Der Changelog-Abschnitt fehlt. | Der Workflow bricht beim Erzeugen der Release-Notes ab. Changelog auf `main` ergänzen, neuen Tag setzen. |
| Falscher Commit getaggt. | Tag lokal und remote löschen (`git tag -d v1.1.0`, `git push origin :refs/tags/v1.1.0`), ein eventuell entstandenes Release auf GitHub löschen und korrekt neu taggen. Das ist nur zulässig, solange niemand das Artefakt bereits bezogen hat – sonst eine neue Version veröffentlichen. |
| Der Workflow scheitert an Infrastruktur (z. B. Netzwerk). | *Actions → Release → Run workflow* und den bestehenden Tag angeben; der Workflow baut denselben Commit erneut. |
