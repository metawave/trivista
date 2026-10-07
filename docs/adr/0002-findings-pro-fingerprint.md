# Findings einmal pro Fingerprint und Project speichern

Ein Finding wird einmal pro Fingerprint und Project gespeichert; jedes Auftreten in einem Scan ist eine Occurrence. Das vermeidet Redundanz bei unveränderten Cron-Scans und liefert "neu" und "nicht mehr gemeldet" für den Diff ohne Zusatzaufwand. Pro Project, damit Findings nie über Projects mit unterschiedlicher Visibility geteilt werden. Trivys eigener `Fingerprint` ist ungeeignet, weil er `ArtifactID` enthält und sich bei jedem Image-Rebuild ändert.

## Zusammensetzung

| Typ | Fingerprint |
|---|---|
| Vulnerability | `VulnerabilityID` + `PkgName` + `Target`; bei `Class=os-pkgs` statt `Target`: `Class` + `Type` (OS-Familie) |
| Misconfiguration | `ID` + Namespace (`builtin.*` zählt als ein gemeinsamer Namespace, eigene Checks behalten ihren) + `Target` + `CauseMetadata.Resource`, bei leerem `Resource` stattdessen `CauseMetadata.StartLine`; nur `Status=FAIL`. Fehlen beide, fallen Treffer derselben Regel im selben Target bewusst zu einem Finding zusammen. `ID` wird normalisiert (Präfix `AVD-` entfernen, Nummer vierstellig mit Bindestrich, `DS005` → `DS-0005`), weil Trivy das ID-Format geändert hat |
| Secret | `RuleID` + `Target` + `StartLine` |
| License | `Name` + `Target` + (`PkgName` oder `FilePath`) |

Bei OS-Paketen enthält `Target` Image-Tag und OS-Version (`app:1.2.3 (debian 12.4)`) und ist deshalb nicht stabil. Bei Misconfigurations und Secrets aus der Image-Konfiguration ist `Target` der Image-Name samt Tag; es wird wie das Artifact um Tag und Digest gekürzt (ADR 0008), Datei-Targets bleiben unverändert. `PkgPath` enthält bei Sprachpaketen oft die Version im Dateinamen (`spring-beans-5.3.15.jar`, `activesupport-6.0.2.1.gemspec`) und gehört deshalb ebenfalls nicht in den Fingerprint.

Das Finding trägt nur Identität und Beschreibung (`Title`, `Description`, `References`, `PrimaryURL`). Beobachtete Werte hängen an der Occurrence: installierte Version, `PkgPath`, `FixedVersion`, `Status` und Severity. Sonst erschiene ein Upgrade ohne Fix oder eine Neubewertung als "nicht mehr gemeldet + neu". Eine Occurrence ist eindeutig pro Scan, Artifact, Finding, installierter Version und Fundort (`PkgPath`, bei Licenses `FilePath`); ein Finding kann pro Scan mehrere Occurrences haben (z. B. `lodash@4.17.20` und `lodash@3.10.1` im selben Lockfile) und zählt als ein Finding mit der höchsten Severity seiner Occurrences. Bei Secrets und Misconfigurations ohne `Resource` erscheint eine verschobene Zeile bewusst als "nicht mehr gemeldet + neu".

## Consequences

- Trivys `Packages` (Inventar) werden nicht gespeichert.
- Zähler werden pro Scan vorberechnet und bleiben dauerhaft. Occurrences sollen später per Retention (Default 90 Tage) löschbar sein; danach gibt es für alte Scans keinen Diff und kein Detail mehr, nur noch den Trend. Retention kommt in Phase 2; im MVP begrenzt die Quote (ADR 0004) den Speicher.
