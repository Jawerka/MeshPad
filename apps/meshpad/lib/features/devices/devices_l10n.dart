import 'package:meshpad_p2p/meshpad_p2p.dart';

import '../../l10n/app_localizations.dart';

extension ManualLanPeerProbeErrorL10n on ManualLanPeerProbeError {
  String message(AppLocalizations l10n) => switch (this) {
        ManualLanPeerProbeError.emptyHost => l10n.devicesManualErrorEmptyHost,
        ManualLanPeerProbeError.invalidPort =>
          l10n.devicesManualErrorInvalidPort,
        ManualLanPeerProbeError.unreachable =>
          l10n.devicesManualErrorUnreachable,
        ManualLanPeerProbeError.webUnsupported => l10n.devicesWebUnsupported,
      };
}
