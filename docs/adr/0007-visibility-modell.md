# Owner und Visibility pro Project

Ein Project gehört einem User oder einer Group. Die Visibility ist `user` (nur der Owner-User), `group` (Mitglieder einer Group) oder `public` (alle angemeldeten User, nie anonym). User-Projects starten mit `user`. Group-Projects starten mit `group`, und `group` meint bei ihnen immer die Owner-Group; `user` gibt es nur für User-Projects. Admins sehen alle Projects. Nicht sichtbare Projects antworten mit `404`, nicht `403`, damit ihre Existenz nicht offengelegt wird.

Verwalten heißt: Visibility und Default Branch setzen, Service Accounts und Tokens verwalten sowie Projects, Repos und Branches löschen. Berechtigt sind der Owner-User bzw. die Mitglieder der Owner-Group und Admins. Gelöscht wird samt Scans, Occurrences, nicht mehr referenzierten Findings und Roh-JSON, bestätigt durch Eintippen des Namens; einzelne Scans sind nicht löschbar. Löschen ist nötig, weil Projects, Repos und Branches beim Upload automatisch entstehen und Tippfehler sonst dauerhaft bleiben.

## Consequences

- Group-Projects verwaltet jedes aktuelle Mitglied der Owner-Group laut Claims; Admins immer. Verschwindet eine Group aus dem Identity Provider, bleiben ihre Projects und Service Accounts bestehen und sind nur noch durch Admins verwaltbar.
- Bei User-Projects hängt die Group am Project. Verliert der Owner die Group, bleibt das Project für sie sichtbar; ändern kann er sie nur auf eine seiner aktuellen Groups.
- Gleichnamige Projects verschiedener Owner sind möglich; die UI zeigt deshalb den Owner mit an.
