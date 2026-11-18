# TicTacTest

Tic-Tac-Toe als Konsolen-Applikation (Java 25, Gradle) – mit automatisiertem
Release-Prozess und als Web-App in der Cloud spielbar.

## 🎮 Jetzt spielen

> **Web-App:** _wird in Auftrag 2 eingetragen, sobald die Infrastruktur steht_

Du bist `X`, der Computer (`GreedyPlayer`) ist `O`. Zug eingeben heisst: Feldnummer
`0`–`8` tippen und mit <kbd>Enter</kbd> bestätigen.

```
0 | 1 | 2
--+---+--
3 | 4 | 5
--+---+--
6 | 7 | 8
```

## Lokal spielen

Ohne irgendetwas zu bauen – direkt aus dem letzten Release:

```bash
# Variante A: nur das Spiel im Terminal
curl -LO https://github.com/lohd4/450-tictactest-mvk/releases/latest/download/tictactest-1.1.0.jar
java -jar tictactest-1.1.0.jar

# Variante B: die komplette Web-App (Terminal im Browser)
cd ops/local && ./fetch-release.sh && docker compose up -d
#  Frontend      http://localhost:8000
#  Web-Konsole   http://localhost:8080
```

Optionen des Jars: `--help` / `-h`, `--version` / `-v`.

## Entwicklung

```bash
./gradlew build          # kompilieren, testen, Coverage-Gate
./gradlew run            # Spiel direkt starten
./gradlew e2eTest        # End-to-End-Tests
./gradlew pitest         # Mutation Testing
```

Die Entwicklungsumgebung ist als DevContainer versioniert – siehe
[doc/DEVCONTAINER_VERSIONING.md](doc/DEVCONTAINER_VERSIONING.md).

## Dokumentation

| Dokument | Inhalt |
| --- | --- |
| [RELEASE.md](RELEASE.md) | Release-Prozess: wann, wer, wie, Versionsschema |
| [CHANGELOG.md](CHANGELOG.md) | Änderungen pro Release |
| [docs/webkonsole.md](docs/webkonsole.md) | Web-Konsole: Werkzeugwahl, Sicherheit, Versionsabfrage, lokaler Betrieb |
| [docs/deployment.md](docs/deployment.md) | Infrastruktur, Deployment, Secrets-Konzept, Promotion-Strategie |
| [doc/TESTKONZEPT.md](doc/TESTKONZEPT.md) | Teststrategie |
| [doc/TESTS.md](doc/TESTS.md) | Testfall-Dokumentation |

## Release

Ein Release entsteht nur durch einen bewusst gesetzten Git-Tag `v*` – ein Push
auf `main` erzeugt keinen. Jeder Release enthält das ausführbare Jar, das
Frontend-Archiv und SHA-256-Prüfsummen:

```bash
git tag -a v1.2.0 -m "Release v1.2.0"
git push origin v1.2.0
```

Details und Vorbedingungen: [RELEASE.md](RELEASE.md).
