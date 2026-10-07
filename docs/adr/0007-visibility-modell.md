# Owner und Visibility pro Project

Ein Project gehört einem User oder einer Group. Die Visibility ist `user` (nur der Owner-User), `group` (Mitglieder einer Group) oder `public` (alle angemeldeten User, nie anonym). User-Projects starten mit `user`. Group-Projects starten mit `group`, und `group` meint bei ihnen immer die Owner-Group; `user` gibt es nur für User-Projects. Admins sehen alle Projects. Nicht sichtbare Projects antworten mit `404`, nicht `403`, damit ihre Existenz nicht offengelegt wird.

Verwalten heißt: Visibility und Default Branch setzen, Service Accounts und Tokens verwalten sowie Projects, Repos, Branches und einzelne Scans löschen. Berechtigt sind der Owner-User bzw. die Mitglieder der Owner-Group und Admins. Gelöscht wird samt Occurrences und nicht mehr referenzierten Findings; Projects, Repos und Branches werden durch Eintippen des Namens bestätigt. Löschen ist nötig, weil Projects, Repos und Branches beim Upload automatisch entstehen und Tippfehler sonst dauerhaft bleiben, weil ein geleaktes Token gefälschte Scans einschleusen kann und weil die Quote (ADR 0004) sonst ohne Ausweg bliebe. Jeder Scan zeigt, welcher Service Account ihn hochgeladen hat.

## Consequences

- Group-Projects verwaltet jedes aktuelle Mitglied der Owner-Group laut Claims; Admins immer. Verschwindet eine Group aus dem Identity Provider, bleiben ihre Projects und Service Accounts bestehen und sind nur noch durch Admins verwaltbar.
- Bei User-Projects hängt die Group am Project. Verliert der Owner die Group, bleibt das Project für sie sichtbar; ändern kann er sie nur auf eine seiner aktuellen Groups.
- Gleichnamige Projects verschiedener Owner sind möglich; die UI zeigt deshalb den Owner mit an.
