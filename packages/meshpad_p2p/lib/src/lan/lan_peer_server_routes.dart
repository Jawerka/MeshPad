part of 'lan_peer_server.dart';

extension _LanPeerServerRoutes on LanPeerServer {
  Future<_HttpResponse> _handleHealthRoute() async {
    String? peerId;
    String? displayName;
    try {
      final engine = await _getEngine();
      peerId = engine.identity.peerId;
      displayName = engine.identity.displayName;
    } on Object {
      // Liveness must succeed even when the engine is not ready (tests / startup).
    }
    return _HttpResponse.json({
      'status': 'ok',
      if (peerId != null) 'peer_id': peerId,
      if (displayName != null) 'display_name': displayName,
      if (tlsIdentity != null) ...{
        'tls': true,
        'tls_cert_sha256': tlsIdentity!.certSha256Hex,
        if (tlsPort != null) 'tls_port': tlsPort,
      },
    });
  }

  Future<_HttpResponse> _handleCatalogRoute(HttpRequest request) async {
    final engine = await _getEngine();
    final localPeerId = engine.identity.peerId;
    final catalog = await engine.localCatalog();
    final acceptGzip = !requestWantsPayloadEncryption(
          request.headers.value(meshpadPayloadEncHeader),
        ) &&
        lanCatalogAcceptsGzip(
          request.headers.value(HttpHeaders.acceptEncodingHeader),
        );
    final encoded = encodeLanCatalogBody(
      catalog,
      useGzip: acceptGzip,
    );
    final jsonText = utf8.decode(
      encoded.gzipped ? gzip.decode(encoded.bytes) : encoded.bytes,
    );
    return _encryptedOrPlainJson(
      request: request,
      jsonText: jsonText,
      localPeerId: localPeerId,
      plainBytes: encoded.bytes,
      plainHeaders: encoded.gzipped
          ? {
              'content-type': 'application/json; charset=utf-8',
              'content-encoding': lanCatalogGzipEncoding,
            }
          : {'content-type': 'application/json; charset=utf-8'},
    );
  }

  Future<_HttpResponse> _handleGetNoteRoute(
    HttpRequest request,
    String suffix,
  ) async {
    if (suffix.contains('/attachments/')) {
      return _getAttachment(suffix);
    }
    final engine = await _getEngine();
    final localPeerId = engine.identity.peerId;
    final snapshot = await engine.exportNote(suffix);
    if (snapshot == null) {
      return _HttpResponse(statusCode: 404, body: 'note not found');
    }
    return _encryptedOrPlainJson(
      request: request,
      jsonText: jsonEncode(remoteSnapshotToJson(snapshot)),
      localPeerId: localPeerId,
    );
  }

  Future<_HttpResponse> _handlePutNoteRoute(
    HttpRequest request,
    String id,
  ) async {
    if (id.contains('/attachments/')) {
      return _putAttachment(request, id);
    }
    final body = await utf8.decoder.bind(request).join();
    final engine = await _getEngine();
    final localPeerId = engine.identity.peerId;
    final clearBody = await _decryptRequestBody(request, body, localPeerId);
    final snapshot = tryParseRemoteSnapshotJson(jsonDecode(clearBody));
    if (snapshot == null) {
      return _HttpResponse(statusCode: 400, body: 'invalid note payload');
    }
    if (snapshot.meta.id != id) {
      return _HttpResponse(statusCode: 400, body: 'id mismatch');
    }
    final result = await engine.applyRemote(snapshot);
    return _encryptedOrPlainJson(
      request: request,
      jsonText: jsonEncode({'result': noteApplyResultWire(result)}),
      localPeerId: engine.identity.peerId,
    );
  }

  Future<_HttpResponse> _handlePairingOfferRoute() async {
    final offer = _pairingOffer;
    if (offer == null || offer.isExpired) {
      if (offer != null && offer.isExpired) {
        _pairingOffer = null;
      }
      return _HttpResponse(statusCode: 404, body: 'no active offer');
    }
    return _HttpResponse.json(offer.toJson());
  }

  Future<_HttpResponse> _handleCascadeRoute(HttpRequest request) async {
    CascadeSyncRequest cascadeRequest = const CascadeSyncRequest();
    try {
      final body = await utf8.decoder.bind(request).join();
      if (body.trim().isNotEmpty) {
        final json = jsonDecode(body) as Map<String, dynamic>;
        cascadeRequest = CascadeSyncRequest.fromWire(json);
      }
    } catch (_) {
      cascadeRequest = const CascadeSyncRequest();
    }
    final handler = onCascadeSyncRequested;
    if (handler != null) {
      unawaited(handler(cascadeRequest));
    }
    return _HttpResponse.json({'status': 'accepted'});
  }

  Future<_HttpResponse> _handlePairingConfirmRoute(HttpRequest request) async {
    final clientKey = pairingClientKeyFromAddress(
      request.connectionInfo?.remoteAddress,
    );
    if (_pairingRateLimiter.isBlocked(clientKey)) {
      MeshPadLog.warn('pairing', 'confirm rate limited for $clientKey');
      return _HttpResponse(statusCode: 429, body: 'rate limited');
    }

    final body = await utf8.decoder.bind(request).join();
    Map<String, dynamic>? confirmJson;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        confirmJson = decoded;
      }
    } on Object {
      return _HttpResponse(statusCode: 400, body: 'invalid pairing payload');
    }
    if (confirmJson == null) {
      return _HttpResponse(statusCode: 400, body: 'invalid pairing payload');
    }
    final confirm = PinPairingConfirm.fromJson(confirmJson);
    final offer = _pairingOffer;
    if (offer == null ||
        offer.isExpired ||
        offer.pin != confirm.pin ||
        offer.peerId != confirm.peerId) {
      _pairingRateLimiter.recordFailure(clientKey);
      return _HttpResponse(statusCode: 403, body: 'invalid pin');
    }
    if (validatePairingPin != null && !validatePairingPin!(confirm.pin)) {
      _pairingRateLimiter.recordFailure(clientKey);
      return _HttpResponse(statusCode: 403, body: 'invalid pin');
    }
    _pairingOffer = null;
    _pairingRateLimiter.recordSuccess(clientKey);
    MeshPadLog.pairing(
      'PIN confirmed for ${confirm.peerId} by '
      '${confirm.initiatorPeerId ?? 'unknown initiator'}',
    );
    if (onPairingConfirmed != null) {
      await onPairingConfirmed!(confirm);
    }
    return _HttpResponse.json({'status': 'trusted'});
  }
}
