import 'package:flutter_test/flutter_test.dart';
import 'package:nus/core/social/social_identity.dart';

void main() {
  group('SocialIdentity', () {
    test('normalizes valid username and preserves a valid immutable identity', () {
      final SocialIdentity identity = SocialIdentity(
        id: ' user-001 ',
        username: ' Talaat_Nus ',
        displayName: ' Talaat Moussa ',
        bio: 'NUS account',
        avatarUrl: 'https://example.com/avatar.png',
        coverUrl: 'https://example.com/cover.png',
        websiteUrl: 'https://example.com',
        isVerified: true,
      );

      expect(identity.id, 'user-001');
      expect(identity.username, 'talaat_nus');
      expect(identity.displayName, 'Talaat Moussa');
      expect(identity.bio, 'NUS account');
      expect(identity.isVerified, isTrue);
    });

    test('rejects invalid usernames, empty display names, and unsafe URLs', () {
      expect(
        () => SocialIdentity(
          id: 'u1',
          username: 'ab',
          displayName: 'User',
        ),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => SocialIdentity(
          id: 'u1',
          username: 'valid_user',
          displayName: '   ',
        ),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => SocialIdentity(
          id: 'u1',
          username: 'valid_user',
          displayName: 'User',
          websiteUrl: 'javascript:alert(1)',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('round trips through JSON and copyWith without changing equality semantics', () {
      final SocialIdentity original = SocialIdentity(
        id: 'u1',
        username: 'valid_user',
        displayName: 'User',
        bio: 'Original',
        isVerified: false,
      );

      final SocialIdentity restored = SocialIdentity.fromJson(original.toJson());
      final SocialIdentity updated = original.copyWith(
        displayName: 'Updated User',
        isVerified: true,
      );

      expect(restored, equals(original));
      expect(restored.hashCode, equals(original.hashCode));
      expect(updated.id, original.id);
      expect(updated.username, original.username);
      expect(updated.displayName, 'Updated User');
      expect(updated.isVerified, isTrue);
      expect(original.displayName, 'User');
      expect(original.isVerified, isFalse);
    });
  });
}
