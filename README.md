# TicTacTest

Tic-Tac-Toe als Konsolen-Applikation (Java 25, Gradle) – mit automatisiertem
Release-Prozess und als Web-App in der Cloud spielbar.

## 🎮 Jetzt spielen

<!-- play-url:start -->
> ### ▶ [Jetzt spielen](http://tictactest-frontend-1dead7af5e1136442f92fe8362.s3-website-us-east-1.amazonaws.com)
>
> Web-Konsole: <http://100.57.214.23/version> meldet die laufende Backend-Version.
<!-- play-url:end -->

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

## Cloud: Infrastruktur und Deployment

Die Infrastruktur (EC2 mit Web-Konsole, Elastic IP, S3-Buckets) ist in
[`infra/`](infra/) mit **Terraform** beschrieben und wird lokal ausgerollt:

```bash
cd infra
cp terraform.tfvars.example terraform.tfvars
terraform init && terraform plan && terraform apply
cd .. && ops/sync-github-env.sh   # Outputs → GitHub Variables + Link oben
```

Die Applikation wird davon **getrennt** deployt: Ein Release-Tag `v*` deployt
automatisch nur, was sich seit dem letzten Release geändert hat – ohne
`terraform apply` und ohne die Instanz neu zu erstellen. Eine bereits
veröffentlichte Version lässt sich gezielt erneut deployen:

```bash
gh workflow run deploy.yaml -f version=1.2.0
```

Alles dazu – Secrets-Konzept, Ablauf, Rollback, Reflexion – in
[docs/deployment.md](docs/deployment.md).


## Release

Ein Release entsteht nur durch einen bewusst gesetzten Git-Tag `v*` – ein Push
auf `main` erzeugt keinen. Jeder Release enthält das ausführbare Jar, das
Frontend-Archiv und SHA-256-Prüfsummen:

```bash
git tag -a v1.2.0 -m "Release v1.2.0"
git push origin v1.2.0
```

Details und Vorbedingungen: [RELEASE.md](RELEASE.md).
