# Changelog

## [Unreleased]

### Added

- Expanded `PLAN.md` with architecture, testing, sprints, risks.
- Monorepo: `packages/meshpad_core`, `packages/meshpad_p2p`, `apps/meshpad`.
- Dev tooling: Melos, CI, setup scripts, EditorConfig, VS Code settings.
- Core: `NoteMeta`, file repository, LWW merge, unit tests.
- Git repository, Android AVD `MeshPad_API36`, `scripts/launch-emulator.ps1`.
- **Sprint 1:** Drift DB, `NoteRepository` (FS + index), models Device/SyncEvent.
- **Sprint 2:** Chat UI — sidebar, feed, composer, inline edit, trash, Markdown preview.
- **Sprint 3:** Attachments, image preview/lightbox, FTS search, sync outbox indicator, trash TTL purge.
- **Sprint 4 (partial):** Device identity, SyncEngine with LWW/tombstone, FakeSyncHub, devices sheet UI, outbox retry and sync status badges.
- **Sprint 5 (partial):** Windows/Linux system tray, settings sheet, customizable data directory, auto-sync loop, rebuild index, Android Share-to, WorkManager background maintenance, headless HTTP server (`apps/meshpad_server`), Web client via `meshpad_api_client`.
- **Sprint 6 (partial):** Manual update check in settings, LAN discovery stub UI, lazy paginated feed, MeshPadException and sync error messages, PIN pairing protocol models, update download link, attachment copy progress UI.
