# Rails 8 mit Postgres als Stack

Trivista ist eine Rails-8-App (Hotwire, Chart.js, Solid Cache) auf Postgres, ausgeliefert als ein Docker-Image für Kubernetes. Rails, weil der Entwickler es beherrscht und OIDC und ORM mitbringt; Go wurde erwogen, bringt hier aber keinen zwingenden Vorteil. Postgres, weil es in der Betriebsumgebung bereits existiert und Rolling Updates mit mehreren Replicas erlaubt (SQLite hieße ein Pod mit RWO-PVC).

Eine einzige DB pro Umgebung. Solid Cache liegt in der primary-DB und dient als `cache_store`, den `rate_limit` (ADR 0004) braucht. Solid Queue und Solid Cable entfallen, weil der Import synchron läuft (ADR 0004) und es keinen Anwendungsfall für Broadcasts gibt.

## Considered Options

- Rails-8-Standard mit eigenen DBs für queue, cache und cable: verworfen, ohne Hintergrund-Jobs und Broadcasts ohne Nutzen.

## Consequences

- Der DB-User braucht kein `CREATEDB`, wenn die DB vorab existiert.
- DB-Connections pro Replica (Puma-Threads) zählen gegen `max_connections`.
