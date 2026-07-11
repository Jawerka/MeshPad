import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'hub_pairing_service.dart';
import 'hub_info.dart';
import 'hub_qr.dart';
import 'hub_update_checker.dart';

class HubWeb {
  HubWeb({
    required this.pairing,
    HubUpdateChecker? updateChecker,
  }) : _updateChecker = updateChecker ?? HubUpdateChecker();

  final HubPairingService pairing;
  final HubUpdateChecker _updateChecker;

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
    router.post('/hub/devices/<peerId>/revoke',
        (Request request, String peerId) {
      return _revokeDevice(webPort, peerId);
    });
    router.post('/hub/devices/revoke-all', (_) {
      return _revokeAllDevices(webPort);
    });
    router.post('/hub/updates/check', (_) => _checkUpdates());

    return router;
  }

  Map<String, dynamic> _statusJson(HubStatus status, {int? webPort}) {
    final json = status.toJson();
    json['hub_version'] = kHubVersion;
    if (webPort != null) {
      json['web_port'] = webPort;
    }
    return json;
  }

  Future<Response> _checkUpdates() async {
    final result = await _updateChecker.check();
    return Response.ok(
      jsonEncode(result.toJson()),
      headers: _jsonHeaders,
    );
  }

  Future<Response> _revokeDevice(int webPort, String peerId) async {
    final ok = await pairing.revokeTrustedDevice(peerId);
    if (!ok) {
      return Response.notFound(
        jsonEncode({'error': 'device_not_found'}),
        headers: _jsonHeaders,
      );
    }
    return _status(webPort);
  }

  Future<Response> _revokeAllDevices(int webPort) async {
    final count = await pairing.revokeAllTrustedDevices();
    return Response.ok(
      jsonEncode({
        'revoked': count,
        'status': _statusJson(await pairing.status(webPort: webPort),
            webPort: webPort),
      }),
      headers: _jsonHeaders,
    );
  }

  Future<Response> _status(int webPort) async {
    final status = await pairing.status(webPort: webPort);
    return Response.ok(
      jsonEncode(_statusJson(status, webPort: webPort)),
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
        'status': _statusJson(status),
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
    final lanHost = status.lanHost ?? '…';
    final syncPort = status.httpPort?.toString() ?? '45838';

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
      display: flex; justify-content: space-between; align-items: center; gap: .5rem;
    }
    .dev-actions { display: flex; align-items: center; gap: .35rem; flex-shrink: 0; }
    .dev-revoke {
      padding: .2rem .45rem; font-size: .72rem; min-width: auto; flex: none;
      border-radius: 6px; color: var(--err); border-color: rgba(220,38,38,.35);
    }
    .dev-revoke:hover { background: rgba(220,38,38,.08); }
    .devices li:last-child, .log li:last-child { border-bottom: none; }
    .dev-ok { color: var(--ok); }
    .dev-fail { color: var(--err); }
    .dev-idle { color: var(--muted); }
    .log time { color: var(--muted); white-space: nowrap; font-size: .75rem; }
    .actions { display: flex; gap: .5rem; margin: 1rem 0; flex-wrap: wrap; }
    .pairing-panel[hidden] { display: none; }
    #pairing-hint { margin-bottom: .75rem; }
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
    .version { font-size: .78rem; color: var(--muted); }
    .modal-backdrop {
      position: fixed; inset: 0; background: rgba(0,0,0,.45);
      display: flex; align-items: center; justify-content: center;
      padding: 1rem; z-index: 100;
    }
    .modal-backdrop[hidden] { display: none; }
    .modal {
      width: 100%; max-width: 400px; max-height: 85vh; overflow: auto;
      background: var(--card); border-radius: 14px; padding: 1.1rem 1.25rem;
      box-shadow: 0 8px 32px rgba(0,0,0,.2);
    }
    .modal h2 { margin: 0 0 .65rem; font-size: 1.1rem; }
    .modal p { margin: 0 0 .75rem; font-size: .9rem; line-height: 1.45; }
    .modal .whats-new {
      font-size: .82rem; line-height: 1.45; white-space: pre-wrap;
      max-height: 240px; overflow: auto; padding: .65rem .75rem;
      border-radius: 8px; background: rgba(128,128,128,.08); margin-bottom: .75rem;
    }
    .modal-actions { display: flex; gap: .5rem; justify-content: flex-end; flex-wrap: wrap; }
    .modal-actions a.btn {
      display: inline-block; text-decoration: none; text-align: center;
      padding: .55rem .9rem; font-size: .9rem; border-radius: 8px;
      background: #2563eb; color: #fff; border: 1px solid #2563eb;
    }
    .modal-actions a.btn:hover { background: #1d4ed8; }
  </style>
</head>
<body>
  <main>
    <h1>MeshPad Hub</h1>
    <p class="sub">${_escapeHtml(status.displayName)}<br><span class="version">v${_escapeHtml(kHubVersion)}</span></p>

    <div class="badge" id="sync-badge">
      <span class="dot ${_escapeHtml(status.syncBadgeKind)}" id="sync-dot"></span>
      <span id="sync-text">${_escapeHtml(status.syncBadgeText)}</span>
    </div>

    <div class="stats">
      <div><strong id="stat-notes">${status.noteCount}</strong>заметок</div>
      <div><strong id="stat-outbox">${status.pendingOutbox}</strong>в очереди</div>
      <div><strong id="stat-devices">${status.trustedCount}</strong>устройств</div>
    </div>

    <p class="hint" id="pairing-hint">Нажмите «Показать PIN и QR», чтобы подключить новое устройство.</p>
    <div id="pairing-panel" class="pairing-panel" hidden>
      <p class="hint">Отсканируйте QR в MeshPad<br>или введите PIN вручную</p>
      <div class="qr-wrap"><img id="qr" width="240" height="240" alt="QR pairing"></div>
      <div class="pin" id="pin">------</div>
      <div style="text-align:center;font-size:.82rem;color:var(--muted);margin-bottom:.5rem">
        LAN: <strong id="lan-endpoint">${_escapeHtml(lanHost)}:$syncPort</strong>
      </div>
    </div>

    <div class="section-title">Устройства</div>
    <ul class="devices" id="devices">${_devicesHtml(status)}</ul>
    <div class="actions" id="device-actions" style="margin-top:.35rem;margin-bottom:.75rem;${status.trustedCount == 0 ? 'display:none' : ''}">
      <button type="button" class="dev-revoke" id="revoke-all-btn" onclick="revokeAllDevices()">Отвязать все</button>
    </div>

    <div class="actions">
      <button type="button" class="primary" id="show-pairing-btn" onclick="showPairing()">Показать PIN и QR</button>
      <button type="button" class="primary" id="sync-btn" onclick="syncNow()">Синхронизировать</button>
      <button type="button" id="refresh-pin-btn" onclick="refreshPin()">Новый PIN</button>
      <button type="button" id="update-btn" onclick="checkUpdates()">Проверить обновления</button>
    </div>

    <div class="section-title">Журнал</div>
    <ul class="log" id="log">${_logHtml(status)}</ul>
  </main>
  <div class="modal-backdrop" id="update-modal" hidden>
    <div class="modal" role="dialog" aria-labelledby="update-modal-title">
      <h2 id="update-modal-title">Обновления</h2>
      <p id="update-modal-message"></p>
      <div class="whats-new" id="update-modal-notes" hidden></div>
      <p id="update-modal-hint" style="font-size:.8rem;color:var(--muted)" hidden>
        Скачайте бинарник, замените <code>/usr/local/bin/meshpad-hub</code> и выполните
        <code>systemctl restart meshpad-hub</code>.
      </p>
      <div class="modal-actions">
        <a class="btn" id="update-download-btn" href="#" target="_blank" rel="noopener" hidden>Скачать hub</a>
        <button type="button" onclick="closeUpdateModal()">Закрыть</button>
      </div>
    </div>
  </div>
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
      const actions = document.getElementById('device-actions');
      if (!list || !list.length) {
        el.innerHTML = '<li><span class="dev-idle">Пока нет — подключите через QR</span></li>';
        if (actions) actions.style.display = 'none';
        return;
      }
      if (actions) actions.style.display = '';
      el.innerHTML = list.map(d =>
        '<li><span>' + escapeHtml(d.name) + '</span><span class="dev-actions">' +
        devIcon(d.last_sync_ok) +
        '<button type="button" class="dev-revoke" onclick="revokeDevice(' +
        JSON.stringify(d.peer_id) + ',' + JSON.stringify(d.name) + ')">Отвязать</button>' +
        '</span></li>'
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
    function pairingVisible() {
      const panel = document.getElementById('pairing-panel');
      return panel && !panel.hidden;
    }
    let lastPairingEventAt = null;
    function showPairing() {
      document.getElementById('pairing-panel').hidden = false;
      document.getElementById('pairing-hint').hidden = true;
      document.getElementById('show-pairing-btn').hidden = true;
      refreshStatus();
    }
    function applyStatus(s) {
      const pairingEvent = s.recent_events && s.recent_events.find(e => e.kind === 'pairing');
      if (pairingEvent && pairingEvent.at !== lastPairingEventAt) {
        lastPairingEventAt = pairingEvent.at;
        showPairing();
      } else if ((s.trusted_count ?? 0) === 0 && !pairingVisible()) {
        showPairing();
      }
      if (pairingVisible()) {
        if (s.pin) document.getElementById('pin').textContent = s.pin;
        const img = document.getElementById('qr');
        if (img && s.pin) {
          img.src = '/hub/qr.png?pin=' + encodeURIComponent(s.pin) + '&t=' + Date.now();
        }
        if (s.lan_host && s.http_port) {
          document.getElementById('lan-endpoint').textContent = s.lan_host + ':' + s.http_port;
        }
      }
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
      showPairing();
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
    async function revokeDevice(peerId, name) {
      if (!confirm('Отвязать устройство «' + name + '»? Его нужно будет подключить заново.')) return;
      const r = await fetch('/hub/devices/' + encodeURIComponent(peerId) + '/revoke', { method: 'POST' });
      if (r.ok) applyStatus(await r.json());
    }
    async function revokeAllDevices() {
      if (!confirm('Отвязать все устройства? Для синхронизации потребуется сопряжение заново.')) return;
      const r = await fetch('/hub/devices/revoke-all', { method: 'POST' });
      if (r.ok) {
        const body = await r.json();
        if (body.status) applyStatus(body.status);
      }
    }
    function closeUpdateModal() {
      document.getElementById('update-modal').hidden = true;
    }
    function showUpdateModal(body) {
      const modal = document.getElementById('update-modal');
      const title = document.getElementById('update-modal-title');
      const message = document.getElementById('update-modal-message');
      const notes = document.getElementById('update-modal-notes');
      const hint = document.getElementById('update-modal-hint');
      const download = document.getElementById('update-download-btn');
      const current = body.current_version || '—';
      if (body.status === 'upToDate') {
        title.textContent = 'Обновления';
        message.textContent = 'Установлена актуальная версия v' + current + '.';
        notes.hidden = true;
        hint.hidden = true;
        download.hidden = true;
      } else if (body.status === 'updateAvailable') {
        title.textContent = 'Доступно обновление';
        message.textContent = 'Текущая v' + current + ' → новая v' + (body.latest_version || '?') + '.';
        if (body.whats_new_markdown) {
          notes.textContent = body.whats_new_markdown;
          notes.hidden = false;
        } else {
          notes.hidden = true;
        }
        if (body.download_url) {
          download.href = body.download_url;
          download.hidden = false;
          hint.hidden = false;
        } else {
          download.hidden = true;
          hint.hidden = true;
          if (body.message) message.textContent += ' ' + body.message;
        }
      } else {
        title.textContent = 'Обновления';
        message.textContent = body.message || 'Не удалось проверить обновления.';
        notes.hidden = true;
        hint.hidden = true;
        download.hidden = true;
      }
      modal.hidden = false;
    }
    async function checkUpdates() {
      const btn = document.getElementById('update-btn');
      btn.disabled = true;
      try {
        const r = await fetch('/hub/updates/check', { method: 'POST' });
        showUpdateModal(await r.json());
      } catch (e) {
        showUpdateModal({ status: 'unavailable', message: String(e) });
      } finally {
        btn.disabled = false;
      }
    }
    setInterval(refreshStatus, 10000);
    refreshStatus();
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
        '<li><span>${_escapeHtml(d.name)}</span>'
        '<span class="dev-actions">$mark'
        '<button type="button" class="dev-revoke" '
        'onclick="revokeDevice(\'${_escapeHtml(d.peerId)}\', \'${_escapeHtml(d.name)}\')">'
        'Отвязать</button></span></li>',
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
