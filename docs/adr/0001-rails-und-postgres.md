# Rails 8 mit Postgres als Stack

Trivista ist eine Rails-8-App (Hotwire, Chart.js, Solid Queue) auf Postgres, ausgeliefert als ein Docker-Image für Kubernetes. Rails, weil der Entwickler es beherrscht und OIDC, Jobs und ORM mitbringt; Go wurde erwogen, bringt hier aber keinen zwingenden Vorteil. Postgres, weil es in der Betriebsumgebung bereits existiert und Rolling Updates mit mehreren Replicas erlaubt (SQLite hieße ein Pod mit RWO-PVC).

## Considered Options

- Eine einzige DB für App, Queue, Cache und Cable: verworfen zugunsten des Rails-Standards; die Solid-Queue-README empfiehlt eine separate Queue-DB.

## Consequences

- Datenbanken nach Rails-8-Standard: primary, queue, cache und cable als eigene DBs auf derselben Postgres-Instanz. `db:prepare` legt fehlende DBs an; ohne `CREATEDB` müssen sie vorab existieren.
- Solid Queue läuft via `SOLID_QUEUE_IN_PUMA` in jeder Replica mit. Keine Phased Restarts; Puma und Supervisor stoppen gemeinsam. DB-Connections pro Replica (Puma-Threads plus Worker) zählen gegen `max_connections`.
