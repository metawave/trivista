# Login ausschließlich über OIDC, Rollen und Groups aus Claims

Trivista hat keinen eigenen Passwort-Login und pflegt keine Gruppen. Login läuft nur über OIDC (`omniauth_openid_connect`); Groups kommen aus dem `groups`-Claim, die Rolle `admin` aus einer konfigurierbaren Group oder einem Rollen-Claim. Claim-Namen sind konfigurierbar, weil `groups` kein OIDC-Standard-Claim ist und im Identity Provider eingerichtet werden muss. Groups und Rolle werden bei jedem Login aktualisiert. Optional beschränkt eine konfigurierbare Login-Group den Zugang: Wer nicht Mitglied ist, erhält `403`, und es wird kein User angelegt. Ein User ist über `(iss, sub)` identifiziert, nicht über E-Mail. Eine Group ist über ihren Claim-Wert identifiziert; der Identity Provider muss stabile Werte liefern (IDs oder nie wiederverwendete Namen), sonst erbt eine neue Group Projects und Service Accounts einer alten. Ein optionaler, konfigurierbarer Claim liefert Anzeigenamen für Groups, wenn der Identity Provider IDs liefert; ohne ihn zeigt die UI den Claim-Wert.

Sessions laufen nach maximal 8 Stunden ab (konfigurierbar), damit entzogene Groups und Rollen spätestens dann wirken. Die Deaktivierung eines Users wird bei jedem Request geprüft und beendet bestehende Sessions sofort.

## Consequences

- Ein Admin kann User deaktivieren und reaktivieren. Deaktivierte User können sich nicht anmelden, auch nicht mit gültiger OIDC-Identität.
- Ohne korrekt konfigurierten Identity Provider ist Trivista nicht nutzbar. Nicht-menschliche Uploader laufen über Service Accounts (ADR 0005).
