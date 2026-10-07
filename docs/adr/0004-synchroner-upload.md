# Upload und Import synchron in einem Request

Der teure Teil eines Uploads, das Parsen des Trivy-Reports und das Lesen der Allowlist-Felder (ADR 0003), muss ohnehin synchron im Request laufen, damit unbereinigte Daten nie gespeichert werden. Danach bleiben nur Inserts der reduzierten Findings. Deshalb importiert der Request auch: Scan, Findings, Occurrences und Zähler werden in einer Transaktion geschrieben (`insert_all`/`upsert_all`). Die CI erhält Erfolg oder Fehler direkt in der Antwort.

## Request

1. Request-Body über dem Limit (Default 50 MB, konfigurierbar): `413` durch Pumas `http_content_length_limit`, bevor der Body vollständig gelesen ist, auch bei chunked Requests. Puma liest den Body vor jeder App-Logik in ein Tempfile; Prüfungen in Rails kämen zu spät. Die Durchsetzung bei chunked Requests ist Puma-versionsabhängig; die Puma-Version wird gepinnt und das Verhalten per Test abgesichert.
2. Upload Token prüfen (nicht abgelaufen, nicht widerrufen), sonst `401` mit `WWW-Authenticate`.
3. Mehr als 60 Uploads pro Stunde pro Token (Rails `rate_limit`, konfigurierbar): `429`. Das Limit gilt näherungsweise; parallele erste Requests können es knapp überschreiten. Ist der Cache nicht erreichbar, bricht der Upload mit `503` ab, statt ungebremst durchzulassen.
4. Kein `multipart/form-data`: `415`. Der Trivy-Report kommt als Dateipart und landet als Tempfile statt als Params im Speicher.
5. Dateipart fehlt, ungültiges JSON, Pflichtfelder `project`, `repo`, `branch`, `commit` fehlen oder ungültiger `trigger`: `400`. Die Felder werden nicht aus Trivys `Metadata` abgeleitet.
6. `trivy k8s`-Report (Top-Level-Key `ClusterName`), `SchemaVersion` ungleich 2, mehr Findings als `MAX_FINDINGS_PER_REPORT` oder ein identifizierender Wert über 1000 Zeichen (ADR 0003): `422` mit Meldung.
7. Allowlist-Felder lesen (ADR 0003) und in einer Transaktion importieren: `201` mit `Location` auf den Scan. Die Transaktion sperrt den Owner und prüft die Quote: Würden die Occurrences des Owners die Quote überschreiten (Default 5 Mio., konfigurierbar), wird nichts gespeichert und die Antwort ist `507`. Die Postgres-Instanz ist geteilt; eine volle Disk träfe alle Owner. Ausweg ist das Löschen von Scans (ADR 0007). Fehlendes oder leeres `Results` ist ein gültiger Scan ohne Findings. Scheitert der Import, wird nichts gespeichert und die Antwort nennt den Fehler; kein Fehler verschwindet still.

## Branch bei Tag- und PR-Scans

`branch` ist immer ein Branch. Ein Tag-Scan gehört per Konvention zum Default Branch, weil ein Git-Tag keinem Branch gehört und keine CI den Ursprungs-Branch liefert; die CI schickt dafür z. B. `CI_DEFAULT_BRANCH` (GitLab) oder `github.event.repository.default_branch` (GitHub), der Tag steht in `tag`. Ein PR-Scan gehört zum Source-Branch. Die README zeigt die passenden Variablen für GitLab, GitHub, Bamboo und Woodpecker.

## Considered Options

- Asynchroner Import per Solid Queue: verworfen. Er brachte transaktionales Enqueue, einen `pending`-Status samt Limit, einen Status-Endpoint für die CI und hängende Scans bei Worker-Abstürzen mit sich, für einen Arbeitsschritt, der nur noch aus Inserts besteht.

## Consequences

- Parsen und Import belegen einen Puma-Thread für die Dauer des Requests und brauchen ein Vielfaches der Report-Größe an Speicher. Gemessen mit einem echten 49,6-MB-Report (`node:18-bullseye`, 11.210 Vulnerabilities): 4 Sekunden, Spitze rund 450 MB. Deshalb parst und importiert pro Prozess immer nur ein Upload gleichzeitig; weitere warten. Dauert der Import über etwa 10 Sekunden, wird Asynchronität neu bewertet; reicht der Speicher nicht, wird das Upload-Limit gesenkt, als letzte Stufe ein Streaming-Parser eingeführt. Die README empfiehlt `--list-all-pkgs=false`.
- Ingress bzw. Gateway vor Trivista müssen Request-Bodies bis zum Upload-Limit und die Request-Dauer zulassen, sollen das Limit zusätzlich selbst durchsetzen und Uploads pro IP rate- und connection-limitieren, weil Puma auch unauthentifizierte Bodies vor der Token-Prüfung puffert.
- Der Pod braucht ein `ephemeral-storage`-Limit für die Tempfiles.
