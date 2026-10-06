# Validierung im Request, Import asynchron

Trivy-Reports sind groß (die Packages-Liste ist in aktuellen Trivy-Versionen Default), ein vollständig synchroner Import würde CI-Jobs blockieren und in Timeouts laufen. Deshalb validiert der Request und reduziert den Report auf die Allowlist (ADR 0003), und ein Solid-Queue-Job importiert Findings und Zähler.

## Request (synchron)

1. Upload Token prüfen (nicht abgelaufen, nicht widerrufen), sonst `401` mit `WWW-Authenticate`.
2. Request-Body über dem Limit (Default 50 MB, konfigurierbar): `413` durch Pumas `http_content_length_limit`, bevor der Body vollständig gelesen ist, auch bei chunked Requests. Eine Prüfung in Rails käme zu spät, weil Puma den Body vorher in ein Tempfile liest. Die Durchsetzung bei chunked Requests ist Puma-versionsabhängig; die Puma-Version wird gepinnt und das Verhalten per Test abgesichert.
3. Mehr als 60 Uploads pro Stunde pro Token (Rails `rate_limit`) oder mehr als 10 offene `pending`-Scans pro Owner, beides konfigurierbar: `429`. Begrenzt den Schaden eines geleakten Tokens.
4. Kein `multipart/form-data`: `415`. Der Trivy-Report kommt als Dateipart und landet als Tempfile statt als Params im Speicher.
5. Dateipart fehlt, ungültiges JSON, Pflichtfelder `project`, `repo`, `branch`, `commit` fehlen oder ungültiger `trigger`: `400`. Die Felder werden nicht aus Trivys `Metadata` abgeleitet.
6. `trivy k8s`-Report (Top-Level-Key `ClusterName`) oder `SchemaVersion` ungleich 2: `422` mit Meldung.
7. `project` wurde aus dem Namensraum des Service-Account-Owners übertragen: `409` mit Hinweis auf den neuen Owner (ADR 0006).
8. Trivy-Report auf die Allowlist reduzieren (ADR 0003), Scan mit Status `pending` speichern, `202` mit `Location` auf den Scan.

## Job (asynchron)

Findings und Zähler importieren, Status `processed` oder `failed` mit sichtbarer Fehlermeldung. Kein Fehler verschwindet still. Fehlendes oder leeres `Results` ist ein gültiger Scan ohne Findings, kein Formatfehler. Occurrences, Zähler und Status werden in einer Transaktion geschrieben, der Import ist idempotent. Weil die Queue nach Rails-Standard in einer eigenen DB liegt, sind Scan-Speicherung und Enqueue nicht atomar; ein wiederkehrender Job stellt verwaiste `pending`-Scans erneut ein.

## Consequences

- Die Reduktion parst den ganzen Trivy-Report im Speicher, pro gleichzeitigem Upload ein Vielfaches seiner Größe. Speicherbedarf wird mit echten Reports gemessen; reicht das Memory-Limit nicht, wird das Upload-Limit gesenkt, als letzte Stufe ein Streaming-Parser eingeführt. Die README empfiehlt `--list-all-pkgs=false`.
- Ingress bzw. Gateway vor Trivista müssen Request-Bodies bis zum Upload-Limit und die Upload-Dauer zulassen und sollen das Limit zusätzlich selbst durchsetzen.
