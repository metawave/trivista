# Uploads nur über Service Accounts in Trivista

Uploads authentifizieren sich ausschließlich mit Upload Tokens, und jedes Upload Token gehört einem Service Account. Ein Service Account gehört einem Owner (User oder Group) und existiert nur in Trivista, nicht im Identity Provider, weil Uploader auch Externe sein können. Persönliche Tokens sind ein Service Account auf User-Ebene; es gibt nur einen Token-Typ.

Upload Tokens erlauben ausschließlich Scan-Uploads, haben ein optionales Ablaufdatum, sind widerrufbar und werden nur als Hash gespeichert (Klartext einmalig bei Erstellung). Ein Leak aus der CI soll keine Daten lesbar machen; Lesezugriff gibt es nur über die OIDC-Session.

Ein Project wird über Owner und Name identifiziert, der Name ist pro Owner eindeutig. Ein Upload löst `project` im Namensraum des Service-Account-Owners auf und legt es bei Bedarf an. Ein Token kann deshalb nie in ein Project eines anderen Owners schreiben.

## Considered Options

- Service-User als Identität im Identity Provider: verworfen, Externe sind dort nicht abbildbar.
- Persönliche User-Tokens als eigener Typ neben Service-Account-Tokens: verworfen, zwei Konzepte für dieselbe Aufgabe.

## Consequences

- Service Accounts eines Users verwaltet der User, die einer Group jedes aktuelle Mitglied laut Claims; Admins immer.
- Deaktiviert ein Admin einen User, werden dauerhaft alle Tokens seiner Service Accounts und alle von ihm angelegten Tokens widerrufen, auch in Group-Service-Accounts. Group-Service-Accounts selbst bleiben bestehen. Nach einer Reaktivierung sind neue Tokens nötig.
- Die Token-Liste zeigt, wer ein Token angelegt hat und wann es zuletzt benutzt wurde, damit verwaiste Tokens erkennbar sind.
