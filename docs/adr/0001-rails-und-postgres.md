# Rails 8 mit Postgres als Stack

Trivista ist eine Rails-8-App (Hotwire, Chart.js, Solid Queue, Solid Cache) auf Postgres, ausgeliefert als ein Docker-Image für Kubernetes. Rails, weil der Entwickler es beherrscht und OIDC, Jobs und ORM mitbringt; Go wurde erwogen, bringt hier aber keinen zwingenden Vorteil. Postgres, weil es in der Betriebsumgebung bereits existiert und Rolling Updates mit mehreren Replicas erlaubt (SQLite hieße ein Pod mit RWO-PVC).

Queue und Cache liegen in der primary-DB, Solid Cable entfällt. So werden Scan und Import-Job in einer Transaktion geschrieben, und es kann keinen verwaisten Scan ohne Job geben. Dafür wird der Import-Job innerhalb der Transaktion eingereiht, nicht erst nach dem Commit (`enqueue_after_transaction_commit` für diesen Job aus), und `config.solid_queue.connects_to` wird entfernt, damit Solid Queue die Connection der App nutzt; nur dann liegt der Enqueue in derselben Transaktion. Ein Test sichert ab, dass ein Rollback auch den Job verwirft.

## Considered Options

- Rails-8-Standard mit eigenen DBs für queue, cache und cable: verworfen. Die separate Queue-DB macht Scan-Speicherung und Enqueue nicht-atomar und erfordert einen Recovery-Job; Cable hat keinen Anwendungsfall. Die Solid-Queue-README unterstützt die Single-DB-Konfiguration ausdrücklich.

## Consequences

- Eine DB pro Umgebung; der DB-User braucht kein `CREATEDB`, wenn die DB vorab existiert.
- Solid Queue läuft via `SOLID_QUEUE_IN_PUMA` in jeder Replica mit. Keine Phased Restarts; Puma und Supervisor stoppen gemeinsam. DB-Connections pro Replica (Puma-Threads plus Worker) zählen gegen `max_connections`.
- Solid Cache dient als `cache_store`, den `rate_limit` (ADR 0004) braucht.
