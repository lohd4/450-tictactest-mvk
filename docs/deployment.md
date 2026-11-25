# Deployment (Auftrag 2 & 3)

Wie die TicTacTest-Webapp in die Cloud kommt: Infrastruktur mit **Terraform**,
Applikation per **Release-Deployment** aus GitHub Actions. Dieses Dokument
enthält das Secrets-Konzept, den vollständigen Ablauf (manuell und
automatisiert) und die Reflexion inklusive Promotion-Strategie.

Vorgelagert: [docs/webkonsole.md](webkonsole.md) beschreibt die Web-Konsole
selbst (Werkzeugwahl, Sicherheit, Versionsabfrage), [RELEASE.md](../RELEASE.md)
den Release-Prozess, der die Artefakte erzeugt.

---

## 1. Überblick

```
   Git-Tag v1.3.0
        │
        ▼
 ┌─────────────────────┐   release.yaml: testet, baut, veröffentlicht
 │ GitHub Release      │   Assets: tictactest-1.3.0.jar
 │ v1.3.0              │           tictactest-frontend-1.3.0.zip  (+ .sha256)
 └─────────┬───────────┘
           │ deploy.yaml (workflow_call) – deployt NUR das Geänderte
     ┌─────┴──────────────────────────┐
     ▼                                ▼
 Backend                          Frontend
 jar ──► S3 (privat) ──┐          zip ──► S3 Static Website
                       │ SSM
                       ▼
            EC2 ── nginx:80 ── ttyd:7681 ── java -jar
                     │
                     └─ /version  (Plain Text, z. B. "1.3.0")
```

| Baustein | Lebenszyklus | Wer ändert ihn |
| --- | --- | --- |
| EC2-Instanz, Elastic IP, Security Group, S3-Buckets, systemd-Unit, nginx-Config, Java, ttyd | **Infrastruktur** | `terraform apply`, lokal, von Hand |
| Jar, Frontend-Dateien, `/etc/tictactest/version` | **Applikation** | Deployment, automatisch bei einem Release |

### Die zentrale Trennung

> Ein neuer Release erfordert **kein `terraform apply`** und **keine neue
> EC2-Instanz.**

Erreicht wird das dadurch, dass `user_data` **keine Applikationsversion
enthält**. Das Provisioning-Skript richtet nur die Laufzeitumgebung ein; welche
Version läuft, steht in der Datei `/etc/tictactest/version` auf der Instanz. Die
systemd-Unit liest diese Datei bei jedem Start:

```ini
ExecStartPre=/usr/local/bin/tictactest-fetch   # holt das Jar aus S3, falls es fehlt
ExecStart=/usr/local/bin/tictactest-run        # liest /etc/tictactest/version
```

Ein Deployment schreibt also nur eine Datei und startet einen Dienst neu.
Terraform sieht davon nichts – `terraform plan` bleibt nach einem Deployment
leer.

#### Warum nicht das Jar in `user_data` herunterladen?

Das wäre der naheliegende, aber falsche Weg: `user_data` läuft **nur beim ersten
Boot**. Eine neue Version in `user_data` wäre auf einer laufenden Instanz
wirkungslos – die Konfiguration behauptet dann etwas, das die Maschine nicht
tut. Der einzige Weg, das zu „reparieren", wäre
`user_data_replace_on_change = true` plus eine Versionsänderung, und das
**zerstört die Instanz und baut sie neu** bei jedem Release. Genau das verbietet
Auftrag 2.

`user_data_replace_on_change = true` ist in dieser Konfiguration trotzdem
gesetzt – aber aus dem umgekehrten Grund: Wenn sich das *Provisioning* ändert
(neues Paket, neue Unit, neuer nginx-Block), ist ein Ersetzen die ehrliche
Reaktion, weil das Skript sonst nie wieder ausgeführt würde. Das ist
ungefährlich, **weil** die Version nicht in `user_data` steht: Die neue Instanz
liest ihre gewünschte Version aus dem Artefakt-Bucket, kommt auf derselben
Elastic IP hoch – und ein normales Applikations-Deployment berührt `user_data`
nie und ersetzt deshalb auch nie die Instanz.

### Wie das Jar auf die Instanz kommt – und warum über S3

Drei Varianten standen zur Wahl:

| Variante | Bewertung |
| --- | --- |
| Instanz lädt direkt vom GitHub-Release | Einfach, aber: bei einem **privaten Repository** bräuchte die Instanz ein GitHub-Token – ein langlebiges Secret auf einer öffentlich erreichbaren Maschine. Und die Instanz hängt beim Booten an der Erreichbarkeit von GitHub. |
| **Kopie in einen privaten S3-Bucket, Instanz holt es dort ab** ✅ | Die Instanz authentisiert sich mit ihrem **Instance Profile** – es liegen **gar keine Zugangsdaten** auf der Box. Funktioniert unverändert, wenn das Repo privat wird. Nach einem Neustart ist das Artefakt weiterhin erreichbar, auch ohne GitHub. Die Bucket-Versionierung ist eingeschaltet, ein überschriebenes Artefakt bleibt wiederherstellbar. |
| Per SSH hochkopieren | Braucht einen privaten Schlüssel in GitHub Secrets **und** einen offenen Port 22. Zwei Dinge, die wir sonst nicht brauchen. |

**Entscheidung: S3.** Der Preis ist ein zusätzlicher Schritt in der Pipeline
(Release-Asset herunterladen, nach S3 hochladen) und ein weiterer Baustein, der
nach einem `terraform destroy` neu gefüllt werden muss. Dafür gilt: kein Secret
auf der Instanz, kein offener SSH-Port, keine Abhängigkeit von GitHub zur
Laufzeit.

### Warum SSM und nicht SSH für die Befehle auf der Instanz

Das Deployment muss auf der Instanz zwei Dinge tun: die Versionsdatei schreiben
und den Dienst neu starten. Statt sich anzumelden, schickt die Pipeline das per
`aws ssm send-command` mit dem Dokument `AWS-RunShellScript`.

| | SSM | SSH |
| --- | --- | --- |
| Zugangsdaten in GitHub | keine zusätzlichen – die AWS-Credentials sind sowieso da | **zusätzlich** ein privater Schlüssel als Secret |
| Security Group | Port 22 bleibt **zu** | Port 22 muss für die GitHub-Runner offen sein, deren IPs wechseln → praktisch `0.0.0.0/0` |
| Zugriffskontrolle | IAM | Dateirechte auf einem Schlüssel |
| Audit | jeder Befehl in CloudTrail | nur was auf der Instanz geloggt wird |
| Abhängigkeit | der SSM-Agent muss gesund sein | nur sshd |

**Entscheidung: SSM.** Der einzige echte Nachteil ist die Abhängigkeit vom
SSM-Agent: Hängt er, ist die Instanz über die Pipeline nicht erreichbar. Deshalb
bleibt SSH als Notausgang vorgesehen – die Variable `ssh_ingress_cidrs` öffnet
Port 22 für *eine* Adresse, wenn auf der Box selbst etwas debuggt werden muss,
und eine Validierung verweigert `0.0.0.0/0`.

---

## 2. Secrets-Konzept

> Zugangsdaten gehören **weder ins Repository noch in Workflow-Dateien noch in
> Log-Ausgaben.** Dieser Abschnitt ist absichtlich vor dem Workflow entstanden.

### 2.1 Welche Zugangsdaten braucht die Pipeline?

| Zugangsdaten | Woher | Gültigkeit | Wofür |
| --- | --- | --- | --- |
| `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN` | AWS Academy Learner Lab → *AWS Details* → *AWS CLI* | **temporär**, nur für die laufende Lab-Session (einige Stunden) | S3-Upload, `ssm send-command`, S3-Sync |
| `GITHUB_TOKEN` | von GitHub Actions automatisch pro Job erzeugt | Dauer des Jobs | Release anlegen (`release.yaml`), fürs Deployment nicht nötig |

Die Release-Assets werden mit `curl` **ohne Token** geladen – das Repository ist
öffentlich. Würde es privat, bräuchten `deploy-backend.sh` und
`deploy-frontend.sh` zusätzlich `GH_TOKEN` (bzw. `gh release download`); eine
Zeile im Skript, aber ein weiteres Secret.

Beachte: Die Instanz selbst braucht **keine** Zugangsdaten. Sie greift über das
`LabInstanceProfile` auf S3 zu. Ein kompromittierter Webserver gibt deshalb
keine Keys her.

### 2.2 GitHub Secrets vs. Variables

| | **Secrets** | **Variables** |
| --- | --- | --- |
| Gespeichert | verschlüsselt | Klartext |
| Lesbar in der UI | **nein**, nur überschreibbar | ja |
| In Logs | von GitHub automatisch maskiert (`***`) | erscheinen im Klartext |
| Gedacht für | alles, was Zugriff **gewährt** | Konfiguration, die nur *beschreibt* |

Konkret in diesem Repo:

| Name | Typ | Wert | Begründung |
| --- | --- | --- | --- |
| `AWS_ACCESS_KEY_ID` | Secret | aus dem Learner Lab | Teil eines Credential-Paars. Allein harmlos, gemeinsam mit dem Secret Key aber der Schlüssel zum Konto – es gibt keinen Grund, ihn offen hinzulegen. |
| `AWS_SECRET_ACCESS_KEY` | Secret | aus dem Learner Lab | gewährt Zugriff |
| `AWS_SESSION_TOKEN` | Secret | aus dem Learner Lab | gewährt Zugriff |
| `AWS_REGION` | Variable | `us-east-1` | öffentlich, keine Geheimnis-Eigenschaft |
| `INSTANCE_ID` | Variable | `i-0abc…` | Identifier. Nützt ohne Credentials niemandem. |
| `ARTIFACTS_BUCKET` | Variable | `tictactest-artifacts-…` | der Bucket ist privat; der Name allein öffnet ihn nicht |
| `FRONTEND_BUCKET` | Variable | `tictactest-frontend-…` | der Bucket ist sowieso eine öffentliche Website |
| `VERSION_URL` | Variable | `http://<EIP>/version` | öffentlich erreichbar |
| `PLAY_URL` | Variable | `http://<bucket>.s3-website-us-east-1.amazonaws.com` | steht im README |

Die Variables sind genau die Terraform-Outputs. Der Output `github_variables`
liefert sie als einen Block, `ops/sync-github-env.sh` schreibt sie direkt nach
GitHub – siehe [Abschnitt 3](#3-infrastruktur-aufbauen).

**Security by obscurity wäre hier falsch:** Dass `INSTANCE_ID` und
`ARTIFACTS_BUCKET` Variables sind, ist keine Nachlässigkeit. Ein Identifier ist
keine Berechtigung. Hinge die Sicherheit daran, dass niemand den Bucket-Namen
kennt, wäre der Bucket falsch konfiguriert – er ist mit
`aws_s3_bucket_public_access_block` vollständig dicht, und nur das Instance
Profile darf hinein.

### 2.3 Abgelaufene Learner-Lab-Credentials

Das ist **der** wiederkehrende Stolperstein: Nach jeder Lab-Session sind die
Credentials ungültig.

**Woran man es erkennt.** Der Deploy-Job wird rot, und zwar beim ersten
AWS-Aufruf, mit einer dieser Meldungen:

```
An error occurred (ExpiredToken) when calling the PutObject operation:
    The provided token has expired.
An error occurred (InvalidClientTokenId) when calling the GetCallerIdentity
    operation: The security token included in the request is invalid.
```

**Was dabei passiert – und was nicht.** Das Release ist davon **nicht**
betroffen: `release.yaml` testet, baut und veröffentlicht die Assets, ohne AWS
anzufassen. Tag, Release und Artefakte existieren danach also korrekt; nur die
laufende Umgebung ist noch die alte. Weil das Deployment ganz am ersten
AWS-Aufruf scheitert, gibt es auch **keinen halben Zustand**: Es wurde kein Jar
hochgeladen, keine Versionsdatei geschrieben, nichts neu gestartet. Die alte
Version läuft unverändert weiter.

**Nachdeployen:**

```bash
# 1. Neue Credentials aus dem Learner Lab (AWS Details → AWS CLI) holen und setzen.
#    Niemals in eine Datei im Repo schreiben, niemals committen.
gh secret set AWS_ACCESS_KEY_ID
gh secret set AWS_SECRET_ACCESS_KEY
gh secret set AWS_SESSION_TOKEN
#    (gh fragt den Wert interaktiv ab; er landet nicht in der Shell-History)

# 2. Prüfen, dass die Instanz überhaupt wieder läuft – die Lab-Session hat sie gestoppt
aws ec2 describe-instances --instance-ids "$INSTANCE_ID" \
	--query 'Reservations[].Instances[].State.Name' --output text

# 3. Dasselbe Release gezielt erneut deployen – idempotent, beliebig wiederholbar
gh workflow run deploy.yaml -f version=1.3.0
```

Schritt 3 ist exakt der Rollback-Pfad aus
[Abschnitt 6](#6-gezielt-eine-version-deployen-teil-5). Es gibt bewusst **nur
einen** Deployment-Weg; der manuelle Knopf ist derselbe Workflow, den das
Release aufruft.

> **Stolperfalle vermieden:** Nach einer neuen Lab-Session ändert sich die
> **Instance-ID nicht** (die Instanz wird gestoppt, nicht gelöscht), und die
> öffentliche Adresse bleibt dank Elastic IP gleich. Es müssen also **nur die
> drei Secrets** erneuert werden, keine Variables. Das ist der ganze Grund,
> warum die Elastic IP in der Konfiguration steht.

### 2.4 Wer kann die Secrets sehen oder benutzen?

* **Sehen:** niemand. Auch Repo-Admins können einen gesetzten Secret-Wert nicht
  wieder auslesen, nur überschreiben.
* **Benutzen:** jeder Workflow in diesem Repository, der sie referenziert – und
  damit jeder, der Workflow-Dateien auf `main` ändern oder einen Tag pushen
  darf. Schreibrechte aufs Repository sind in der Praxis gleichbedeutend mit
  Zugriff auf die Secrets.
* **Logs:** GitHub maskiert bekannte Secret-Werte automatisch als `***`. Das
  schützt aber nur den **exakten** Wert: `echo "$AWS_SECRET_ACCESS_KEY" | base64`
  würde ungehindert durchgehen. Deshalb gibt kein Skript Credentials aus, und
  `set -x` steht nirgends in den Deploy-Skripten (`set -euo pipefail`, ohne
  `x`). Das `set -euxo pipefail` im SSM-Kommando läuft **auf der Instanz** und
  verarbeitet nur die Versionsnummer. Nach jedem Lauf werden die Logs
  kontrolliert.
* **Forks und Pull Requests:** Ein `pull_request`-Lauf aus einem Fork bekommt
  von GitHub **keine** Secrets – sonst könnte jeder per PR die Credentials
  abgreifen. Zusätzlich hat `deploy.yaml` überhaupt keinen `pull_request`- und
  keinen `push`-Trigger: nur `workflow_call` (aus `release.yaml`) und
  `workflow_dispatch` (manuell). Ein PR kann also nicht deployen, auch nicht
  versehentlich. `secrets: inherit` in `release.yaml` gibt die Secrets nur an
  einen Workflow **im selben Repository** weiter.

### 2.5 Schaden bei einem Leak – und die Reaktion

**Schaden.** Wer die drei Werte hat, kann bis zum Ablauf der Session alles tun,
was die Lab-Rolle darf: Instanzen starten (Kostenschaden, z. B. Mining), die
Buckets lesen und löschen, die EC2-Instanz terminieren. Die Artefakte selbst
sind nicht geheim (sie liegen öffentlich im Release), aber die Umgebung ist weg
und das Lab-Budget potenziell aufgebraucht. Begrenzt wird der Schaden durch drei
Dinge: die kurze Lebensdauer der Credentials, die Guardrails des Learner Lab
(keine IAM-Änderungen, begrenzte Instanztypen) und das Budgetlimit.

**Reaktion, in dieser Reihenfolge:**

1. **Session im Learner Lab beenden** („End Lab") – das invalidiert die
   Credentials sofort; das ist hier das Äquivalent zum Rotieren eines Keys.
2. Neue Session starten, neue Credentials, `gh secret set` (siehe 2.3).
3. **CloudTrail** auf fremde Aufrufe prüfen, `aws ec2 describe-instances` und
   `aws s3 ls` auf unerwartete Ressourcen, Billing ansehen.
4. Die undichte Stelle schliessen (Log-Ausgabe, versehentlicher Commit,
   Screenshot in der Abgabe).
5. Falls die Werte **committet** wurden: Sie gelten dauerhaft als geleakt, auch
   nach einem `git revert`. History umschreiben hilft bei GitHub nur begrenzt –
   der alte Commit bleibt über die API erreichbar. Rotieren ist die einzige
   wirksame Maßnahme, und genau deshalb steht sie an Punkt 1.

### 2.6 Wie man es ohne Learner-Lab-Einschränkungen löst: OIDC

In einem echten Unternehmen würden **keine AWS-Credentials in GitHub liegen.**
Stattdessen GitHub Actions als **OIDC-Identitätsanbieter**:

```
GitHub Actions Job
   │  erhält von GitHub ein kurzlebiges, signiertes OIDC-Token
   │  (Claims: repository, ref, environment, workflow …)
   ▼
AWS STS  AssumeRoleWithWebIdentity
   │  prüft die Signatur gegen den IAM OIDC Provider
   │  prüft die Trust Policy der Rolle gegen die Claims
   ▼
temporäre Credentials, ~1 Stunde, nur für diesen Job
```

```yaml
permissions:
  id-token: write          # erlaubt dem Job, ein OIDC-Token anzufordern
  contents: read
steps:
  - uses: aws-actions/configure-aws-credentials@v4
    with:
      role-to-assume: arn:aws:iam::123456789012:role/tictactest-deploy
      aws-region: us-east-1
```

Die Trust Policy der Rolle schränkt ein, **wer** sie annehmen darf – bis auf die
Ebene „nur dieses Repo, nur aus einem Tag `v*`":

```json
"Condition": {
  "StringEquals": { "token.actions.githubusercontent.com:aud": "sts.amazonaws.com" },
  "StringLike":   { "token.actions.githubusercontent.com:sub": "repo:lohd4/450-tictactest-mvk:ref:refs/tags/v*" }
}
```

Vorteile: kein langlebiges Secret, nichts, was ablaufen und nachgepflegt werden
muss, feingranulare Berechtigungen pro Umgebung (eine Rolle für staging, eine
für prod), und ein Leak ist praktisch wertlos, weil das Token an Repo, Ref und
Laufzeit gebunden ist.

**Warum hier nicht?** Das Learner Lab erlaubt keine eigenen IAM-Rollen,
-Policies und -Identity-Provider. Deshalb bleibt es bei den temporären
Session-Credentials als Secrets – mit dem Nachpflegen aus 2.3 als bewusst
akzeptiertem Preis.

---

## 3. Infrastruktur aufbauen

Einmalig, lokal, von Hand. **Nicht** aus der Pipeline – ein Deployment darf die
Infrastruktur nie anfassen.

```bash
cd infra
cp terraform.tfvars.example terraform.tfvars   # terraform.tfvars ist gitignored
terraform init
terraform plan
terraform apply
```

Danach die Outputs ansehen:

```bash
terraform output
terraform output -raw play_url
terraform output -json github_variables
```

| Output | Vertraulich? |
| --- | --- |
| `play_url`, `console_url`, `version_url`, `public_ip` | nein – öffentliche Adressen, sie stehen im README bzw. im Browser |
| `frontend_bucket` | nein – öffentliche Website |
| `artifacts_bucket`, `instance_id`, `aws_region` | nein – Identifier ohne Berechtigung (siehe 2.2) |
| **nicht als Output vorhanden:** AWS-Credentials, Session-Token, der State | **ja, vertraulich** – der State bleibt lokal und gitignored, Credentials tauchen nirgends auf |

Die Werte in GitHub eintragen (Variables, keine Secrets):

```bash
ops/sync-github-env.sh            # liest die Terraform-Outputs, setzt die Variables,
                                  # aktualisiert den Link im README
ops/sync-github-env.sh --dry-run  # nur anzeigen, nichts ändern
```

> Nach einem `terraform destroy` + `terraform apply` sind **Bucket-Namen,
> Instance-ID und Elastic IP neu**. Dann muss dieses Skript erneut laufen –
> das ist die Antwort auf „welche Werte in GitHub müssen Sie anpassen?"
> (Auftrag 3, Teil 5). Die drei AWS-Secrets bleiben davon unberührt.

---

## 4. Manuelles Deployment (Auftrag 2, Teil 3)

Diese Schritte sind die Vorlage für die Pipeline – sie macht exakt dasselbe. Als
Vorbereitung: Credentials der laufenden Lab-Session im Terminal exportieren und
die Outputs in Shell-Variablen holen.

```bash
cd infra
export AWS_REGION=$(terraform output -raw aws_region)
export INSTANCE_ID=$(terraform output -raw instance_id)
export ARTIFACTS_BUCKET=$(terraform output -raw artifacts_bucket)
export FRONTEND_BUCKET=$(terraform output -raw frontend_bucket)
export VERSION_URL=$(terraform output -raw version_url)
export PLAY_URL=$(terraform output -raw play_url)
cd ..
VERSION=1.0.0
BASE="https://github.com/lohd4/450-tictactest-mvk/releases/download/v$VERSION"
```

### 4.1 Backend: Jar aus dem Release auf die Instanz

```bash
# 1. Artefakt AUS DEM RELEASE holen – nichts wird gebaut
curl -fsSLO "$BASE/tictactest-$VERSION.jar"
curl -fsSLO "$BASE/tictactest-$VERSION.jar.sha256"
sha256sum -c "tictactest-$VERSION.jar.sha256"

# 2. In den privaten Artefakt-Bucket legen
aws s3 cp "tictactest-$VERSION.jar" \
	"s3://$ARTIFACTS_BUCKET/backend/tictactest-$VERSION.jar" --region "$AWS_REGION"
aws s3 cp "tictactest-$VERSION.jar.sha256" \
	"s3://$ARTIFACTS_BUCKET/backend/tictactest-$VERSION.jar.sha256" --region "$AWS_REGION"

# 3. Der Instanz sagen, welche Version sie fahren soll, und den Dienst neu starten.
#    Über SSM, ohne SSH-Login.
CMD_ID=$(aws ssm send-command \
	--region "$AWS_REGION" \
	--instance-ids "$INSTANCE_ID" \
	--document-name AWS-RunShellScript \
	--comment "deploy tictactest $VERSION" \
	--parameters "commands=[
		'set -euxo pipefail',
		'printf \"%s\\n\" \"$VERSION\" > /etc/tictactest/version',
		'/usr/local/bin/tictactest-fetch',
		'systemctl restart tictactest.service',
		'systemctl is-active tictactest.service'
	]" \
	--query 'Command.CommandId' --output text)

aws ssm wait command-executed --region "$AWS_REGION" \
	--command-id "$CMD_ID" --instance-id "$INSTANCE_ID"

aws ssm get-command-invocation --region "$AWS_REGION" \
	--command-id "$CMD_ID" --instance-id "$INSTANCE_ID" \
	--query '{Status:Status,Stdout:StandardOutputContent}' --output text

# 4. Prüfen, was WIRKLICH läuft – ein grünes SSM-Kommando beweist das nicht
curl -fsS "$VERSION_URL"     # → 1.0.0
```

### 4.2 Frontend: Archiv aus dem Release in den Website-Bucket

```bash
curl -fsSLO "$BASE/tictactest-frontend-$VERSION.zip"
rm -rf site && mkdir site && unzip -q "tictactest-frontend-$VERSION.zip" -d site

# config.js gehört der Infrastruktur und darf nicht im Archiv sein
[ -f site/config.js ] && { echo "FEHLER: config.js im Archiv"; exit 1; }

# --delete entfernt Dateien, die es im Release nicht mehr gibt
# --exclude config.js schützt die Konfiguration aus der Infrastruktur
aws s3 sync site/ "s3://$FRONTEND_BUCKET/" --region "$AWS_REGION" \
	--delete --exclude 'config.js'

# version.json darf nicht gecacht werden, sonst zeigt der Browser die alte Version
aws s3 cp site/version.json "s3://$FRONTEND_BUCKET/version.json" \
	--region "$AWS_REGION" --cache-control no-store --content-type application/json

# Prüfen
curl -fsS "$PLAY_URL/version.json"
curl -fsS "$PLAY_URL/config.js" | grep TICTACTEST_CONFIG   # muss noch da sein
```

### 4.3 Im Browser spielen

`$PLAY_URL` öffnen. Im Fuss der Seite stehen beide Versionen: Frontend (aus
`version.json`) und Backend (aus `/version` der Instanz). Beide müssen `1.0.0`
zeigen.

### 4.4 Release B deployen – ohne `terraform apply`

Neuen Release erstellen (sichtbare Frontend-Änderung + neue Versionsnummer,
Ablauf in [RELEASE.md](../RELEASE.md)), dann **genau dieselben Befehle** wie
oben mit `VERSION=1.1.0`. Danach der Beweis, dass die Infrastruktur unberührt
ist:

```bash
cd infra && terraform plan
# → "No changes. Your infrastructure matches the configuration."
```

Das ist der Kern von Auftrag 2: zwei Deployments, eine Instanz, kein
`terraform apply` dazwischen.

### 4.5 Protokoll der manuellen Deployments

Auszufüllen beim Durchführen in einer laufenden Lab-Session:

| Schritt | Erwartet | Beobachtet |
| --- | --- | --- |
| `terraform apply` | Instanz, EIP, 2 Buckets, `config.js` im Bucket | |
| Release A deployt | `/version` → A, Frontend zeigt A | |
| Partie im Browser | spielbar, GreedyPlayer antwortet | |
| Release B deployt | `/version` → B, Frontend zeigt B | |
| `terraform plan` danach | *No changes* | |
| Instance-ID vorher/nachher | identisch | |

---

## 5. Automatisches Deployment bei einem Release (Auftrag 3)

### 5.1 Was deployt wann

`release.yaml` ruft nach dem Veröffentlichen `deploy.yaml` per `workflow_call`
auf. `deploy.yaml` hat **keinen `push`-Trigger** – ein Push auf `main` deployt
nichts.

> **Warum `workflow_call` und nicht `on: release`?** Ereignisse, die mit dem
> `GITHUB_TOKEN` ausgelöst werden, starten keine weiteren Workflows. Ein von
> `release.yaml` erzeugtes Release würde einen `release:`-Trigger also nie
> feuern. `workflow_call` ist ausserdem ehrlicher: Der Tag deployt genau die
> Artefakte, die er gerade veröffentlicht hat.

Zwei Deployments dürfen sich nicht überholen:

```yaml
concurrency:
  group: deploy-production
  cancel-in-progress: false   # warten, nicht abbrechen
```

`cancel-in-progress: false` ist Absicht: Ein abgebrochenes Deployment könnte das
Jar hochgeladen, aber den Dienst nicht neu gestartet haben. Ein halbfertiges
Deployment ist schlimmer als ein spätes.

### 5.2 Änderungserkennung (Teil 2)

`.github/scripts/detect-changes.sh` entscheidet, welche Hälften deployt werden.

**Pfad-Zuordnung:**

| Pfad | Backend | Frontend | Begründung |
| --- | --- | --- | --- |
| `frontend/*` | – | ✅ | das Frontend selbst |
| `.github/scripts/package-frontend.sh` | – | ✅ | bestimmt, wie das Archiv entsteht |
| `src/main/*` | ✅ | – | landet im Jar |
| `build.gradle`, `settings.gradle`, `gradle.properties`, `gradlew*`, `gradle/*` | ✅ | – | bestimmt, was im Jar landet (Toolchain, Manifest, Version) |
| `.github/workflows/release.yaml` | ✅ | ✅ | erzeugt **beide** Artefakte, kann beide verändern |
| `src/test/*` | – | – | ein reiner Testunterschied erzeugt ein byte-identisches Jar |
| `doc/*`, `docs/*`, `*.md` | – | – | ändert kein Artefakt |
| `infra/*` | – | – | Infrastruktur wird mit `terraform apply` ausgerollt, bewusst nicht von hier |
| `ops/*` | – | – | lokale Hilfsmittel und das Env-Sync-Skript |
| `.devcontainer/*`, `.vscode/*`, Dotfiles | – | – | Entwicklungsumgebung |
| **alles andere** | ✅ | ✅ | unbekannter Pfad → im Zweifel beides deployen, statt still etwas zu überspringen |

Die Grenzfälle, die der Auftrag anspricht:

* **`build.gradle` → Backend.** Es entscheidet über den Inhalt des Jars
  (Toolchain, Manifest, Version). Dass es auch Testaufgaben definiert, ändert
  daran nichts.
* **Betriebsdateien (systemd-Unit, nginx-Config) → gar nichts.** Sie liegen in
  `infra/` und beschreiben, *wie und wo* etwas läuft, nicht *was*. Ein Rollback
  auf `v1.0.0` soll die Unit nicht mitzurückdrehen. Eine Änderung daran braucht
  ein `terraform apply`, keinen Release.
* **Workflow-Dateien → unterschiedlich.** `release.yaml` baut die Artefakte und
  zählt deshalb für beide Hälften. `deploy.yaml` und die Deploy-Skripte ändern
  nur, *wie* deployt wird, und erzeugen kein neues Artefakt – sie lösen kein
  Deployment aus.
* **Der Default ist „beides".** Ein nicht zugeordneter Pfad deployt
  vorsichtshalber alles. Lieber ein unnötiges Deployment als eine Änderung, die
  nie ankommt.

**Verglichen wird mit dem vorherigen Release-Tag, nicht mit dem letzten Commit:**

```bash
previous_tag=$(git tag --list 'v*' --sort=version:refname \
	| awk -v current="$tag" '$0 == current { found = 1; exit } { prev = $0 } END { if (found) print prev }')
git diff --name-only "$previous_tag".."$tag"
```

Begründung: Deployt wird ein **Release**, also kann „hat sich das Backend
geändert?" nur „seit dem letzten Release" heissen. Ein Vergleich mit dem
vorherigen Commit würde alles übersehen, was zwischen zwei Releases auf `main`
gelandet ist – ein Release, der zehn Commits bündelt, würde dann fast nichts
deployen.

Das `awk` nimmt bewusst den Tag **unmittelbar vor diesem** in
Versions-Reihenfolge, nicht „den neuesten, der nicht dieser ist". Sonst würde
ein gezieltes Re-Deployment von `v1.2.0` gegen `v1.3.0` vergleichen und das
Ergebnis umdrehen.

**Allererster Release:** Es gibt keinen vorherigen Tag, also ist alles neu –
beide Hälften werden deployt. Dasselbe gilt sinngemäss für ein manuelles
Deployment: Dort ist die Aussage „stelle diese Version her", der Zustand der
Umgebung ist unbekannt, also werden immer beide Hälften deployt.

**Warum der `paths:`-Filter von GitHub Actions das nicht kann:** Drei Gründe.
Erstens wertet der Filter nur die Commits des auslösenden **Push**-Events aus –
ein Tag-Push enthält keine Commits, GitHub meldet keine geänderten Dateien, der
Filter würde also nie feuern. Zweitens kann `paths:` grundsätzlich nur „diese
Dateien in diesem Push" ausdrücken, nicht „Unterschied zwischen zwei Tags".
Drittens, praktisch: `deploy.yaml` wird über `workflow_call` gestartet, und dort
gibt es `paths:` gar nicht.

### 5.3 Backend-Deployment (Teil 3)

`.github/scripts/deploy-backend.sh`, aufgerufen vom Job `backend`, wenn
`needs.plan.outputs.backend == 'true'`:

1. Jar (und `.sha256`) **aus dem Release** herunterladen – nichts wird gebaut.
2. Nach `s3://$ARTIFACTS_BUCKET/backend/` hochladen.
3. Per SSM `/etc/tictactest/version` schreiben, `tictactest-fetch` laufen
   lassen, Dienst neu starten.
4. **Verifizieren:** bis zu 120 s auf `$VERSION_URL` pollen. Meldet der
   Endpunkt nicht genau die neue Version, schlägt der Workflow fehl:

```
::error::after 120s http://<eip>/version reports '1.2.0', expected '1.3.0'
```

Dass das SSM-Kommando grün war, beweist nur, dass die Befehle liefen – nicht,
dass die richtige Version Traffic bedient. Die Versionsabfrage ist die echte
Prüfung.

#### Was passiert mit Spielenden während des Neustarts?

`systemctl restart` beendet ttyd. Alle WebSocket-Verbindungen brechen ab, die
JVMs der laufenden Partien werden mitgetötet, und im Browser steht ein totes
Terminal – ein Reload startet ein neues Spiel auf der neuen Version. Da jede
Partie nur im Prozess existiert, ist kein Zustand zu retten; sichtbar ist der
Ausfall rund 2–5 Sekunden.

Wie man es vermeiden könnte (**nur beschrieben, nicht umgesetzt**):

* **Der günstigste Weg:** ttyd nicht fix auf ein Jar zeigen lassen, sondern auf
  ein Wrapper-Skript, das die Version **beim Verbindungsaufbau** aus
  `/etc/tictactest/version` liest. Dann braucht ein Deployment **gar keinen
  Neustart**: Neue Verbindungen starten die neue Version, laufende Partien
  spielen ihre alte zu Ende. Der Preis: Es laufen kurzzeitig zwei Versionen
  gleichzeitig, und der Versionsendpunkt kann nur noch die *gewünschte* Version
  melden – die Prüfung der Pipeline würde dadurch schwächer.
* **Blue/Green mit Connection Draining:** zweite ttyd-Instanz auf einem anderen
  Port mit dem neuen Jar starten, nginx-Upstream für neue Verbindungen
  umschalten, die alte Instanz leerlaufen lassen, dann stoppen. Saubere Lösung,
  aber zwei Dienste und doppelter Speicherbedarf – auf 1 GiB RAM spürbar.
* **Zwei Instanzen hinter einem Load Balancer**, rollierend deployt. Im Learner
  Lab mit einem t3.micro überdimensioniert.
* **Ehrliche Vorwarnung:** ein Wartungshinweis im Frontend, während ein
  Deployment läuft. Löst das Problem nicht, macht es aber erklärbar.

#### Woher weiss die Instanz nach einem Neustart, welche Version sie starten soll?

Aus `/etc/tictactest/version` auf dem EBS-Root-Volume – geschrieben vom
Deployment, nicht von Terraform. Beim Booten gilt:

1. `systemctl enable tictactest.service` (im Provisioning gesetzt) startet den
   Dienst automatisch.
2. `ExecStartPre=/usr/local/bin/tictactest-fetch` liest die Versionsdatei und
   holt das Jar aus dem Artefakt-Bucket, falls es lokal fehlt (Instanz ersetzt,
   Volume neu) – über das Instance Profile, ohne Credentials.
3. `ExecStart=/usr/local/bin/tictactest-run` liest dieselbe Datei, schreibt
   `version.txt` für den `/version`-Endpunkt und startet
   `ttyd … java -jar tictactest-<version>.jar`.

Dass `version.txt` **vom Launcher** geschrieben wird und nicht vom Deployment,
ist Absicht: So kann der Endpunkt nie etwas anderes behaupten als das Jar, das
tatsächlich gestartet wurde.

### 5.4 Frontend-Deployment (Teil 4)

`.github/scripts/deploy-frontend.sh`:

1. Frontend-Archiv aus dem Release laden und entpacken.
2. `aws s3 sync --delete --exclude config.js` – `--delete` entfernt Dateien, die
   es im neuen Release nicht mehr gibt.
3. `version.json` nochmals mit `--cache-control no-store` hochladen.
4. **Verifizieren:** `$PLAY_URL/version.json` muss die neue Version melden, und
   `$PLAY_URL/config.js` muss weiterhin `TICTACTEST_CONFIG` enthalten.

#### Was, wenn das Frontend-Deployment die Konfiguration löscht?

Dann steht in `config.js` nichts mehr (oder sie fehlt ganz) und die Seite ist
funktionslos: Der `<iframe>` bekommt keine `src`, das Terminal bleibt leer, die
Fehlerbox zeigt „Keine Konsolen-URL konfiguriert", und die Backend-Version
erscheint als „nicht konfiguriert". Die Instanz läuft dabei einwandfrei weiter –
sie ist nur für Besucher nicht mehr erreichbar, und zwar bis jemand
`terraform apply` erneut ausführt.

Genau deshalb **vier** voneinander unabhängige Absicherungen:

| Schicht | Wo | Was sie tut |
| --- | --- | --- |
| 1 | `.gitignore` | `config.js` ist nicht im Repository |
| 2 | `package-frontend.sh` | entfernt `config.js` aus dem Staging und **bricht ab**, falls sie im fertigen Archiv auftaucht |
| 3 | `deploy-frontend.sh` | verweigert das Deployment, wenn das Archiv `config.js` enthält – zweite Verteidigungslinie genau dort, wo Schaden entstehen würde |
| 4 | `aws s3 sync --exclude config.js` | der Ausschluss gilt für **beide** Seiten des Syncs: die Datei wird weder hochgeladen noch gelöscht |

Und danach die Kontrolle (Schicht 5): Der Workflow holt `config.js` über HTTP
und schlägt fehl, wenn `TICTACTEST_CONFIG` fehlt.

Geschrieben wird `config.js` von Terraform selbst
(`aws_s3_object.frontend_config`), weil **nur die Infrastruktur die Adresse der
Instanz kennt**:

```js
window.TICTACTEST_CONFIG = {
	consoleUrl: 'http://<Elastic IP>/',
	versionUrl: 'http://<Elastic IP>/version'
};
```

In diesen öffentlichen Bucket darf deshalb **nie** etwas anderes als die
statische Seite und diese Konfiguration: keine Credentials, keine `.env`, kein
Terraform-State, keine internen Adressen. Alles hier ist für jeden im Internet
lesbar.

---

## 6. Gezielt eine Version deployen (Teil 5)

```bash
gh workflow run deploy.yaml -f version=1.2.0
# oder: GitHub → Actions → Deploy → Run workflow
```

Ein manuelles Deployment deployt **immer beide Hälften**. Begründung: Es sagt
„stelle diesen Zustand her". Welche Hälfte bereits passt, ist nicht bekannt
(vielleicht wurde nach einem `terraform destroy` gerade neu aufgebaut), also
wird nichts übersprungen.

Damit sind drei Fälle abgedeckt:

| Fall | Befehl |
| --- | --- |
| **Rollback** auf eine ältere Version | `gh workflow run deploy.yaml -f version=1.2.0` |
| **Nachdeployen** nach abgelaufenen Credentials | Secrets erneuern (2.3), dann derselbe Befehl |
| **Wiederaufbau** nach `terraform destroy` + `apply` | `ops/sync-github-env.sh`, dann derselbe Befehl |

### Testprotokoll

| Test | Erwartet | Beobachtet |
| --- | --- | --- |
| Rollback: v1.3.0 läuft → `deploy.yaml -f version=1.2.0` | Frontend **und** `/version` zeigen 1.2.0 | |
| Kaputter Release (Jar startet nicht) | SSM-Schritt oder Versionsprüfung schlägt fehl, Workflow rot, spätestens nach 120 s | |
| Zeit bis wieder eine funktionierende Version läuft | ein Dispatch der letzten guten Version: ca. 1–2 min | |
| `terraform destroy` + `apply`, dann Sync + Dispatch | Umgebung wieder auf der aktuellen Version | |

**Zum kaputten Release:** Wichtig ist, *wo* er auffällt. Startet das Jar nicht,
bleibt `systemctl is-active` rot und das SSM-Kommando scheitert; selbst wenn der
Dienst scheinbar läuft, meldet `/version` nie die neue Version und die
Verifikation läuft in den Timeout. Der Workflow wird in beiden Fällen rot. Was
die Pipeline **nicht** verhindert: dass die Instanz in dieser Zeit kaputt ist –
`/etc/tictactest/version` zeigt schon auf die neue Version. Die
Wiederherstellung ist ein Dispatch der letzten funktionierenden Version. Ein
automatischer Rollback wäre der nächste Ausbauschritt: bei fehlgeschlagener
Prüfung die vorherige Version zurückschreiben, statt sie von Hand anzustossen.

---

## 7. Robustheit (Auftrag 2, Teil 4)

### 7.1 Lab-Session beenden und neu starten

Das Learner Lab **stoppt** die Instanz, löscht sie aber nicht. Erwartet:

| Frage | Erwartung | Warum |
| --- | --- | --- |
| Läuft die App wieder von selbst? | ja | `systemctl enable tictactest.service` + nginx `enable`; `ExecStartPre` holt das Jar notfalls neu |
| Ist die URL gleich geblieben? | ja | **Elastic IP** – ohne sie bekäme die Instanz eine neue öffentliche IP, und `config.js` im Bucket wäre falsch, bis jemand `terraform apply` laufen lässt |
| Läuft dieselbe Version? | ja | `/etc/tictactest/version` liegt auf dem Root-Volume und wird beim Start gelesen |
| Muss in GitHub etwas angepasst werden? | nur die 3 AWS-**Secrets** | Instance-ID, Buckets und EIP sind unverändert |

| Beobachtet | |
| --- | --- |
| Instanz startet automatisch | |
| `curl $VERSION_URL` nach dem Start | |
| `$PLAY_URL` spielbar | |

### 7.2 Etwas am Provisioning ändern (z. B. neue Umgebungsvariable für den Dienst)

Erwartung: `terraform plan` zeigt eine Änderung an `user_data` und **damit
`replace` für `aws_instance.console`** (`user_data_replace_on_change = true`).
Konkret:

* Die **Instanz wird ersetzt** → neue Instance-ID.
* Die **Elastic IP bleibt** – sie ist eine eigene Ressource und wird nur neu
  zugeordnet (`aws_eip_association`). Die URL in `config.js` bleibt gültig.
* Die **laufende Version** kommt nicht von selbst zurück: Die neue Instanz hat
  eine leere `/etc/tictactest/version` und startet zunächst nichts. **Hier ist
  Handarbeit nötig** – entweder `initial_version` setzen, oder nach dem Apply
  ein Dispatch von `deploy.yaml`. Das ist der dokumentierte Preis dafür, dass
  Provisioning-Änderungen nicht stillschweigend ignoriert werden.
* **`INSTANCE_ID` in den GitHub Variables muss neu gesetzt werden** →
  `ops/sync-github-env.sh`.

| Beobachtet | |
| --- | --- |
| `terraform plan`-Ausgabe (replace?) | |
| Instance-ID vorher / nachher | |
| EIP vorher / nachher | |
| Version nach dem Apply | |

### 7.3 `terraform destroy` und wieder `terraform apply`

| Wert | Ändert sich? |
| --- | --- |
| Instance-ID | **ja** |
| Elastic IP / `public_ip` | **ja** – eine freigegebene EIP ist nicht reservierbar |
| Bucket-Namen (`bucket_prefix`) | **ja** – S3-Namen sind global eindeutig, deshalb kein fester Name |
| `play_url`, `console_url`, `version_url` | **ja** (sie enthalten die obigen Werte) |
| Inhalt des Artefakt-Buckets | **weg** (`force_destroy = true`) |

Bis wieder dieselbe Version läuft:

```bash
cd infra && terraform apply
cd .. && ops/sync-github-env.sh         # neue Outputs → GitHub Variables + README
gh workflow run deploy.yaml -f version=<aktuelle Version>
```

Ein `destroy` ist also **kein** Datenverlust im eigentlichen Sinn: Alles
Notwendige liegt im GitHub-Release und wird von dort wiederhergestellt. Das ist
der praktische Nutzen davon, das Artefakt als Release zu führen und nicht nur
auf der Instanz.

| Beobachtet | |
| --- | --- |
| Neue EIP / neue Bucket-Namen | |
| Zeit bis wieder spielbar | |

---

## 8. Nachweis der Trennung (Auftrag 3, Teil 6)

Vier Fälle, nacheinander. Jeweils der Link zum Workflow-Lauf und das Ergebnis:

| # | Release | Erwartung | Workflow-Lauf | Ergebnis |
| --- | --- | --- | --- | --- |
| 1 | nur Frontend (z. B. eine Farbe in `frontend/style.css`) | Job `frontend` läuft, Job `backend` **skipped**. Frontend-Version neu, Backend-Version unverändert. | | |
| 2 | nur Backend (z. B. eigener Player fest in `main()`) | Job `backend` läuft, Job `frontend` **skipped**. Backend-Version neu, Frontend wird nicht angefasst. | | |
| 3 | beides | beide Jobs laufen | | |
| 4 | Push auf `main` **ohne** Tag | **kein** Deploy-Lauf überhaupt – `deploy.yaml` hat keinen `push`-Trigger | | |

Nachprüfbar jeweils auch ohne Workflow-Logs, direkt an der laufenden Umgebung:

```bash
curl -s "$VERSION_URL"              # Backend-Version
curl -s "$PLAY_URL/version.json"    # Frontend-Version
```

Der Job-Zusammenfassung von `deploy.yaml` ist der Plan direkt zu entnehmen:

```
### Deployment plan for `1.4.0`
| Teil | Aktion |
| Backend | unverändert |
| Frontend | wird deployt |
```

**Zu Fall 2:** Der eigene Player aus Modul 450 ist genau der vorgesehene
Kandidat für einen Nur-Backend-Release – er wird in `main()` fest umgeschaltet
(aktuell `play(new HumanPlayer(), new GreedyPlayer())`). Eine Änderung in
`src/main/` ordnet `detect-changes.sh` dem Backend zu, `frontend/` bleibt
unberührt, und der `frontend`-Job wird übersprungen.

---

## 9. Reflexion und Ausblick: Umgebungen und Promotion (Teil 7)

### 9.1 Der Weg einer Änderung

**Backend-Änderung** (z. B. eigener Player in `main()`):

```
Commit auf einem Branch
   │  CI.yaml: Tests, Coverage-Gate, Mutation Testing
   ▼
Pull Request → Review → Merge auf main          ← hier wird noch nichts deployt
   │
   │  CHANGELOG.md "Unreleased" → "1.4.0" pflegen
   ▼
git tag v1.4.0 && git push origin v1.4.0        ← manuell, bewusste Entscheidung
   │
   ▼  release.yaml
Tests ──► ./gradlew jar ──► java -jar … --version ──► GitHub Release v1.4.0
   │                                                  (Jar + Frontend-Zip + Checksums)
   ▼  deploy.yaml (workflow_call)
detect-changes.sh:  v1.3.0..v1.4.0 → src/main/… → backend=true, frontend=false
   │
   ├─ Job frontend: SKIPPED  (läuft unverändert weiter)
   │
   └─ Job backend:
         Jar aus dem Release ──► S3 (privat)
         SSM: /etc/tictactest/version = 1.4.0, fetch, systemctl restart
         Prüfung: curl /version == 1.4.0  (sonst Workflow rot)
   ▼
Spielbar auf $PLAY_URL, Fuss der Seite: Backend 1.4.0, Frontend 1.3.0
```

**Frontend-Änderung** (z. B. eine Farbe):

```
Commit → PR → Merge auf main → git tag v1.5.0
   │
   ▼  release.yaml   (erzeugt beide Artefakte, immer)
GitHub Release v1.5.0
   │
   ▼  deploy.yaml
detect-changes.sh:  v1.4.0..v1.5.0 → frontend/… → backend=false, frontend=true
   │
   ├─ Job backend: SKIPPED  ← die laufende JVM wird nicht angefasst,
   │                           niemandes Partie bricht ab
   │
   └─ Job frontend:
         Zip aus dem Release ──► entpacken ──► s3 sync --delete --exclude config.js
         Prüfung: version.json == 1.5.0  UND  config.js enthält noch TICTACTEST_CONFIG
   ▼
Fuss der Seite: Frontend 1.5.0, Backend 1.4.0
```

Bemerkenswert: Der Release **baut** immer beide Artefakte, deployt aber nur das
Geänderte. Das ist gewollt – so ist für jede Version ein vollständiger Satz
Artefakte abrufbar, und ein gezieltes Deployment dieser Version funktioniert
auch Monate später.

### 9.2 Automatisiert vs. manuell

| Schritt | Status | Warum (noch) manuell |
| --- | --- | --- |
| Tests, Coverage, Mutation Testing | **automatisch** (CI.yaml, bei jedem Push/PR) | |
| Build und Veröffentlichung der Artefakte | **automatisch** (release.yaml, bei Tag `v*`) | |
| Entscheidung, was deployt wird | **automatisch** (detect-changes.sh) | |
| Backend- und Frontend-Deployment | **automatisch** (deploy.yaml) | |
| Prüfung der laufenden Version | **automatisch** | |
| Rollback | **halbautomatisch** – ein Knopf, aber jemand muss ihn drücken | Die Entscheidung „zurück" braucht ein Urteil, nicht nur ein rotes Häkchen |
| `git tag` / Versionsnummer / CHANGELOG | **manuell** | Eine Version ist eine bewusste Aussage über die Art der Änderung (siehe RELEASE.md), nicht etwas, das eine Pipeline raten soll |
| `terraform apply` | **manuell, lokal** | Es gibt keinen Remote-State (Learner Lab), und Infrastrukturänderungen sollen nicht als Nebeneffekt eines Releases passieren. Mit Remote-State wäre ein `plan` im PR und ein `apply` nach Review der nächste Schritt. |
| AWS-Credentials nachpflegen | **manuell**, nach jeder Lab-Session | Learner-Lab-Einschränkung; mit OIDC entfiele es ganz (2.6) |
| GitHub Variables nach einem Apply setzen | **halbautomatisch** (`ops/sync-github-env.sh`) | |

### 9.3 Mehrere Umgebungen (dev / staging / prod)

Was an der Terraform-Konfiguration zu ändern wäre:

1. **Die Ressourcen in ein Modul ziehen** (`infra/modules/tictactest/`) und drei
   dünne Root-Konfigurationen `infra/envs/{dev,staging,prod}/` anlegen, die das
   Modul mit unterschiedlichen Variablen aufrufen. Alternative: ein Root und
   Terraform-Workspaces. Getrennte Verzeichnisse sind hier vorzuziehen, weil die
   Umgebungen sich dann *sichtbar* unterscheiden dürfen (prod mit Load Balancer,
   dev ohne) und ein `terraform apply` nie versehentlich im falschen Workspace
   landet.
2. **Getrennter State pro Umgebung.** Pflicht – ein gemeinsamer State wäre ein
   gemeinsames Schicksal. Richtig wäre ein S3-Backend mit
   `key = "tictactest/<env>/terraform.tfstate"` und Locking. Im Learner Lab
   bleibt es bei lokalem State.
3. Eine Variable `environment`, die **in jeden Namen** einfliesst:
   `name_prefix = "${var.project_name}-${var.environment}"`, `bucket_prefix`
   entsprechend. Sonst kollidieren Security-Group- und Bucket-Namen.
4. `default_tags` um `Environment = var.environment` erweitern – für Kosten- und
   Zuordnungsauswertungen.

| Pro Umgebung **gleich** | Pro Umgebung **unterschiedlich** |
| --- | --- |
| der Terraform-Code selbst (dasselbe Modul) | `instance_type` (dev `t3.micro`, prod grösser) |
| Form der Architektur: nginx → ttyd → Jar | `ttyd_max_clients` |
| systemd-Unit, nginx-Config, ttyd-Version und -Prüfsumme | Namen und damit alle Bucket-Namen, EIPs, IDs |
| Security-Group-**Regeln** (nur Port 80) | `ssh_ingress_cidrs` (in dev offener, in prod zu) |
| Region (im Lab erzwungen) | State-Key, AWS-Konto (in der Praxis: ein Konto pro Umgebung) |
| | Domain/Zertifikat, Monitoring-Schwellen, Aufbewahrungsfristen |

Zwei Dinge, die bei mehreren Umgebungen zusätzlich auffallen: Die GitHub
Variables müssten pro Umgebung existieren – GitHub **Environments** haben eigene
Variables und Secrets, was genau dafür gedacht ist. Und `config.js` wird pro
Umgebung von Terraform geschrieben und zeigt automatisch auf die richtige
Instanz; das Frontend-**Artefakt** bleibt für alle Umgebungen identisch.

### 9.4 Promotion-Strategie

```
  Tag v1.4.0
      │
      ▼  release.yaml  –  EINMAL bauen, EINMAL testen
 ┌──────────────────────────────┐
 │  Release-Artefakte v1.4.0    │  ◄── unveränderlich, die einzige Quelle
 │  jar + frontend.zip + sha256 │
 └───────┬──────────────────────┘
         │ automatisch, sofort
         ▼
    ┌─────────┐   Smoke-Test: /version == 1.4.0,
    │   dev   │   automatisierte Partie gegen die deployte Konsole
    └────┬────┘
         │ bei grünem Smoke-Test: automatisch (oder Knopf)
         ▼
    ┌──────────┐  E2E gegen die deployte Umgebung,
    │ staging  │  Last-/Speichertest: n gleichzeitige Partien
    └────┬─────┘
         │ GitHub Environment "prod" mit Required Reviewers
         ▼  (manuelle Freigabe)
    ┌─────────┐
    │  prod   │  danach: Versionsprüfung, Monitoring beobachten
    └─────────┘
```

**Wird für jede Umgebung neu gebaut, oder dasselbe Artefakt weitergereicht?**
Dasselbe Artefakt – **bit-für-bit identisch**, immer aus dem Release. Das ist
der Kern, nicht eine Optimierung:

* Getestet wurde **genau dieses Binary**. Ein Neubau erzeugt potenziell ein
  anderes (andere Abhängigkeitsversion, anderer Compiler, anderer Zeitstempel),
  und dann läuft in prod etwas, das nie getestet wurde.
* „Funktioniert in staging, nicht in prod" ist dann **immer** ein Umgebungs- und
  nie ein Artefaktproblem. Das halbiert die Fehlersuche.
* Rollback heisst „voriges Artefakt deployen" und ist deshalb schnell und
  verlässlich – nicht „alten Commit nochmal bauen und hoffen".

Die aktuelle Pipeline erfüllt das schon: `deploy-backend.sh` und
`deploy-frontend.sh` laden Release-Assets und bauen nichts.

**Was löst ein Deployment in welche Umgebung aus?**

| Umgebung | Auslöser | Begründung |
| --- | --- | --- |
| dev | Tag `v*` (wie heute) | schnelle Rückmeldung; dev darf kaputt sein |
| staging | erfolgreicher Smoke-Test in dev, automatisch | kein Mensch nötig, solange die Prüfung aussagekräftig ist |
| prod | manuelle Freigabe über ein GitHub Environment | der Zeitpunkt ist eine Geschäftsentscheidung (Wartungsfenster, Kommunikation), keine technische |

Ein Push auf `main` löst in **keiner** Umgebung ein Deployment aus – diese Regel
würde sich nicht ändern. (In vielen Teams geht ein Push auf `main` direkt nach
dev; hier ist der Tag die bewusste Grenze zwischen „gemerged" und
„veröffentlicht".)

**Welche Prüfung muss bestanden sein?**

| Vor … | Prüfung | Art |
| --- | --- | --- |
| dem Release | Unit- und E2E-Tests, Coverage-Gate, Mutation Testing | im Build, gegen den Code |
| staging | **Smoke-Test gegen die deployte dev-Umgebung**: `/version` meldet die neue Version (gibt es schon), plus eine automatisierte Partie über die Web-Konsole | gegen das *deployte Artefakt* |
| prod | E2E in staging, dazu ein Speicher-/Lasttest mit `ttyd_max_clients` parallelen Partien – der wirkliche Engpass dieser Anwendung | gegen die *Umgebung* |

Der entscheidende Unterschied: Vor dem Release testet man den **Code**, bei der
Promotion das **Deployment**. Ein Test, der ohne laufende Umgebung bestanden
werden kann, taugt nicht als Promotion-Gate.

**Wer darf nach prod deployen?** Über **GitHub Environments** mit *Required
Reviewers*: Der Job wartet, bis eine berechtigte Person freigibt. Dazu passen
*Deployment Branch/Tag Rules* (nur Tags `v*` dürfen prod deployen) und
Environment-Secrets, sodass die prod-Credentials für dev- und staging-Jobs
technisch gar nicht erreichbar sind. Zusammen mit der verpflichtenden Freigabe
ergibt das eine prüfbare Spur: wer wann welche Version nach prod gelassen hat.

**Wie passt die Änderungserkennung zu mehreren Umgebungen?**

Hier bricht der aktuelle Ansatz – und das ist der interessanteste Punkt. Heute
vergleicht `detect-changes.sh` mit dem **vorherigen Release-Tag**. Das setzt
stillschweigend voraus, dass die Umgebung diesen vorherigen Tag auch fährt. Bei
drei Umgebungen, die unterschiedlich weit hinterherhängen, ist das falsch:

> prod läuft noch `v1.1.0`. `v1.2.0` hat nur das Frontend geändert, `v1.3.0` nur
> das Backend. Promotiert man `v1.3.0` direkt nach prod und vergleicht mit
> `v1.2.0`, sagt die Erkennung „nur Backend" – und prod behält das Frontend von
> `v1.1.0`. Die Frontend-Änderung aus `v1.2.0` wird **übersprungen** und kommt
> nie an.

Die Korrektur: nicht gegen den vorherigen Tag vergleichen, sondern gegen die
**Version, die in der Zielumgebung tatsächlich läuft**:

```bash
# statt: previous_tag = der Tag vor diesem
# sondern:
deployed=$(curl -fsS "$VERSION_URL")      # z. B. 1.1.0 – die Umgebung selbst fragen
git diff --name-only "v$deployed".."$tag"
```

Die Versionsabfrage aus Auftrag 1 ist damit nicht nur eine Prüfung *nach* dem
Deployment, sondern die **Eingabe** für die Entscheidung, was zu deployen ist.
Für das Frontend bräuchte es dieselbe Auskunft – `version.json` liefert sie
schon.

Pragmatische Alternative, in der Praxis verbreitet: In nachgelagerten Umgebungen
**immer beides deployen**. Ein Frontend-Sync ist billig, ein Backend-Neustart
dauert Sekunden, und „ich deploye den vollständigen Zustand dieser Version" ist
eine viel einfachere Aussage als eine Differenz über mehrere Versionssprünge.
Die Änderungserkennung bliebe dann, wofür sie hier gedacht ist: die schnelle,
erste Umgebung nicht unnötig zu stören – genau wie das Überspringen des
Backend-Jobs heute verhindert, dass eine Farbänderung im Frontend jemandem die
laufende Partie abbricht.

---

## 10. Spickzettel

```bash
# Infrastruktur (lokal, selten)
cd infra && terraform init && terraform plan && terraform apply
terraform output -json github_variables
cd .. && ops/sync-github-env.sh

# Release (deployt automatisch nur das Geänderte)
#   CHANGELOG.md pflegen, dann:
git tag v1.4.0 && git push origin v1.4.0

# Gezielt deployen / Rollback / nach abgelaufenen Credentials
gh workflow run deploy.yaml -f version=1.2.0

# Was läuft gerade?
curl -s "$(cd infra && terraform output -raw version_url)"
curl -s "$(cd infra && terraform output -raw play_url)/version.json"

# Nach einer neuen Lab-Session
gh secret set AWS_ACCESS_KEY_ID
gh secret set AWS_SECRET_ACCESS_KEY
gh secret set AWS_SESSION_TOKEN
```
