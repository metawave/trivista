# Secret-Inhalte vor dem Speichern verwerfen

Trivy maskiert bei Secret-Findings nur den Regeltreffer; die Kontextzeilen in `Code` stehen im Klartext. Deshalb werden synchron im Upload-Request, vor jedem Speichern, `Results[].Secrets[].Match`, `Results[].Secrets[].Code` und Einträge in `Results[].ExperimentalModifiedFindings[]` mit `Type == "secret"` aus dem Trivy-Report entfernt. Ebenso wird die Userinfo (`user:token@`) aus URL-förmigen Werten in `ArtifactName` und `Metadata.RepoURL` entfernt, da Repo-Scans Zugangsdaten in der URL tragen können. Das bereinigte Roh-JSON wird gespeichert. Trivista hält damit nie eine zweite Kopie von Secrets, auch nicht in Backups oder Dumps; Preis ist eine fehlende Code-Vorschau bei Secrets.

## Considered Options

- Unbereinigt speichern und nur über die Anwendung nicht ausliefern: verworfen, Backups, Dumps und DB-Zugriff legen die Secrets offen.
- Unbereinigt mit Active Record Encryption: verworfen, der Schlüssel liegt in derselben App.
- Gar kein Roh-JSON (Allowlist): verworfen, Neu-Import bei Schemaänderungen soll möglich bleiben.

## Consequences

`CauseMetadata.Code`, `RenderedCause` und `Metadata.ImageConfig` (Env, History) bleiben bewusst erhalten; sie können sensible Daten enthalten, sind aber keine Secret-Findings.
