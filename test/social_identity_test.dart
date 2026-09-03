import 'package:flutter_test/flutter_test.dart';
import 'package:nus/core/social/social_identity.dart';

void main() {
  group('SocialIdentity', () {
    test('normalizes valid identity fields and preserves the canonical values', () {
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
      expect(identity.avatarUrl, 'https://example.com/avatar.png');
      expect(identity.coverUrl, 'https://example.com/cover.png');
      expect(identity.websiteUrl, 'https://example.com');
      expect(identity.isVerified, isTrue);
    });

    test('rejects invalid usernames, empty display names, unsafe URLs, and invalid clear requests', () {
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

      final SocialIdentity identity = SocialIdentity(
        id: 'u1',
        username: 'valid_user',
        displayName: 'User',
        avatarUrl: 'https://example.com/avatar.png',
      );

      expect(
        () => identity.copyWith(
          avatarUrl: 'https://example.com/other.png',
          clearAvatarUrl: true,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('round trips through JSON, supports explicit nullable-field clearing, and remains immutable', () {
      final SocialIdentity original = SocialIdentity(
        id: 'u1',
        username: 'valid_user',
        displayName: 'User',
        bio: 'Original',
        avatarUrl: 'https://example.com/avatar.png',
        websiteUrl: 'https://example.com',
        isVerified: false,
      );

      final SocialIdentity restored = SocialIdentity.fromJson(original.toJson());
      final SocialIdentity updated = original.copyWith(
        displayName: 'Updated User',
        isVerified: true,
        clearAvatarUrl: true,
        clearWebsiteUrl: true,
      );

      expect(restored, equals(original));
      expect(restored.hashCode, equals(original.hashCode));
      expect(updated.id, original.id);
      expect(updated.username, original.username);
      expect(updated.displayName, 'Updated User');
      expect(updated.avatarUrl, isNull);
      expect(updated.websiteUrl, isNull);
      expect(updated.isVerified, isTrue);
      expect(original.displayName, 'User');
      expect(original.avatarUrl, 'https://example.com/avatar.png');
      expect(original.websiteUrl, 'https://example.com');
      expect(original.isVerified, isFalse);
    });
  });
}
