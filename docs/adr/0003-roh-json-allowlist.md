# Roh-JSON nur als Allowlist-Projektion speichern

Trivy-Reports können Secrets an vielen Stellen im Klartext enthalten: in den Kontextzeilen von Secret-Findings (`Code`, Trivy maskiert nur den Regeltreffer), in Image-Konfiguration und Build-Befehlen (`ImageConfig`, `Layer.CreatedBy`), in Code-Vorschauen und Rego-Traces von Misconfigurations (`CauseMetadata.Code`, `RenderedCause`, `Traces`) und in Repo-URLs mit Zugangsdaten. Deshalb wird der Trivy-Report synchron im Upload-Request, vor jedem Speichern, auf eine Allowlist bekannter Felder reduziert; alles andere wird verworfen, auch Felder künftiger Trivy-Versionen. Diese Projektion wird als Roh-JSON gespeichert. Trivista hält damit keine Kopie von Secrets in DB, Backups oder Dumps.

## Allowlist

| Ebene | Felder |
|---|---|
| Report | `SchemaVersion`, `CreatedAt`, `ArtifactName` (bei URLs nur `scheme://host/path`, ohne Userinfo, Query und Fragment), `ArtifactType`, `Metadata.OS.Family`, `Metadata.OS.Name`, `Trivy.Version` |
| Result | `Target`, `Class`, `Type` |
| Vulnerability | `VulnerabilityID`, `PkgName`, `PkgPath`, `InstalledVersion`, `FixedVersion`, `Status`, `Severity`, `Title`, `Description`, `PrimaryURL`, `References`, `PublishedDate`, `LastModifiedDate` |
| Misconfiguration | `ID`, `Type`, `Title`, `Description`, `Resolution`, `Severity`, `Status`, `PrimaryURL`, `References`, `CauseMetadata.Resource`, `CauseMetadata.Provider`, `CauseMetadata.Service`, `CauseMetadata.StartLine`, `CauseMetadata.EndLine` |
| Secret | `RuleID`, `Category`, `Severity`, `Title`, `StartLine`, `EndLine` |
| License | `Name`, `Category`, `Severity`, `PkgName`, `FilePath`, `Confidence`, `Link` |

## Flüchtige Kopien

Vor der Projektion liegt der unbereinigte Report kurzzeitig in Tempfiles von Puma und Rack. Diese liegen auf flüchtigem Speicher (`emptyDir`) und werden nach dem Request gelöscht. Der Upload-Pfad schreibt weder Request-Body noch Parser-Meldungen in Logs oder Error-Tracker; ungültiges JSON ergibt eine generische `400` ohne Exception-Text, weil Parser-Fehler Ausschnitte des Inputs enthalten.

## Considered Options

- Unbereinigt speichern und nur über die Anwendung nicht ausliefern: verworfen, Backups, Dumps und DB-Zugriff legen die Secrets offen.
- Unbereinigt mit Active Record Encryption: verworfen, der Schlüssel liegt in derselben App.
- Blocklist bekannter Leck-Felder: verworfen, jede Prüfrunde fand ein weiteres Feld (`Code`, `ImageConfig`, `Layer.CreatedBy`, `Traces`), und neue Trivy-Versionen können neue bringen.
- Gar kein Roh-JSON: verworfen, Neu-Import bei Schemaänderungen von Trivista soll möglich bleiben.

## Consequences

- Keine Code-Vorschau bei Secrets und Misconfigurations, keine Image-Konfiguration, kein Package-Inventar.
- Neu-Import alter Scans ist nur für Felder der Allowlist möglich.
- Jede Erweiterung der Allowlist braucht eine Prüfung, ob das Feld Secret-Klartext enthalten kann. `Message` bei Misconfigurations ist bewusst nicht enthalten, weil Trivy-Checks dort Befehlszeilen aus dem gescannten Input einsetzen (z. B. DS025).
