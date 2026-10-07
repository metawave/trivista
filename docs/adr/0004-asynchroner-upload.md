# Validierung im Request, Import asynchron

Trivy-Reports sind groß (die Packages-Liste ist in aktuellen Trivy-Versionen Default), ein vollständig synchroner Import würde CI-Jobs blockieren und in Timeouts laufen. Deshalb validiert der Request und reduziert den Report auf die Allowlist (ADR 0003), und ein Solid-Queue-Job importiert Findings und Zähler.

## Request (synchron)

1. Request-Body über dem Limit (Default 50 MB, konfigurierbar): `413` durch Pumas `http_content_length_limit`, bevor der Body vollständig gelesen ist, auch bei chunked Requests. Puma liest den Body vor jeder App-Logik in ein Tempfile; Prüfungen in Rails kämen zu spät. Die Durchsetzung bei chunked Requests ist Puma-versionsabhängig; die Puma-Version wird gepinnt und das Verhalten per Test abgesichert.
2. Upload Token prüfen (nicht abgelaufen, nicht widerrufen), sonst `401` mit `WWW-Authenticate`.
3. Mehr als 60 Uploads pro Stunde pro Token (Rails `rate_limit`) oder mehr als 10 offene `pending`-Scans pro Owner, beides konfigurierbar: `429`. Begrenzt den Schaden eines geleakten Tokens.
4. Kein `multipart/form-data`: `415`. Der Trivy-Report kommt als Dateipart und landet als Tempfile statt als Params im Speicher.
5. Dateipart fehlt, ungültiges JSON, Pflichtfelder `project`, `repo`, `branch`, `commit` fehlen oder ungültiger `trigger`: `400`. Die Felder werden nicht aus Trivys `Metadata` abgeleitet.
6. `trivy k8s`-Report (Top-Level-Key `ClusterName`) oder `SchemaVersion` ungleich 2: `422` mit Meldung.
7. Trivy-Report auf die Allowlist reduzieren (ADR 0003), Scan mit Status `pending` speichern und Import-Job in derselben Transaktion einreihen (ADR 0001), `202` mit `Location` auf den Scan.

## Branch bei Tag- und PR-Scans

`branch` ist immer ein Branch. Ein Tag-Scan gehört zu dem Branch, aus dem getaggt wurde, der Tag steht in `tag`; ein PR-Scan gehört zum Source-Branch. Die CI muss diese Werte liefern; die README zeigt die passenden Variablen für GitLab, GitHub, Bamboo und Woodpecker.

## Job (asynchron)

Findings und Zähler importieren, Status `processed` oder `failed` mit sichtbarer Fehlermeldung. Kein Fehler verschwindet still. Fehlendes oder leeres `Results` ist ein gültiger Scan ohne Findings, kein Formatfehler. Occurrences, Zähler und Status werden in einer Transaktion geschrieben, der Import ist idempotent.

## Status für die CI

Ein Upload Token darf den Status der Scans lesen, die es selbst hochgeladen hat (`GET` auf `Location`): Status und Fehlermeldung, sonst nichts. So kann die CI einen `failed`-Import erkennen; die README zeigt ein optionales Polling-Beispiel.

## Consequences

- Die Reduktion parst den ganzen Trivy-Report im Speicher, pro gleichzeitigem Upload ein Vielfaches seiner Größe. Speicherbedarf wird mit echten Reports gemessen; reicht das Memory-Limit nicht, wird das Upload-Limit gesenkt, als letzte Stufe ein Streaming-Parser eingeführt. Die README empfiehlt `--list-all-pkgs=false`.
- Ingress bzw. Gateway vor Trivista müssen Request-Bodies bis zum Upload-Limit und die Upload-Dauer zulassen, sollen das Limit zusätzlich selbst durchsetzen und Uploads pro IP rate- und connection-limitieren, weil Puma auch unauthentifizierte Bodies vor der Token-Prüfung puffert.
- Der Pod braucht ein `ephemeral-storage`-Limit für die Tempfiles.
