# Git sync (secondary channel)

MeshPad 1.0 adds optional **Git sync** for desktop (Windows/Linux). LAN sync remains primary.

## Repository layout

Mirror of local notes **without attachments**:

```text
notes/<uuid>/note.md
notes/<uuid>/meta.json
```

Git metadata lives in `<dataDir>/.git-sync/` (separate from LAN wire format).

## Setup (desktop)

1. Create a **private** GitHub repository.
2. Register a **GitHub OAuth App** (one-time):
   - GitHub → **Settings** → **Developer settings** → **OAuth Apps** → **New OAuth App**
   - Enable **Device Flow** (checkbox on the app settings page)
   - Scopes are requested at login (`repo` for private repositories)
   - Copy **Client ID** (public; no secret needed for Device Flow on desktop)
3. In MeshPad **Settings** → **Git sync**:
   - Paste repository URL: `https://github.com/user/repo.git`
   - Paste **GitHub OAuth Client ID**
   - Tap **Войти через GitHub** → browser opens → enter the device code
4. Enable **Git sync**; use header icons: cloud download = **pull**, cloud upload = **push**.

Alternative: build with embedded Client ID:

```powershell
flutter run -d windows --dart-define=MESHPAD_GITHUB_CLIENT_ID=Ov23liYourClientId
```

Token is stored in OS secure storage (`flutter_secure_storage`). Sign out via **Выйти** in settings.

## Behavior

| Action | When |
|--------|------|
| Pull | App start; every N minutes (default 5); header button |
| Push | Header button (manual) |

Android: Git sync UI shows «скоро» — use LAN on mobile.

## LAN independence

Git and LAN operate independently. Git never uploads `attachments/` or `.thumbs/`.

See [ARCHITECTURE.md](ARCHITECTURE.md), [DEVELOPMENT.md](DEVELOPMENT.md).
