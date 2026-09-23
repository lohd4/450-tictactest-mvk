# DevContainer-Versionierung & Release-Prozess

> **Status:** Umsetzt bis "PR wird erstellt" (Auftrag 3, dritter Punkt). Die
> Punkte "CI-Jobs/lokale Umgebung nutzen automatisch neueste Version" sind
> noch offen (siehe [Offene Punkte](#offene-punkte)).

## Konzept

Das DevContainer-Image (`ghcr.io/<owner>/tictactest-dev`) wird von
[`.github/workflows/devcontainer-image.yaml`](../.github/workflows/devcontainer-image.yaml)
bei jeder Änderung an `.devcontainer/**` automatisch gebaut und nach GHCR
gepusht. Damit nicht jedes ungeprüfte Build sofort "offiziell" wird, gibt es
zwei Kategorien von Tags:

| Tag | Beispiel | Bedeutung |
| --- | --- | --- |
| Branch-Slug | `ghcr.io/…/tictactest-dev:my-feature` | Unreleased. Jeder Push auf einen Branch, der `.devcontainer/**` ändert, erzeugt/aktualisiert diesen Tag. Zum Testen der Container-Änderung selbst, bevor sie nach `main` gemerged wird. |
| `latest` | `ghcr.io/…/tictactest-dev:latest` | Wird bei jedem Push auf `main` neu gesetzt. |
| Versions-Tag | `ghcr.io/…/tictactest-dev:v1.0.1` | Der eigentliche **Release**. Wird nur bei einem Push auf `main` erzeugt, siehe unten. |

Die aktuell **freigegebene** Version steht in
[`.devcontainer/VERSION`](../.devcontainer/VERSION) (`vMAJOR.MINOR.PATCH`).
Diese Datei ist die Quelle der Wahrheit – nicht "was zuletzt in GHCR gelandet
ist".

## Ablauf bei einer Änderung am DevContainer

1. Jemand ändert `.devcontainer/Dockerfile` (oder `devcontainer.json` etc.)
   auf einem Branch und öffnet einen PR nach `main`.
2. Bei jedem Push auf diesen Branch baut die Pipeline das Image und pusht es
   unter dem Branch-Slug-Tag – so kann die Änderung selbst getestet werden
   (z. B. lokal `docker pull ghcr.io/<owner>/tictactest-dev:<branch>`),
   ohne dass sie schon "offiziell" ist.
3. Wird der PR nach `main` gemerged, läuft die Pipeline erneut, diesmal auf
   `main`:
   - `.devcontainer/VERSION` wird gelesen (z. B. `v1.0.0`) und die Patch-Zahl
     wird automatisch erhöht (`v1.0.1`).
   - Das Image wird zusätzlich unter `latest` **und** `v1.0.1` gepusht.
   - Es wird automatisch ein neuer Pull Request erstellt
     (`devcontainer-release/v1.0.1`), der `.devcontainer/VERSION` auf
     `v1.0.1` setzt.
4. **Das Image liegt damit schon in der Registry, gilt aber noch nicht als
   freigegeben.** Erst wenn dieser automatisch erstellte PR reviewt und
   gemerged wird, gilt `v1.0.1` als offiziell freigegebene Version (die
   Freigabe ist also ein bewusster, menschlicher Merge-Schritt – kein Tag in
   GHCR allein reicht).

Das erfüllt die Anforderung "wir möchten verhindern, dass Container
verwendet werden, welche noch nicht offiziell freigegeben wurden": Ein
Versions-Tag in GHCR ist nur ein *Vorschlag*; erst der gemergte Bump-PR macht
ihn zur freigegebenen Version.

## Bekannte Einschränkung

Der automatisch erstellte PR wird mit dem Standard-`GITHUB_TOKEN` erstellt.
GitHub startet damit **keine** weiteren Workflows auf diesem PR (z. B. würde
`coverage-gate.yaml` dort nicht automatisch laufen). Falls das gewünscht ist,
müsste stattdessen ein Personal Access Token oder eine GitHub App verwendet
werden (bewusst nicht umgesetzt, da das ein zusätzliches Secret braucht).

## Offene Punkte

Aus Auftrag 3 noch nicht umgesetzt:

- CI-Jobs (`CI.yaml`, `coverage-gate.yaml`, `mutation-testing.yaml`) lesen
  aktuell **nicht** `.devcontainer/VERSION`, sondern wählen das Image über
  `.github/scripts/resolve-image.sh` dynamisch (Branch-Tag → Default-Branch-Tag
  → `latest`). Um die Freigabe wirklich durchzusetzen, müssten diese Jobs auf
  den in `VERSION` gepinnten Tag umgestellt werden.
- Lokale Entwicklungsumgebungen (`devcontainer.json`) bauen das Image aktuell
  lokal aus dem `Dockerfile` und beziehen es nicht aus GHCR – die Frage
  "automatisch neueste Version lokal" ist damit anders (aber gültig) gelöst
  und noch nicht mit dem Versions-Tag verknüpft.
