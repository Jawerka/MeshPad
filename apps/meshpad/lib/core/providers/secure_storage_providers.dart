import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/secure_git_token_store.dart';

final secureGitTokenStoreProvider = Provider<SecureGitTokenStore>(
  (ref) => SecureGitTokenStore(),
);
