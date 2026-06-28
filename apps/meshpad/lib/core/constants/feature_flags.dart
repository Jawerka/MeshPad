/// Product feature toggles (temporary until post-MVP work lands).
abstract final class MeshPadFeatureFlags {
  /// libp2p transport removed from production (ADR 0003). Always false.
  static const libp2pTransportSettingVisible = false;
}
