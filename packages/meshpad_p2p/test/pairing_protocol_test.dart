import 'package:meshpad_p2p/meshpad_p2p.dart';
import 'package:test/test.dart';

void main() {
  group('PairingConfirmRateLimiter', () {
    test('blocks after max failures within window', () {
      var now = DateTime.utc(2026, 5, 31, 12);
      final limiter = PairingConfirmRateLimiter(
        maxAttempts: 3,
        window: const Duration(minutes: 1),
        now: () => now,
      );

      expect(limiter.isBlocked('client-a'), isFalse);
      limiter.recordFailure('client-a');
      limiter.recordFailure('client-a');
      expect(limiter.isBlocked('client-a'), isFalse);
      limiter.recordFailure('client-a');
      expect(limiter.isBlocked('client-a'), isTrue);
    });

    test('success clears failure bucket', () {
      final limiter = PairingConfirmRateLimiter(maxAttempts: 2);
      limiter.recordFailure('client-a');
      limiter.recordFailure('client-a');
      expect(limiter.isBlocked('client-a'), isTrue);

      limiter.recordSuccess('client-a');
      expect(limiter.isBlocked('client-a'), isFalse);
    });

    test('old failures fall outside window', () {
      var now = DateTime.utc(2026, 5, 31, 12);
      final limiter = PairingConfirmRateLimiter(
        maxAttempts: 2,
        window: const Duration(minutes: 1),
        now: () => now,
      );

      limiter.recordFailure('client-a');
      limiter.recordFailure('client-a');
      expect(limiter.isBlocked('client-a'), isTrue);

      now = now.add(const Duration(minutes: 2));
      expect(limiter.isBlocked('client-a'), isFalse);
    });
  });

  group('createPairingOffer', () {
    test('uses default TTL', () {
      final before = DateTime.now().toUtc();
      final offer = createPairingOffer(
        peerId: 'peer-a',
        displayName: 'A',
        pin: '123456',
      );
      final after = DateTime.now().toUtc().add(pairingOfferTtl);

      expect(offer.expiresAt.isAfter(before), isTrue);
      expect(offer.expiresAt.isBefore(after.add(const Duration(seconds: 2))),
          isTrue);
    });
  });
}
