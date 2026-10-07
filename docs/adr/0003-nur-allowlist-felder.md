# Nur Allowlist-Felder speichern, kein Roh-JSON

Trivy-Reports können Secrets an vielen Stellen im Klartext enthalten: in den Kontextzeilen von Secret-Findings (`Code`, Trivy maskiert nur den Regeltreffer), in Image-Konfiguration und Build-Befehlen (`ImageConfig`, `Layer.CreatedBy`), in Code-Vorschauen und Rego-Traces von Misconfigurations (`CauseMetadata.Code`, `RenderedCause`, `Traces`) und in Repo-URLs mit Zugangsdaten. Deshalb liest der Upload-Request aus dem Trivy-Report ausschließlich die Felder einer Allowlist und speichert sie in Spalten von Scan, Finding und Occurrence; alles andere wird verworfen, auch Felder künftiger Trivy-Versionen. Ein Roh-JSON wird nicht gespeichert. Trivista hält damit keine Kopie von Secrets in DB, Backups oder Dumps.

## Allowlist

| Ebene | Felder |
|---|---|
| Report | `SchemaVersion`, `CreatedAt`, `ArtifactName` (bei URLs nur `scheme://host/path`, ohne Userinfo, Query und Fragment), `ArtifactType`, `Metadata.OS.Family`, `Metadata.OS.Name`, `Trivy.Version` |
| Result | `Target`, `Class`, `Type` |
| Vulnerability | `VulnerabilityID`, `PkgName`, `PkgPath`, `InstalledVersion`, `FixedVersion`, `Status`, `Severity`, `Title`, `Description`, `PrimaryURL`, `References`, `PublishedDate`, `LastModifiedDate` |
| Misconfiguration | `ID`, `Namespace`, `Type`, `Title`, `Description`, `Resolution`, `Severity`, `Status`, `PrimaryURL`, `References`, `CauseMetadata.Resource`, `CauseMetadata.Provider`, `CauseMetadata.Service`, `CauseMetadata.StartLine`, `CauseMetadata.EndLine` |
| Secret | `RuleID`, `Category`, `Severity`, `Title`, `StartLine`, `EndLine` |
| License | `Name`, `Category`, `Severity`, `PkgName`, `FilePath`, `Confidence`, `Link` |

## Längen

Texte werden auf 1000 Zeichen gekürzt, `Description` und `Resolution` auf 10000, `References` auf 50 Einträge, damit ein einzelnes Finding die Quote (ADR 0004) nicht mit riesigen Texten umgeht. Werte, die ein Artifact, Finding oder eine Occurrence identifizieren (ADR 0002 und 0008: `ArtifactName`, `Target`, `Class`, `Type`, die IDs, `PkgName`, `PkgPath`, `InstalledVersion`, `Namespace`, `CauseMetadata.Resource`, `FilePath`), werden nie gekürzt: Ab 1001 Zeichen wird der Report mit `422` abgelehnt, weil zwei lange Pfade mit gleichem Anfang sonst still zu einem Finding verschmölzen.

## Flüchtige Kopien

Vor der Projektion liegt der unbereinigte Report kurzzeitig in Tempfiles von Puma und Rack. Diese liegen auf flüchtigem Speicher (`emptyDir`) und werden nach dem Request gelöscht. Der Upload-Pfad schreibt weder Request-Body noch Parser-Meldungen in Logs oder Error-Tracker; ungültiges JSON ergibt eine generische `400` ohne Exception-Text, weil Parser-Fehler Ausschnitte des Inputs enthalten.

## URLs aus Reports

`PrimaryURL`, `References` und `Link` stammen von externen Uploadern. Sie werden wie `ArtifactName` nur als `scheme://host/path` gespeichert, ohne Userinfo, Query und Fragment; bereinigt wird vor dem Kürzen, damit eine lange Userinfo nicht als Host stehen bleibt. Dargestellt werden sie nur als Link, wenn sie absolute `http`- oder `https`-URLs sind; alles andere erscheint als Text, damit z. B. `javascript:`-URLs keinen Code im Browser eines Lesers ausführen.

## Considered Options

- Unbereinigt speichern und nur über die Anwendung nicht ausliefern: verworfen, Backups, Dumps und DB-Zugriff legen die Secrets offen.
- Unbereinigt mit Active Record Encryption: verworfen, der Schlüssel liegt in derselben App.
- Blocklist bekannter Leck-Felder: verworfen, jede Prüfrunde fand ein weiteres Feld (`Code`, `ImageConfig`, `Layer.CreatedBy`, `Traces`), und neue Trivy-Versionen können neue bringen.
- Allowlist-Projektion zusätzlich als Roh-JSON speichern: verworfen. Sie enthält nur Felder, die ohnehin in Spalten stehen, wiederholt Beschreibungen bei jedem Scan und dominiert den Speicherbedarf; ein Neu-Import daraus brächte kaum Gewinn.

## Consequences

- Keine Code-Vorschau bei Secrets und Misconfigurations, keine Image-Konfiguration, kein Package-Inventar.
- Alte Scans lassen sich nicht neu importieren; Schemaänderungen arbeiten mit den gespeicherten Spalten.
- Jede Erweiterung der Allowlist braucht eine Prüfung, ob das Feld Secret-Klartext enthalten kann. `Message` bei Misconfigurations ist bewusst nicht enthalten, weil Trivy-Checks dort Befehlszeilen aus dem gescannten Input einsetzen (z. B. DS025).
