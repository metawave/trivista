# Login ausschließlich über OIDC, Rollen und Groups aus Claims

Trivista hat keinen eigenen Passwort-Login und pflegt keine Gruppen. Login läuft nur über OIDC (`omniauth_openid_connect`); Groups kommen aus dem `groups`-Claim, die Rolle `admin` aus einer konfigurierbaren Group oder einem Rollen-Claim. Claim-Namen sind konfigurierbar, weil `groups` kein OIDC-Standard-Claim ist und im Identity Provider eingerichtet werden muss. Groups und Rolle werden bei jedem Login aktualisiert. Ein User ist über `(iss, sub)` identifiziert, nicht über E-Mail. Eine Group ist über ihren Claim-Wert identifiziert; der Identity Provider muss stabile Werte liefern (IDs oder nie wiederverwendete Namen), sonst erbt eine neue Group Projects und Service Accounts einer alten.

Sessions laufen nach maximal 8 Stunden ab (konfigurierbar), damit entzogene Groups und Rollen spätestens dann wirken. Die Deaktivierung eines Users wird bei jedem Request geprüft und beendet bestehende Sessions sofort.

## Consequences

- Ein Admin kann User deaktivieren und reaktivieren. Deaktivierte User können sich nicht anmelden, auch nicht mit gültiger OIDC-Identität.
- Ein Admin kann den Owner eines Projects übertragen, auch zwischen User und Group. Bei Transfer auf eine Group wird Visibility `user` zu `group`. Hat der neue Owner bereits ein gleichnamiges Project, schlägt der Transfer fehl. Service Accounts werden nicht übertragen; die CI braucht danach ein Token des neuen Owners. Der alte Owner-Namensraum merkt sich den übertragenen Namen: Ein Upload darauf legt kein neues Project an, sondern antwortet `409` mit Hinweis auf den neuen Owner, damit die Historie nicht still in zwei Projects zerfällt. Diese Sperre greift nur, solange im Namensraum kein Project dieses Namens existiert; sie entfällt beim Rücktransfer und wenn das übertragene Project gelöscht wird, und Admins können sie aufheben. Ein bewusst gelöschtes Project entsteht beim nächsten Upload dagegen normal neu.
- Ohne korrekt konfigurierten Identity Provider ist Trivista nicht nutzbar. Nicht-menschliche Uploader laufen über Service Accounts (ADR 0005).
