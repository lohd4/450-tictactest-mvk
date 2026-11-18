# Web-Konsole (Auftrag 1)

TicTacTest bleibt eine Konsolen-Applikation. Statt sie umzuschreiben, wird das
**unveränderte Jar aus dem Release** von einer Web-Konsole gestartet, die Ein-
und Ausgabe in ein Terminal im Browser überträgt. Dieses Dokument beschreibt die
Werkzeugwahl, den lokalen Betrieb, die Konfiguration und die Versionsabfrage.

> Der Quellcode des Spiels wird dafür nicht angefasst. Gebaut wird nichts – es
> läuft genau das Artefakt, das der Release-Prozess ([RELEASE.md](../RELEASE.md))
> veröffentlicht hat.

## 1. Werkzeugwahl: ttyd

| Werkzeug | Bewertung |
| --- | --- |
| **ttyd 1.7.7** ✅ | Ein einzelnes, statisch gelinktes Binary (1.3 MB, keine Laufzeit-Abhängigkeiten). Bringt ein vollwertiges Terminal (xterm.js) mit, inklusive ANSI-Farben – genau das, was TicTacTest ausgibt. Startet pro Verbindung einen Prozess. Lässt sich auf eine fixe Version und Prüfsumme festnageln. |
| GoTTY | Gleiches Prinzip, aber seit Jahren kaum gepflegt. Kein Grund, das ältere Werkzeug zu wählen. |
| websocketd | Überträgt nur Textzeilen, kein echtes Terminal. Wir müssten eine eigene HTML/JS-Seite schreiben **und** die ANSI-Escape-Sequenzen selbst interpretieren – also genau die Arbeit, die xterm.js schon erledigt. |

**Entscheidung: ttyd.** Ausschlaggebend ist die Kombination aus statischem Binary
(reproduzierbar installierbar, siehe unten) und eingebautem xterm.js: TicTacTest
färbt sein Brett mit ANSI-Codes (`\033[1m`, `\033[37m`), und nur ein echtes
Terminal stellt das korrekt dar.

Festgenagelt wird ttyd über Version **und** Prüfsumme – lokal wie auf EC2
dieselben Werte:

```
Version: 1.7.7
URL:     https://github.com/tsl0922/ttyd/releases/download/1.7.7/ttyd.x86_64
SHA-256: 8a217c968aba172e0dbf3f34447218dc015bc4d5e59bf51db2f2cd12b7be4f55
```

Ohne Pinning liefe auf jeder Maschine und nach jedem Instanz-Neubau potenziell
ein anderes Terminal – das Gegenteil von reproduzierbar.

### Nötige Optionen

| Option | Warum |
| --- | --- |
| `--writable` (`-W`) | **Ohne diese Option kann man im Browser nur zuschauen, nicht tippen.** ttyd ist absichtlich read-only voreingestellt. |
| `--max-clients 10` | Begrenzt die Anzahl gleichzeitiger Sitzungen und damit den Speicherverbrauch (siehe [Abschnitt 5](#5-beobachtungen-aus-dem-betrieb)). |
| `--port 7681` | Fester Port hinter dem Reverse Proxy. |
| `--cwd /tmp` | Arbeitsverzeichnis ohne Schreibrechte auf die Applikation. |

## 2. Architektur

Lokal und in der Cloud dieselbe Form – nur die Adressen unterscheiden sich:

```
Browser
   │
   ├──► Frontend        :8000   statische Seite      (Cloud: S3 Static Website)
   │       │ bettet per <iframe> ein, fragt /version per fetch ab
   │       ▼
   └──► Gateway (nginx) :8080   /version  +  Reverse Proxy
               │                (Cloud: nginx auf der EC2-Instanz, Port 80)
               ▼
           ttyd         :7681   startet pro Verbindung
               │
               ▼
           java -jar tictactest-<version>.jar
```

Frontend und Web-Konsole sind **getrennte Origins** – lokal zwei Ports, in der
Cloud zwei Hosts. Das ist Absicht: So fällt schon lokal auf, was sonst erst in
der Cloud auffiegt (CORS, siehe Abschnitt 4).

### Warum nginx davor?

* Die **Versionsabfrage** braucht einen HTTP-Endpunkt. Das Jar bietet keinen an,
  und wir verändern es nicht.
* Es bleibt bei **einem offenen Port** – die Security Group auf EC2 muss nur
  Port 80 öffnen statt zusätzlich 7681.
* Nur nginx kann den **CORS-Header** setzen, den das Frontend für die
  Versionsabfrage braucht.

Wichtig für den Reverse Proxy ist das WebSocket-Upgrade; ohne diese drei Zeilen
lädt das Terminal, verbindet sich aber nie:

```nginx
proxy_http_version 1.1;
proxy_set_header Upgrade $http_upgrade;
proxy_set_header Connection "upgrade";
```

## 3. Sicherheit

Eine Web-Konsole ist für **alle** erreichbar, die die URL kennen. Es gibt keine
Anmeldung. Entsprechend gilt:

| Risiko | Gegenmassnahme |
| --- | --- |
| **ttyd startet eine Shell.** Würde dort `bash`, `sh` oder `login` stehen, bekäme jeder Besucher eine Shell auf dem Server – mit den Rechten des Dienstbenutzers. Das heisst: Dateien lesen, Software nachladen, von dort weiter ins Netz. Bei einem Cloud-Server zusätzlich Zugriff auf den Instance-Metadata-Endpunkt und damit auf die IAM-Rolle der Instanz. | ttyd bekommt **ausschliesslich** `java -jar …` als Kommando. Nie eine Shell, auch nicht „nur zum Debuggen". Kontrolliert mit `tr "\0" " " < /proc/1/cmdline`. |
| Dienst läuft als `root` | Läuft als unprivilegierter Benutzer (lokal `vscode` uid 1000, auf EC2 ein eigener Service-User). Verifiziert: `uid=1000(vscode)`. |
| Schreibzugriff auf die Applikation | Jar und Frontend sind read-only eingebunden (`:ro`), Arbeitsverzeichnis ist `/tmp`. |
| Unbegrenzt viele Sitzungen → Server geht in die Knie | `--max-clients 10`. |
| Offene Ports | Nur der Gateway-Port ist erreichbar; ttyd selbst hört nur im internen Netz (`expose`, kein `ports`). |

Was TicTacTest hier hilft: Das Spiel liest ausschliesslich eine Zahl über
`Integer.parseInt` und gibt sonst nichts weiter – es gibt keine Stelle, an der
Benutzereingaben als Befehl interpretiert würden (siehe
[doc/TESTKONZEPT.md](../doc/TESTKONZEPT.md), die Tests zu bösartigen Eingaben).

## 4. Versionsabfrage

Nach einem Deployment muss die Pipeline (Auftrag 3) prüfen können, **welche
Version gerade läuft**. Das Jar bietet dafür nichts an und wird nicht verändert.

**Lösung:** Beim Deployment wird neben das Jar eine Datei `version.txt`
geschrieben, die nginx unter `/version` als `text/plain` ausliefert.

```console
$ curl -i http://localhost:8080/version
HTTP/1.1 200 OK
Content-Type: text/plain
Access-Control-Allow-Origin: *
Cache-Control: no-store

1.1.0
```

Die Version ist **nicht von Hand gepflegt**. Sie stammt aus dem Release-Tag:

```
Git-Tag v1.1.0
   └─► Release-Workflow baut tictactest-1.1.0.jar
          └─► Deployment schreibt "1.1.0" in version.txt
                 └─► nginx liefert sie unter /version aus
```

Warum aus dem Tag und nicht aus dem Jar-Manifest? Beides wäre möglich – das Jar
kennt seine Version ja selbst (`java -jar … --version`). Aber:

* Ein HTTP-Endpunkt ist von aussen abfragbar, ohne sich auf die Instanz zu
  verbinden. Die Pipeline braucht genau das.
* `--version` müsste einen Prozess starten; `version.txt` kostet nichts.
* Das Deployment ist die Instanz, die die Wahrheit kennt: Es hat die Datei
  gerade hingelegt. Steht dort die falsche Version, ist das Deployment
  fehlgeschlagen – genau das soll die Prüfung erkennen.

`Cache-Control: no-store` ist wichtig: Eine gecachte Antwort würde nach einem
Deployment die alte Version melden und die Prüfung in die Irre führen.

### CORS

Das Frontend liegt auf einem anderen Origin als die Versionsabfrage. Ohne
`Access-Control-Allow-Origin` blockiert der Browser den `fetch`, und die Seite
könnte die Backend-Version nicht anzeigen (sichtbar als CORS-Fehler in der
Entwickler-Konsole). nginx setzt den Header deshalb explizit.

Der `<iframe>` mit dem Terminal ist davon **nicht** betroffen – ein iframe
unterliegt nicht der Same-Origin-Policy für das blosse Einbetten.

## 5. Beobachtungen aus dem Betrieb

Alle Werte lokal gemessen (ttyd 1.7.7, Jar aus Release v1.1.0, Java 25).

### Was passiert bei Spielende?

Das Spiel endet, `main()` kehrt zurück, der JVM-Prozess endet mit Code 0. ttyd
schliesst daraufhin die WebSocket-Verbindung:

```
N: process exited with code 0, pid: 11
N: WS closed from 172.17.0.1, clients: 0
```

Im Browser bleibt das Endergebnis stehen, das Terminal nimmt aber keine Eingaben
mehr an. **Ein neues Spiel startet man, indem man die Seite neu lädt** – jede
neue Verbindung startet einen neuen Prozess. Das Frontend hat dafür einen Knopf
„Neues Spiel", der nichts anderes tut, als den iframe neu zu laden.

### Was passiert bei ungültiger Eingabe?

`HumanPlayer` parst die Eingabe mit `Integer.parseInt`. Alles, was keine Zahl
ist, wirft – und die Partie ist vorbei:

```
where to put the next CROSS? (0-8):
abc
Exception in thread "main" java.lang.NumberFormatException: For input string: "abc"
	at ch.bbw.m450.tictactoe.players.HumanPlayer.play(HumanPlayer.java:25)
```

Der Prozess endet mit Code 1, die Sitzung ist beendet. Ein belegtes oder
ausserhalb von 0–8 liegendes Feld führt analog zu `IllegalStateException`.

Das ist **unverändertes Verhalten des Jars** und für diese Aufträge in Ordnung.
Das Frontend weist in den Spielregeln darauf hin. Wollte man das abfangen,
gehörte die Änderung ins Spiel (neuer Release), nicht in die Web-Konsole.

### Mehrere Tabs gleichzeitig

Gemessen mit drei parallelen Verbindungen:

```
JVM pid=190  RSS=43 MiB
JVM pid=212  RSS=43 MiB
JVM pid=232  RSS=44 MiB
concurrent JVMs: 3
```

**Eine JVM pro Verbindung, rund 43 MiB pro Sitzung.** Zwei Tabs = zwei
unabhängige Spiele, die nichts voneinander wissen – es gibt keinen gemeinsamen
Spielzustand.

Für einen kleinen Server mit 1 GB RAM heisst das: Nach Abzug von
Betriebssystem, nginx und ttyd (grob 250–300 MB) bleiben ~700 MB, also
theoretisch ~15 gleichzeitige Partien. Ohne Begrenzung würde der Server beim
16. Besucher anfangen zu swappen oder der OOM-Killer würde zuschlagen – und
zwar unkontrolliert, womöglich träfe es nginx. Deshalb `--max-clients 10`:
lieber eine abgewiesene Verbindung als eine umgefallene Instanz.

## 6. Lokal starten

Voraussetzung: Docker. Alles Weitere kommt aus dem Release.

```bash
cd ops/local
./fetch-release.sh            # neuester Release; oder: ./fetch-release.sh v1.2.0
docker compose up -d
```

Dann im Browser:

| URL | Inhalt |
| --- | --- |
| <http://localhost:8000> | Frontend mit eingebettetem Terminal |
| <http://localhost:8080> | Web-Konsole direkt |
| <http://localhost:8080/version> | laufende Backend-Version |

Beenden: `docker compose down`.

`fetch-release.sh` lädt ausschliesslich Release-Assets herunter (Jar,
Frontend-Archiv, dazu ttyd mit geprüfter Prüfsumme) und legt sie unter
`ops/local/.runtime/` ab. Fehlt ein Asset im Release, bricht das Skript ab – es
fällt **nicht** auf einen lokalen Build zurück. Genau das ist der Punkt der
Übung: Betrieben wird das Artefakt, nicht der Quellcode.

## 7. Konfiguration: nichts ist fest verdrahtet

Die URL der Web-Konsole steht **nicht** im Frontend-Code. Sie kommt aus
`config.js`, die vor `app.js` geladen wird:

```js
window.TICTACTEST_CONFIG = {
	consoleUrl: 'http://localhost:8080/',
	versionUrl: 'http://localhost:8080/version'
};
```

| Umgebung | Wer schreibt `config.js`? |
| --- | --- |
| lokal | `fetch-release.sh` (bzw. `cp config.sample.js config.js`) |
| Cloud | **OpenTofu**, direkt in den S3-Bucket – nur die Infrastruktur kennt die Adresse der Instanz |

Deshalb ist `config.js`

* **nicht im Git-Repository** (`.gitignore`), und
* **nicht im Frontend-Archiv** – `package-frontend.sh` entfernt sie und bricht
  ab, falls sie doch hineingeraten sollte.

Damit kann ein Frontend-Deployment die Konfiguration der Infrastruktur nicht
überschreiben. Das Deployment synchronisiert später mit
`aws s3 sync --delete --exclude config.js` (Details in
[deployment.md](deployment.md)).

## 8. Release-Assets

Ein Tag `v*` erzeugt neu vier Assets:

| Asset | Gehört zum Release, weil … |
| --- | --- |
| `tictactest-<v>.jar` | das Artefakt selbst |
| `tictactest-<v>.jar.sha256` | Integritätsprüfung beim Herunterladen |
| `tictactest-frontend-<v>.zip` | siehe unten |
| `tictactest-frontend-<v>.zip.sha256` | dito |

### Warum das Frontend als Release-Asset, obwohl es nur vier Dateien sind?

* **Versionierung.** Ohne Archiv gäbe es keine Frontend-Version – man wüsste
  nicht, welcher Stand ausgeliefert ist. Das Archiv enthält `version.json` mit
  Version, Build-Zeit und Commit.
* **Gleiche Herkunft für alles.** Das Deployment holt Backend *und* Frontend aus
  derselben Quelle: dem Release. Es muss nicht einmal aus GitHub Releases und
  einmal aus dem Git-Baum lesen.
* **Rollback.** `v1.2.0` erneut deployen heisst: genau diese vier Dateien
  wiederherstellen. Ein `git checkout` eines alten Stands wäre nicht dasselbe –
  da müsste man erst wieder verpacken.
* **Unveränderlichkeit.** Ein Release-Asset ändert sich nicht mehr. Der
  Git-Baum kann sich weiterbewegen, das Artefakt nicht.

### Was gehört *nicht* ins Release?

Die **systemd-Unit und die nginx-Konfiguration** gehören zur **Infrastruktur**
(OpenTofu, Auftrag 2), nicht zum Release. Begründung: Sie beschreiben, *wie und
wo* etwas läuft, nicht *was* läuft. Sie ändern sich mit der Instanz, nicht mit
der Applikationsversion – ein Rollback auf `v1.0.0` soll die Unit nicht auf den
damaligen Stand zurückdrehen. Umgekehrt heisst das: Eine Änderung an der Unit
erfordert ein `tofu apply`, kein Release. Diese Grenze ist genau die Trennung,
die Auftrag 2 verlangt.

## 9. Offene Punkte für Auftrag 2 und 3

* Alles läuft über **HTTP**, nicht HTTPS. Im Learner Lab ohne eigene Domain ist
  das der pragmatische Weg. Wäre das Frontend über HTTPS erreichbar, würde der
  Browser den `<iframe>` auf eine HTTP-Konsole als *Mixed Content* blockieren –
  dann bräuchte es ein Zertifikat für die Instanz.
* Es gibt keine Authentifizierung. Wer die URL kennt, kann spielen. Für dieses
  Spiel akzeptabel; ttyd könnte mit `--credential` Basic Auth erzwingen.
* Der Dienst läuft in Auftrag 2 als systemd-Unit, damit er einen Neustart der
  Instanz überlebt.
