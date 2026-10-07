# Leichtgewichtiger, Trivy-nativer Read-only-Collector

Trivista ist bewusst schmal: Es sammelt Trivy-Reports per Push und zeigt sie an. Dependency-Track wurde verworfen, weil es auch bei wenigen Scans mindestens 4 GB RAM braucht; DefectDojo, weil wesentliche Funktionen der "Pro Edition" vorbehalten sind und in der Evaluation fehlten.

## Explizit nicht vorgesehen

- Pull-Scanning: Trivista führt Trivy nie selbst aus.
- Andere Scanner als Trivy.
- Triage, Kommentare, `.trivyignore`- oder VEX-Export (Kandidat für Phase 2).
- Export und Benachrichtigungen.
- Vergleich beliebiger Scans; der Diff gilt nur zum Predecessor.
- Speichern des Package-Inventars.
- `trivy k8s`-Reports im MVP (Phase 2, siehe ADR 0008).
- Owner-Transfer von Projects (Phase 2). Ein Owner-Wechsel geschieht im MVP durch Uploads in den neuen Namensraum; die Historie bleibt beim alten Project. Team-Projects überleben Austritte über Group-Service-Accounts.

## Consequences

Trivy scannt per Default nur `vuln,secret`. Für alle Finding-Typen muss die CI `--scanners vuln,misconfig,secret,license` setzen. Trivista kennt die Scan-Konfiguration nicht und zeigt deshalb "nicht mehr gemeldet" statt "behoben"; die README empfiehlt eine gleichbleibende Konfiguration pro Artifact.
