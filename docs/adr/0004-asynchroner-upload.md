# Validierung im Request, Import asynchron

Trivy-Reports sind groß (die Packages-Liste ist in aktuellen Trivy-Versionen Default), ein vollständig synchroner Import würde CI-Jobs blockieren und in Timeouts laufen. Deshalb validiert und bereinigt der Request, und ein Solid-Queue-Job importiert Findings und Zähler.

## Request (synchron)

1. Upload Token prüfen (nicht abgelaufen, nicht widerrufen), sonst `401` mit `WWW-Authenticate`.
2. Request-Body über dem Limit (Default 50 MB, konfigurierbar): `413` durch Pumas `http_content_length_limit`, bevor der Body vollständig gelesen ist, auch bei chunked Requests. Eine Prüfung in Rails käme zu spät, weil Puma den Body vorher in ein Tempfile liest.
3. Kein `multipart/form-data`: `415`. Der Trivy-Report kommt als Dateipart und landet als Tempfile statt als Params im Speicher.
4. Dateipart fehlt, ungültiges JSON, Pflichtfelder `project`, `repo`, `branch`, `commit` fehlen oder ungültiger `trigger`: `400`. Die Felder werden nicht aus Trivys `Metadata` abgeleitet.
5. `trivy k8s`-Report (Top-Level-Key `ClusterName`) oder `SchemaVersion` ungleich 2: `422` mit Meldung.
6. `project` wurde aus dem Namensraum des Service-Account-Owners übertragen: `409` mit Hinweis auf den neuen Owner (ADR 0006).
7. Secrets bereinigen (ADR 0003), Scan mit Status `pending` speichern, `202` mit `Location` auf den Scan.

## Job (asynchron)

Findings und Zähler importieren, Status `processed` oder `failed` mit sichtbarer Fehlermeldung. Kein Fehler verschwindet still. Fehlendes oder leeres `Results` ist ein gültiger Scan ohne Findings, kein Formatfehler.

## Consequences

- Die Bereinigung parst den ganzen Trivy-Report im Speicher, pro gleichzeitigem Upload ein Vielfaches seiner Größe. Speicherbedarf wird mit echten Reports gemessen; reicht das Memory-Limit nicht, wird das Upload-Limit gesenkt, als letzte Stufe ein Streaming-Parser eingeführt. Die README empfiehlt `--list-all-pkgs=false`.
- Ingress bzw. Gateway vor Trivista müssen Request-Bodies bis zum Upload-Limit und die Upload-Dauer zulassen.
