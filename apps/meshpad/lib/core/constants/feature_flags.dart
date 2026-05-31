/// Product feature toggles (temporary until post-MVP work lands).
abstract final class MeshPadFeatureFlags {
  /// libp2p push/pull (B.2) is not ready; hide transport choice in settings.
  /// Dev override: `--dart-define=MESHPAD_SYNC_TRANSPORT=libp2p`.
  static const libp2pTransportSettingVisible = false;
}
