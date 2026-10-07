# Design System

Dense, read-only developer UI: severity first, structure through borders. Three places hold it:

- `app/assets/stylesheets/application.css` is the source of truth in code. Values (colors, sizes, radii) live only there as `:root` tokens; reference tokens and existing classes, add a token before adding a raw value.
- `/design` (development and test only, no login) renders every token, class and markup helper live; check new UI against it.
- `docs/design/` holds the sources of the Design canvas (https://claude.ai/artifact/MvLViJxrbTiST39eCe5vj9): `canvas.json` plus one `.dc.html` per artboard. They need the canvas runtime to render; republish them to a Design canvas to view or edit them.

## Color

- Severity owns the warm colors. Fills and on-colors come from `--sev-<level>` / `--sev-<level>-on`; the scale runs dark (CRITICAL) to light (UNKNOWN) so it reads in grayscale, and every severity mark carries its label or letter.
- One accent (`--accent`) for links, primary actions, focus, selection and "new".
- "No longer reported" stays neutral gray: it is not proof of a fix (CONTEXT.md: Diff), so it never borrows a success color.
- Destructive actions are text-colored buttons (`btn--danger`) behind a typed-name confirmation (`confirmed?`), keeping red fills for severity.

## Type and layout

- IBM Plex Sans for UI, IBM Plex Mono for anything a developer copies: SHAs, IDs, versions, paths, image refs, names of repos, branches and service accounts. Self-hosted in `app/assets/fonts` (OFL).
- Controls are 36 px (`--control-height`), small ones 32 px. Pages use `.page` (1360 px), `.page--narrow` for settings and lists, `.page--form` for single forms.
- Every page works at 375 px: wide tables sit in `.table-scroll`, toolbars wrap.

## Filtering

Filters are links, one query param each, preserving the other params; no `<select>` with an Apply button.

- Finding type: `.tabs` with `.tab[aria-current=page]` and a `.count`.
- Single choice (range, visibility): `.segmented` links with `aria-current="true"`.
- Toggles (severity, trigger, only new): `.toggle` links with `aria-current="true"|"false"`; several severities travel as one comma list (`?severity=HIGH,LOW`).

Forms that change data (settings, tokens, service accounts) keep regular fields in `.field` with a visible label.

## Building blocks

Helpers render the recurring pieces; reach for them before writing markup: `severity_counts`, `severity_badge`, `diff_chips`, `icon`, `logo`, `copy_button`, `nav_link`, `owner_label`, `visibility_label`. Inline SVG icons live in `ApplicationHelper::ICONS` (24 px stroke icons, `aria-hidden`). Icon-only buttons get an `aria-label`.

## Changing the system

Change canvas, CSS and styleguide together: a new pattern gets drawn in the canvas's Components artboard (and its source copied to `docs/design/`), a class in `application.css`, an example on `/design`, then used in views.
