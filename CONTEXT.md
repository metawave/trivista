# Trivista

Sammelt Trivy-Reports pro Project und zeigt die Historie der Findings über Zeit, read-only.

## Language

### Struktur

**Project**:
Oberste Einheit, gehört einem Owner und hat eine Visibility. Enthält Repos oder, für einen Cluster, direkt Scans.
_Avoid_: Application, Product, Projekt

**Repo**:
Ein Source-Repository innerhalb eines Projects.
_Avoid_: Repository, Codebase

**Branch**:
Ein Branch eines Repos.
_Avoid_: Ref

**Default Branch**:
Der Branch eines Repos, der den aktuellen Stand des Repos in der Projektübersicht repräsentiert.
_Avoid_: Main branch, Hauptbranch

**Cluster**:
Ein Kubernetes-Cluster, abgebildet als eigenes Project.
_Avoid_: Environment

**Trivy-Report**:
Die von Trivy erzeugte JSON-Datei, die hochgeladen wird.
_Avoid_: Result, Output

**Scan**:
Ein hochgeladener Trivy-Report für einen Branch zu einem Commit, oder für einen Cluster. Tag-Scans gehören zum Default Branch, PR-Scans zum Source-Branch.
_Avoid_: Run, Report

**Commit**:
Der Git-Commit, auf dem ein Scan eines Branches basiert.
_Avoid_: Revision, SHA

**Tag**:
Optionale Release-Bezeichnung eines Scans.
_Avoid_: Version, Label

**Trigger**:
Optionaler Auslöser eines Scans (`push`, `tag`, `schedule`, `manual`, `pr`), sonst `unknown`.
_Avoid_: Source, Event

**Artifact**:
Ein von Trivy gescanntes Objekt, z. B. ein Image, ein Filesystem oder eine Kubernetes-Resource; identifiziert durch Kategorie und Name ohne Tag oder Digest.
_Avoid_: Target

### Findings

**Finding**:
Ein einzelner Trivy-Befund vom Typ Vulnerability, Misconfiguration, Secret oder License.
_Avoid_: Issue, Alert, Package

**Occurrence**:
Ein Auftreten eines Findings in einem Scan und Artifact, mit den dort beobachteten Werten wie installierter Version, Fundort und Severity.
_Avoid_: Instance, Hit

**Severity**:
Schweregrad eines Findings gemäß Trivy (`CRITICAL`, `HIGH`, `MEDIUM`, `LOW`, `UNKNOWN`).
_Avoid_: Priority, Risk

**Fingerprint**:
Stabile Identität eines Findings innerhalb eines Projects über Scans hinweg.
_Avoid_: Hash, Key

**Predecessor**:
Der letzte Scan desselben Branches bzw. Cluster-Projects und Artifacts vor einem Scan.
_Avoid_: Previous, Baseline

**Diff**:
Neue und nicht mehr gemeldete Findings eines Scans gegenüber seinem Predecessor. "Nicht mehr gemeldet" heißt nicht zwingend behoben, die Scan-Konfiguration kann sich geändert haben.
_Avoid_: Comparison, Delta

**Trend**:
Verlauf der Finding-Anzahl pro Typ und Severity über die Scans eines Branches bzw. Cluster-Projects und Artifacts. Für ein oder mehrere Projects pro Tag summiert über den jeweils letzten Scan pro Artifact auf den Default Branches.
_Avoid_: History, Chart

**Retention**:
Löscht die Occurrences von Scans, die älter als die Aufbewahrungsdauer sind; der Scan behält seine Zähler für den Trend, Detail und Diff entfallen. Der neueste Scan pro Branch und Artifact bleibt immer vollständig.
_Avoid_: Cleanup, Archivierung

### Zugriff

**User**:
Eine über OIDC angemeldete Person.
_Avoid_: Account, Member

**Group**:
Eine Gruppe, der ein User laut Identity Provider angehört.
_Avoid_: Team

**Owner**:
Der User oder die Group, dem ein Project oder Service Account gehört.
_Avoid_: Creator, Maintainer

**Admin**:
User mit Rolle `admin`, sieht und verwaltet alle Projects, Service Accounts und User.
_Avoid_: Superuser, Root

**Visibility**:
Wer ein Project sehen darf: der Owner-User (`user`), eine Group (`group`) oder alle User (`public`).
_Avoid_: Permission, Access level

**Service Account**:
In Trivista angelegte, nicht anmeldefähige Identität eines Owners, die Upload Tokens besitzt.
_Avoid_: Bot, Technical user, Service-User

**Upload Token**:
Einem Service Account zugeordnetes Geheimnis, das ausschließlich Scan-Uploads erlaubt.
_Avoid_: API key, PAT
