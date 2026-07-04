import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'hub_pairing_service.dart';
import 'hub_qr.dart';

class HubWeb {
  HubWeb({required this.pairing});

  final HubPairingService pairing;

  Router buildRouter({required int webPort}) {
    final router = Router();

    router.get('/', (_) => _index(webPort));
    router.get('/hub/status', (_) => _status(webPort));
    router.get('/hub/qr.png', (_) => _qrPng());
    router.get('/hub/qr.svg', (_) => _qrSvg());
    router.post('/hub/sync', (_) => _syncNow());
    router.post('/hub/pairing/refresh', (_) async {
      await pairing.refreshPairing();
      return _status(webPort);
    });

    return router;
  }

  Future<Response> _status(int webPort) async {
    final status = await pairing.status(webPort: webPort);
    return Response.ok(
      jsonEncode(status.toJson()),
      headers: _jsonHeaders,
    );
  }

  Future<Response> _syncNow() async {
    final result = await pairing.runSyncNow();
    final status = await pairing.status();
    return Response.ok(
      jsonEncode({
        'result': result.status.name,
        'note_count': result.noteCount,
        'message': result.message,
        'status': status.toJson(),
      }),
      headers: _jsonHeaders,
    );
  }

  Future<Response> _qrPng() async {
    final status = await pairing.status();
    final uri = status.qrUri;
    if (uri == null) {
      return Response(404, body: 'pairing inactive');
    }
    return Response.ok(
      qrDataToPng(uri),
      headers: {
        'content-type': 'image/png',
        'cache-control': 'no-cache',
      },
    );
  }

  Future<Response> _qrSvg() async {
    final status = await pairing.status();
    final uri = status.qrUri;
    if (uri == null) {
      return Response(404, body: 'pairing inactive');
    }
    return Response.ok(
      qrDataToSvg(uri),
      headers: {
        'content-type': 'image/svg+xml; charset=utf-8',
        'cache-control': 'no-cache',
      },
    );
  }

  Future<Response> _index(int webPort) async {
    final status = await pairing.status(webPort: webPort);
    final pin = status.pin ?? '------';
    final lanHost = status.lanHost ?? '…';
    final syncPort = status.httpPort?.toString() ?? '45838';
    final qrSrc = status.qrUri == null
        ? ''
        : '/hub/qr.png?pin=${Uri.encodeComponent(pin)}';

    final html = '''
<!DOCTYPE html>
<html lang="ru">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>MeshPad Hub</title>
  <style>
    :root {
      color-scheme: light dark;
      font-family: system-ui, -apple-system, sans-serif;
      --bg: #f4f4f5; --card: #fff; --text: #111; --muted: #666;
      --ok: #16a34a; --warn: #ca8a04; --err: #dc2626; --wait: #64748b;
    }
    @media (prefers-color-scheme: dark) {
      :root { --bg: #18181b; --card: #27272a; --text: #fafafa; --muted: #a1a1aa; }
    }
    * { box-sizing: border-box; }
    body {
      margin: 0; min-height: 100vh; background: var(--bg); color: var(--text);
      display: flex; align-items: flex-start; justify-content: center; padding: 1rem;
    }
    main {
      width: 100%; max-width: 420px; background: var(--card);
      border-radius: 16px; padding: 1.25rem 1.5rem 1.5rem;
      box-shadow: 0 4px 24px rgba(0,0,0,.08);
    }
    h1 { font-size: 1.35rem; margin: 0 0 .2rem; text-align: center; }
    .sub { color: var(--muted); font-size: .9rem; margin-bottom: .75rem; text-align: center; }
    .badge {
      display: flex; align-items: center; gap: .55rem;
      padding: .65rem .85rem; border-radius: 10px; font-size: .88rem;
      margin-bottom: 1rem; background: rgba(128,128,128,.08);
    }
    .dot { width: 10px; height: 10px; border-radius: 50%; flex-shrink: 0; }
    .dot.ok { background: var(--ok); }
    .dot.partial { background: var(--warn); }
    .dot.error { background: var(--err); }
    .dot.waiting, .dot.idle, .dot.syncing { background: var(--wait); }
    .dot.syncing { animation: pulse 1s infinite alternate; }
    @keyframes pulse { from { opacity: .35; } to { opacity: 1; } }
    .stats {
      display: grid; grid-template-columns: 1fr 1fr 1fr; gap: .5rem;
      margin-bottom: 1rem; text-align: center; font-size: .78rem; color: var(--muted);
    }
    .stats strong { display: block; font-size: 1.15rem; color: var(--text); }
    .section-title {
      font-size: .75rem; text-transform: uppercase; letter-spacing: .04em;
      color: var(--muted); margin: .75rem 0 .35rem;
    }
    .hint { font-size: .85rem; color: var(--muted); margin-bottom: .75rem; line-height: 1.4; text-align: center; }
    .qr-wrap {
      display: flex; justify-content: center; padding: 12px; background: #fff;
      border-radius: 12px; margin-bottom: .5rem; min-height: 268px; align-items: center;
    }
    .qr-wrap img { width: 240px; height: 240px; image-rendering: pixelated; }
    .pin {
      text-align: center; font-size: 2.4rem; letter-spacing: .28em; font-weight: 700;
      font-variant-numeric: tabular-nums; margin: .35rem 0 .75rem;
    }
    .devices, .log { list-style: none; padding: 0; margin: 0; font-size: .82rem; }
    .devices li, .log li {
      padding: .45rem 0; border-bottom: 1px solid rgba(128,128,128,.15);
      display: flex; justify-content: space-between; gap: .5rem;
    }
    .devices li:last-child, .log li:last-child { border-bottom: none; }
    .dev-ok { color: var(--ok); }
    .dev-fail { color: var(--err); }
    .dev-idle { color: var(--muted); }
    .log time { color: var(--muted); white-space: nowrap; font-size: .75rem; }
    .actions { display: flex; gap: .5rem; margin-top: 1rem; flex-wrap: wrap; }
    button {
      flex: 1; min-width: 120px; padding: .55rem .9rem; font-size: .9rem;
      border-radius: 8px; border: 1px solid rgba(128,128,128,.35);
      background: transparent; color: inherit; cursor: pointer;
    }
    button:hover { background: rgba(128,128,128,.12); }
    button:disabled { opacity: .5; cursor: default; }
    button.primary { background: #2563eb; color: #fff; border-color: #2563eb; }
    button.primary:hover { background: #1d4ed8; }
    .err { color: var(--err); font-size: .85rem; text-align: center; }
  </style>
</head>
<body>
  <main>
    <h1>MeshPad Hub</h1>
    <p class="sub">${_escapeHtml(status.displayName)}</p>

    <div class="badge" id="sync-badge">
      <span class="dot ${_escapeHtml(status.syncBadgeKind)}" id="sync-dot"></span>
      <span id="sync-text">${_escapeHtml(status.syncBadgeText)}</span>
    </div>

    <div class="stats">
      <div><strong id="stat-notes">${status.noteCount}</strong>заметок</div>
      <div><strong id="stat-outbox">${status.pendingOutbox}</strong>в очереди</div>
      <div><strong id="stat-devices">${status.trustedCount}</strong>устройств</div>
    </div>

    <p class="hint">Отсканируйте QR в MeshPad<br>или введите PIN вручную</p>
    ${qrSrc.isEmpty ? '<p class="err">Pairing недоступен — подождите…</p>' : '<div class="qr-wrap"><img id="qr" src="$qrSrc" width="240" height="240" alt="QR pairing"></div>'}
    <div class="pin" id="pin">$pin</div>
    <div style="text-align:center;font-size:.82rem;color:var(--muted);margin-bottom:.5rem">
      LAN: <strong>${_escapeHtml(lanHost)}:$syncPort</strong>
    </div>

    <div class="section-title">Устройства</div>
    <ul class="devices" id="devices">${_devicesHtml(status)}</ul>

    <div class="section-title">Журнал</div>
    <ul class="log" id="log">${_logHtml(status)}</ul>

    <div class="actions">
      <button type="button" class="primary" id="sync-btn" onclick="syncNow()">Синхронизировать</button>
      <button type="button" onclick="refreshPin()">Новый PIN</button>
    </div>
  </main>
  <script>
    function fmtTime(iso) {
      if (!iso) return '—';
      try { return new Date(iso).toLocaleString('ru-RU', { hour: '2-digit', minute: '2-digit', day: '2-digit', month: '2-digit' }); }
      catch (_) { return iso; }
    }
    function devIcon(ok) {
      if (ok === true) return '<span class="dev-ok">✓ sync</span>';
      if (ok === false) return '<span class="dev-fail">✗ offline</span>';
      return '<span class="dev-idle">—</span>';
    }
    function renderDevices(list) {
      const el = document.getElementById('devices');
      if (!list || !list.length) {
        el.innerHTML = '<li><span class="dev-idle">Пока нет — подключите через QR</span></li>';
        return;
      }
      el.innerHTML = list.map(d =>
        '<li><span>' + escapeHtml(d.name) + '</span>' + devIcon(d.last_sync_ok) + '</li>'
      ).join('');
    }
    function renderLog(events) {
      const el = document.getElementById('log');
      if (!events || !events.length) {
        el.innerHTML = '<li><span class="dev-idle">Событий пока нет</span></li>';
        return;
      }
      el.innerHTML = events.map(e =>
        '<li><span>' + escapeHtml(e.message) + '</span><time>' + fmtTime(e.at) + '</time></li>'
      ).join('');
    }
    function escapeHtml(s) {
      return String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');
    }
    function applyStatus(s) {
      if (s.pin) document.getElementById('pin').textContent = s.pin;
      const img = document.getElementById('qr');
      if (img && s.pin) img.src = '/hub/qr.png?pin=' + encodeURIComponent(s.pin) + '&t=' + Date.now();
      document.getElementById('stat-notes').textContent = s.note_count ?? 0;
      document.getElementById('stat-outbox').textContent = s.pending_outbox ?? 0;
      document.getElementById('stat-devices').textContent = s.trusted_count ?? 0;
      const dot = document.getElementById('sync-dot');
      dot.className = 'dot ' + (s.sync_badge_kind || 'idle');
      document.getElementById('sync-text').textContent = s.sync_badge_text || '—';
      document.getElementById('sync-btn').disabled = !!s.syncing;
      renderDevices(s.trusted_devices);
      renderLog(s.recent_events);
    }
    async function refreshStatus() {
      const r = await fetch('/hub/status');
      applyStatus(await r.json());
    }
    async function refreshPin() {
      await fetch('/hub/pairing/refresh', { method: 'POST' });
      await refreshStatus();
    }
    async function syncNow() {
      const btn = document.getElementById('sync-btn');
      btn.disabled = true;
      document.getElementById('sync-dot').className = 'dot syncing';
      document.getElementById('sync-text').textContent = 'Синхронизация…';
      try {
        const r = await fetch('/hub/sync', { method: 'POST' });
        const body = await r.json();
        if (body.status) applyStatus(body.status);
      } finally {
        btn.disabled = false;
      }
    }
    setInterval(refreshStatus, 10000);
  </script>
</body>
</html>
''';

    return Response.ok(
      html,
      headers: {'content-type': 'text/html; charset=utf-8'},
    );
  }

  static String _devicesHtml(HubStatus status) {
    if (status.trustedDevices.isEmpty) {
      return '<li><span class="dev-idle">Пока нет — подключите через QR</span></li>';
    }
    final sb = StringBuffer();
    for (final d in status.trustedDevices) {
      final mark = switch (d.lastSyncOk) {
        true => '<span class="dev-ok">✓ sync</span>',
        false => '<span class="dev-fail">✗ offline</span>',
        null => '<span class="dev-idle">—</span>',
      };
      sb.writeln(
        '<li><span>${_escapeHtml(d.name)}</span>$mark</li>',
      );
    }
    return sb.toString();
  }

  static String _logHtml(HubStatus status) {
    if (status.recentEvents.isEmpty) {
      return '<li><span class="dev-idle">Событий пока нет</span></li>';
    }
    final sb = StringBuffer();
    for (final e in status.recentEvents) {
      final t = e.at.toLocal();
      final time =
          '${t.day.toString().padLeft(2, '0')}.${t.month.toString().padLeft(2, '0')} '
          '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
      sb.writeln(
        '<li><span>${_escapeHtml(e.message)}</span><time>$time</time></li>',
      );
    }
    return sb.toString();
  }

  static const _jsonHeaders = {
    'content-type': 'application/json; charset=utf-8',
  };

  static String _escapeHtml(String raw) {
    return raw
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;');
  }
}
