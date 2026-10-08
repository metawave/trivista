# Hierarchie Project → Repo → Branch → Scan, Trends pro Branch und Artifact

Branch ist eine eigene Ebene und kein Label am Scan, weil Historie pro Branch gelesen wird. Jeder Scan hat genau ein Artifact. Trends und Diffs gelten pro Branch und Artifact, damit z. B. Filesystem- und Image-Scans desselben Branches nicht vermischt werden.

Ein Artifact ist durch Kategorie und `ArtifactName` ohne Tag oder Digest identifiziert. Die Kategorie entspricht `ArtifactType`, nur `filesystem` und `repository` bilden gemeinsam die Kategorie `source`, weil Trivy ab 0.68 `trivy fs .` in einem Git-Checkout als `repository` meldet und ein Upgrade sonst die Historie spaltet; der gemeldete Typ wird zusätzlich gespeichert. Ohne Kürzung wäre jeder neue Image-Tag ein neues Artifact ohne Predecessor. Gekürzt wird nur bei `container_image`: zuerst alles ab `@` (Digest), dann `:…` nur nach dem letzten `/`, damit ein Registry-Port (`registry:5000/app:1.2`) erhalten bleibt.

Predecessor ist der letzte Scan desselben Branches und Artifacts nach Upload-Zeitpunkt und ID; er wird beim Lesen bestimmt. Mehrere Scans pro Commit sind erlaubt.

Jedes Repo hat einen Default Branch: `main`, sonst `master`, sonst der erste hochgeladene Branch; änderbar durch Verwaltungsberechtigte (ADR 0007). Solange er nicht manuell gesetzt ist, wird diese Regel bei jedem neuen Branch neu angewendet, ein später hochgeladener `main` übernimmt also. Wird der Default Branch gelöscht, gilt wieder die automatische Regel. Die Zähler der Projektliste summieren den letzten Scan pro Artifact auf den Default Branches, damit Findings aus Feature-Branches nicht mehrfach zählen; Artifacts ohne Scan in den letzten 30 Tagen (konfigurierbar) zählen nicht mehr. Dieselbe Regel gilt für die aktuellen Findings eines Branches und für den Trend eines Projects, der sie pro Tag anwendet; massgebend ist der heutige Default Branch.

## Phase 2: Cluster

`trivy k8s` passt später so: Ein Cluster wird als eigenes Project abgebildet, dessen Scans direkt am Project hängen und je Kubernetes-Resource ein Artifact enthalten. Dafür wird die Beziehung Scan → Artifact per Migration auf 1..n erweitert; Zähler, Predecessor und Trend gelten dann pro Cluster-Project und Artifact.

## Consequences

- Ein umbenannter Branch beginnt eine neue Historie; in Git gelöschte Branches bleiben erhalten, bis sie in Trivista gelöscht werden (ADR 0007).
- Zwei verschiedene Images mit gleichem Namen ohne Tag gelten als dasselbe Artifact; unterschiedlich geschriebene Referenzen auf dasselbe Image (`app` vs. `registry.example.com/app`) als verschiedene.
- Kein stabiler Trend bei Image-Tar-Inputs mit Version im Dateinamen und bei fs-Scans, deren Pfad Build-IDs enthält. Die README empfiehlt `trivy fs .`; ein optionales Upload-Feld `artifact`, das den Namen überschreibt, ist der Upgrade-Pfad. Solche verwaisten Artifacts fallen nach 30 Tagen aus den Zählern der Projektliste.
