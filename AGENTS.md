# AGENTS.md

Instructions for AI coding agents working in this repository.

FlowDo (随随办办) is a single-user, LAN-self-hosted, "no-pressure" task manager. One password, no email, no registration; tasks are isolated per Space. The only client is a **web** client (Flutter Web, mobile + desktop browsers) — no Android/iOS/desktop app exists, and `app/` intentionally contains only the `web/` platform directory. Do not re-add other platform directories.

This file is a map and a guardrail. Full rules live in the linked docs; read them before deep work. The existing `.cursor/rules/client-cutoff.mdc` is the authoritative statement of the client/server interaction cutoff — follow it.

## Repository layout

| Path | What it is |
| --- | --- |
| `app/` | Flutter web client. Riverpod 3 + `http` (no Dio) + `speech_to_text` (web voice input). State: Riverpod 3 `Notifier` controllers in `lib/providers.dart`, API layer in `lib/api/`, UI in `lib/ui/`, models in `lib/models/`. Platform abstraction (`_stub`/`_web` files) in `lib/platform/`. Only the `web/` platform directory exists. |
| `server/` | NestJS 11 + Prisma + PostgreSQL 16. Domain modules in `src/` as flat directories (auth, spaces, tasks, briefing, archive, system, instance, notices, users, clock, …). No global prefix — routes are `/auth`, `/tasks`, `/spaces`, `/me`, `/briefing`, `/archive`. |
| `web/` | `nginx.conf` that serves the built `app/web/` output and reverse-proxies API prefixes to the api container. No source code. |
| `docker-compose.yml` | Three services: `db` (postgres:16, volume `flowdo_data`), `api` (mounts the host Docker socket and `.` as `/deploy` for in-app self-update; exposes `:3000`), `web` (nginx, `${WEB_PORT:-8080}`). |
| `start.sh` | One-shot script: `./start.sh` (Docker: build + up -d) or `./start.sh --source` (bare: Postgres in background + nest on `0.0.0.0:3000`), `--stop`, `--reset`. Generates `.env` with `JWT_SECRET`/`WEB_PORT=8080`/`API_PORT=13000` if missing. |
| `.github/workflows/release.yml` | The only workflow. Tag `v*.*.*` → parallel server-image + web-image jobs → release zip + GitHub Release with notes extracted from `CHANGELOG.md`. There is **no PR-level CI** (no lint/test workflow), so pre-check locally. |
| `docs/` | `UI_KIT.md` (design system), `voice_setup.html`, screenshots. |
| `VERSION`, `CHANGELOG.md` | Release version + notes; must stay in sync with the two manifests. |

There is no root `package.json`/lockfile. There are two independent toolchains (npm in `server/`, pub in `app/`).

## Client/server cutoff (the most important rule)

`.cursor/rules/client-cutoff.mdc` (always-on) states the full contract. In short:

- **Server owns** all business rules: permission boundaries, state transitions, focus capacity, archive/delete timing, reminders. The client only does presentation and lightweight validation.
- **Client owns** pure presentation: card appearance, gestures, animations, local drafts.
- **Interaction policy is deliberately split.** The client intercepts *what the user tries to do* (e.g. full focus slot → no swipe-in; in-focus reminder → cannot change priority; done card → detail read-only) and shows its own guidance, never the server's rejection message. The server enforces the *consequence* (capacity, transitions, archive timing, reminders).
- **Some rules are duplicated on both sides** and must be changed together. Canonical pairs:
  - `server/src/tasks/task-status.ts` (`canTransition`/`canEnterFocusManually`/`canChangePriority`) ↔ `app/lib/ui/task_edit_policy.dart`
  - `app/lib/ui/task_gesture_policy.dart` (client-only gestures: swipe targets, press, long-press, drag-to-focus)
  - `server/src/clock/cron.ts` ↔ `app/lib/utils/cron.dart` (reminder scheduling math, crontab parsing)
  - `server/src/clock/lunar.ts` ↔ `app/lib/utils/lunar.dart` (Chinese lunar calendar + auspicious/inauspicious days)
  - `server/src/tasks/priority-order.ts` (`priorityRank`, `comparePriorityThenRecent`) ↔ `app/lib/ui/task_sort.dart` (priority ordering)
- Core invariants: `TODO ↔ FOCUS`, `FOCUS → DONE`, `DONE → TODO / ARCHIVE`; `ARCHIVE` is read-only and deletable only. Reminders (priority `REMINDER`) are scheduled in by the server; they cannot be manually moved into focus. Regular in-focus tasks may only change priority among `HIGH/MEDIUM/LOW`. Done tasks swipe back only to TODO.

When editing any of the paired files above, edit **both** sides in the same change and keep the rules in sync.

## Commands

### Server (`server/`)

```bash
npm run start:dev     # nest start --watch (no prefix; hits /auth /tasks /spaces /me /briefing /archive directly)
npm run build         # nest build → dist/
npm test              # jest, rootDir=src, *.spec.ts only
npm run test:e2e      # jest-e2e, test/ *.e2e-spec.ts
npm run test:cov
npm run lint          # eslint (eslint:fix to auto-fix)
```

Non-Docker dev setup (from CONTRIBUTING.md): `server/.env` is **not** provided as an example file. Copy the env vars from `docker-compose.yml` and build `DATABASE_URL` yourself. Run migrations with `npx prisma db push`; the schema is versionless (no `prisma migrate` history).

Docker is the integration-truth: only the Docker stack has the nginx same-origin proxy (`/tasks`, `/me`, `/briefing`, `/archive`, `/health`, … → `api:3000`), which the client's no-CORS design depends on. A bare `nest` server on `:3000` will not satisfy the client from the Flutter web dev server. Use the full stack for anything that touches the API.

### Client (`app/`)

```bash
flutter analyze       # pre-check (PR gate)
flutter test          # pre-check (PR gate)
flutter build web --release --no-web-resources-cdn   # production web build
```

The client has **no CORS config** — it assumes the web build is served same-origin as the API through nginx. In dev, the Flutter web dev server cannot reach a bare nest server without a proxy.

## Web build — non-obvious gotchas

- **`--no-web-resources-cdn` is mandatory.** Without it, CanvasKit is loaded from `gstatic.com` and breaks in the intranet deployment.
- The whole `app/web/build/web/` output directory must be deployed (`index.html`, `assets/`, `canvaskit/`). Serving only `index.html` yields a white screen.
- `web/nginx.conf` uses `gzip_static` (build with `--base-href /` already produces `.gz`); static hashed assets get `immutable` caching, unhashed entry files get `no-cache`.
- Voice input (`speech_to_text`) requires a secure context: `https://` or `localhost`. On an intranet `http://<IP>:8080` the browser blocks the mic; see `DEPLOY.md` (Chrome/Edge `--unsafely-treat-insecure-origin-as-secure` flag or an HTTPS reverse proxy).
- Fonts: Noto Sans SC + ZCOOL KuaiLe are bundled (tens of MB); avoid adding more web fonts lightly.

## Release flow

There is no PR CI. The release pipeline is version-driven:

1. Bump `VERSION`, `app/pubspec.yaml` (`version: x.y.z+build`) and `server/package.json` to the same `x.y.z`.
2. Update `CHANGELOG.md` (the tag pipeline extracts release notes from it).
3. Commit `chore(release): vX.Y.Z` (and `chore: fix X.Y` for a patch-only bump).
4. `git tag vX.Y.Z && git push origin vX.Y.Z` — `release.yml` then builds the server image, the web image (running `flutter analyze && flutter test` + `flutter build web`), the release zip, and the GitHub Release.

Conventional Commits are expected (`feat:`/`fix:`/`refactor:`/`chore:`, scoped as appropriate).

## Design system

`docs/UI_KIT.md` is the reference for any new screen. Key rules: use `Theme.of(context).colorScheme` and `context.flowColors` (never `Colors.white` or fixed hex); pull spacing/radii/motion from `app/lib/theme/app_tokens.dart` (`AppSpacing`, `AppRadii`, `AppMotion`); icons via Material Rounded/Outlined in `FlowDoIconTile`. Priority colors are fixed across themes (high/mid/low/none/reminder). There is also a `.cursor/skills/ui-ux-pro-max/` design-system skill available in Cursor for richer UI work.

## Data model notes (Prisma)

- `Instance` is a **single row** (PK id=1) holding `passwordHash`, `mustChangePassword`, `activeSpaceId` — the "single password, no accounts" design. There is no user table.
- `Space` carries per-space knobs: `archiveAfterDays` (default 7), `focusLimit` (default 3), `deleteArchivedAfterDays` (default 30; 0 = keep forever).
- `Task` has `status` (TODO/FOCUS/DONE/ARCHIVE) and `priority` (NONE/HIGH/MEDIUM/LOW/REMINDER) enums, plus `remind*` fields and `dueAt`/`completedAt`.
- Schema is applied with `prisma db push` (no migration history) — see `server/docker-entrypoint.sh`, which also force-resolves `db` to IPv4 to avoid an IPv6 P1001 hang.

## Conventions

- Code identifiers and commits are English; user-facing strings and docs are Chinese.
- Timezones: `tzOffset` is **minutes** relative to UTC, defaulting to `+480` (China) when absent.
- The API container mounts the host Docker socket and the repo (`/deploy`) to support in-app self-update (About page) — it can update container images and rewrite compose files. Container updates persist; orchestration changes apply on the next `start.sh`.
- Read `README.md` (product behavior + state-flow rules), `CONTRIBUTING.md` (full dev/release rules), `DEPLOY.md` (deployment, forgot-password SQL, voice setup), and `.cursor/rules/client-cutoff.mdc` before substantive changes.
