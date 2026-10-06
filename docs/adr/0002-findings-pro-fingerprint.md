# Findings einmal pro Fingerprint und Project speichern

Ein Finding wird einmal pro Fingerprint und Project gespeichert; jedes Auftreten in einem Scan ist eine Occurrence. Das vermeidet Redundanz bei unveränderten Cron-Scans und liefert "neu" und "nicht mehr gemeldet" für den Diff ohne Zusatzaufwand. Pro Project, damit Findings nie über Projects mit unterschiedlicher Visibility geteilt werden. Trivys eigener `Fingerprint` ist ungeeignet, weil er `ArtifactID` enthält und sich bei jedem Image-Rebuild ändert.

## Zusammensetzung

| Typ | Fingerprint |
|---|---|
| Vulnerability | `VulnerabilityID` + `PkgName` + `PkgPath` + `Target`; bei `Class=os-pkgs` statt `Target`: `Class` + `Type` (OS-Familie) |
| Misconfiguration | `ID` + `Target` + `CauseMetadata.Resource`, bei leerem `Resource` stattdessen `CauseMetadata.StartLine`; nur `Status=FAIL`. Fehlen beide, fallen Treffer derselben Regel im selben Target bewusst zu einem Finding zusammen |
| Secret | `RuleID` + `Target` + `StartLine` |
| License | `Name` + `Target` + (`PkgName` oder `FilePath`) |

Bei OS-Paketen enthält `Target` Image-Tag und OS-Version (`app:1.2.3 (debian 12.4)`) und ist deshalb nicht stabil. Installierte Version und Severity gehören nicht in den Fingerprint, sondern an die Occurrence; sonst erschiene ein Upgrade ohne Fix oder eine Neubewertung als "nicht mehr gemeldet + neu". Eine Occurrence ist eindeutig pro Scan, Artifact, Finding und installierter Version; ein Finding kann pro Scan mehrere Occurrences haben (z. B. `lodash@4.17.20` und `lodash@3.10.1` im selben Lockfile) und zählt als ein Finding. Bei Secrets und Misconfigurations ohne `Resource` erscheint eine verschobene Zeile bewusst als "nicht mehr gemeldet + neu".

## Consequences

- Trivys `Packages` (Inventar) werden nicht gespeichert.
- Zähler werden pro Scan und Artifact vorberechnet und bleiben dauerhaft. Roh-JSON und Occurrences sollen später per Retention (Default 90 Tage) löschbar sein; danach gibt es für alte Scans keinen Diff und kein Detail mehr, nur noch den Trend. Retention ist im MVP nicht umgesetzt.
