# Trivista

Rails 8 / PostgreSQL app that collects Trivy reports from CI and shows the finding history per project. Vocabulary lives in `CONTEXT.md`, decisions in `docs/adr/`: read the ADR of an area before changing it, and record a decision that departs from an ADR as a new or updated ADR.

## Commands

- Setup: `mise install`, then start Postgres with `docker run -d --name trivista-postgres -e POSTGRES_PASSWORD=postgres -p 127.0.0.1:55432:5432 postgres:18`. Development env vars come from `[env]` in `mise.toml`; run commands through `mise exec --` unless mise is activated in the shell.
- Done means `mise exec -- bin/ci` is green: setup, RuboCop, bundler-audit, importmap audit, Brakeman, tests, seeds.
- Single test: `mise exec -- bin/rails test test/models/upload_test.rb -n /quota/`
- Trivy report fixtures: `script/generate_trivy_fixtures` (needs Docker).

## Conventions

- Code and specs move together. The specs are `CONTEXT.md`, `docs/adr/`, `docs/design-system.md` and the README sections on configuration and the upload API. A change to behavior or vocabulary updates code, tests and every affected spec in the same commit, and a spec change brings code and tests along; search the specs for the changed term before committing. `docs/plan.md` is the completed MVP plan and stays as written.
- Test-first. Every security- or data-relevant rule (authorization, allowlist, locks, quota) has a test that turns red when the rule is removed; confirm it by removing the rule once.
- Authorization goes through scopes: `Project.visible_to` / `manageable_by`, nested records through their own `visible_to`. Records outside the scope answer 404.
- Trivy data enters only through the `TrivyReport` allowlist (ADR 0003); logs and error messages carry generic text, report content stays out of them.
- Failures surface: explicit status codes and exceptions; DB constraints and counters stay strict instead of being clamped.
- UI and styling (views, CSS, helpers that render markup): follow `docs/design-system.md`.
- A change to UI or behavior that shows on a page also refreshes the README screenshots: run `mise exec -- bin/screenshots`, review `docs/screenshots/` and commit them with the change. A new screen worth showing gets its own capture in `test/system/readme_screenshots_test.rb` and a line in the README section.
- Integration tests sign in with `sign_in(sub:, groups:)` from `test/test_helper.rb` (OmniAuth test mode) and build on `test/fixtures`.

## Gotchas

- Minitest 6 has no `stub`; swap the collaborator explicitly (for example `Rails.cache = ActiveSupport::Cache::NullStore.new`, restored in `ensure`).
- The app refuses to boot without `OIDC_LOGIN_GROUP`, also for `bin/rails runner` and `console`.
- Puma enforces the upload body limit before Rails; Rails-level size checks come too late.
- Production assumes TLS (`assume_ssl`); signing in to the production image over plain http fails the CSRF origin check.
- Chart.js is a vendored bundled ESM build (`vendor/javascript/chart.js.js`); `bin/importmap pin chart.js` fetches builds that load chunks by relative path and break.
- Concurrent writes that read state first (tokens, default branch, quota) lock the row with `lock!` / `with_lock` and re-check under the lock.
