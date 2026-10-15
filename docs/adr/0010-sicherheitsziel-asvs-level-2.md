# Sicherheitsziel: OWASP ASVS 5.0 Level 2

Trivista hält Schwachstellen- und Secret-Funde ganzer Teams und nimmt Uploads von CI-Systemen mit langlebigen Tokens an. Ein kompromittierter Zugang legt offen, wo Systeme angreifbar sind. Deshalb erfüllt Trivista OWASP ASVS 5.0 Level 2 und mitigiert die OWASP Top 10 (Ausgabe 2025). Level 3 wird nur umgesetzt, wo es billig ist.

Gemessen wird gegen die Anforderungen von ASVS 5.0.0 mit ihren IDs. Was der Identity Provider (Pocket ID), der Ingress oder der Cluster leisten muss, ist Teil des Ziels, wird aber im Deployment-Repo umgesetzt; `docs/security.md` hält fest, welche Anforderung wo erfüllt wird und welche Abweichungen bewusst akzeptiert sind.

## Considered Options

- Kein formales Ziel, nur Reviews nach konkreten Angriffen: verworfen. So blieben im MVP Anforderungen ohne konkreten Angriffspfad unbemerkt, etwa ein serverseitig beendetes Logout, ein Idle-Timeout, Security-Header und Audit-Ereignisse.
- ASVS Level 1: verworfen, deckt Session-Management, Logging und Konfiguration zu wenig ab für Daten dieser Sensibilität.
- ASVS Level 3: verworfen, verlangt unter anderem adaptive Zugriffskontrollen und Defense-in-Depth, die für ein internes Tool unverhältnismässig sind.

## Consequences

- Neue Funktionen und ADRs prüfen die betroffenen ASVS-Kapitel mit; eine Abweichung wird mit Begründung in `docs/security.md` festgehalten, nicht stillschweigend in Kauf genommen.
- Für Standardanliegen wie Sessions, CSP oder Rate-Limiting gelten die Rails-Bordmittel (AGENTS.md).
- Eine vollständige Verifikation gegen ASVS wird wiederholt, wenn sich Authentisierung, Upload-Pfad oder Deployment wesentlich ändern.
