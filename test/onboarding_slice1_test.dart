import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nus/features/onboarding/application/household_profile_repository.dart';
import 'package:nus/features/onboarding/application/household_profile_validator.dart';
import 'package:nus/features/onboarding/domain/household_profile.dart';
import 'package:nus/features/onboarding/presentation/auth_gate.dart';
import 'package:nus/features/onboarding/presentation/auth_page.dart';
import 'package:nus/features/onboarding/presentation/household_onboarding_page.dart';
import 'package:nus/core/auth/auth_repository.dart';
import 'package:nus/core/auth/auth_state.dart';

void main() {
  group('Slice 1 domain', () {
    const validator = HouseholdProfileValidator();

    test('accepts a complete real household profile', () {
      const profile = HouseholdProfile(
        userId: 'u1', countryCode: 'EG', region: 'Cairo', currencyCode: 'EGP',
        householdSize: 4, adults: 2, children: 2, housingType: 'rent',
        incomeFrequency: 'monthly', monthlyIncome: 10000, recurringObligations: 3000,
      );
      expect(validator.isValid(profile), isTrue);
      final summary = InitialFinancialSummary.fromProfile(profile);
      expect(summary.monthlyIncome, 10000);
      expect(summary.recurringObligations, 3000);
      expect(summary.remainingAfterObligations, 7000);
    });

    test('rejects impossible counts, invalid currency, and negative money', () {
      const profile = HouseholdProfile(
        userId: 'u1', countryCode: 'EG', region: null, currencyCode: 'BAD',
        householdSize: 4, adults: 3, children: -1, housingType: 'rent',
        incomeFrequency: 'monthly', monthlyIncome: 0, recurringObligations: -1,
      );
      final result = validator.validate(profile);
      expect(result.isValid, isFalse);
      expect(result.errors.keys, containsAll(<String>['currency', 'householdSize', 'children', 'monthlyIncome', 'recurringObligations']));
    });
  });

  testWidgets('unauthenticated user is routed to registration/login', (tester) async {
    final auth = FakeAuthRepository(const UnauthenticatedAuthState());
    await tester.pumpWidget(_host(AuthGate(authRepository: auth, profileRepository: FakeProfileRepository())));
    await tester.pumpAndSettle();
    expect(find.text('إنشاء الحساب'), findsOneWidget);
    expect(find.text('لديك حساب بالفعل؟ تسجيل الدخول'), findsOneWidget);
  });

  testWidgets('new authenticated user is routed to household onboarding', (tester) async {
    final auth = FakeAuthRepository(_authenticatedState());
    await tester.pumpWidget(_host(AuthGate(authRepository: auth, profileRepository: FakeProfileRepository())));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('household-onboarding-page')), findsOneWidget);
    expect(find.byType(HouseholdOnboardingPage), findsOneWidget);
  });

  testWidgets('existing valid profile bypasses onboarding and opens the NUS household shell', (tester) async {
    final auth = FakeAuthRepository(_authenticatedState());
    final profiles = FakeProfileRepository()..profile = _profile();
    await tester.pumpWidget(_host(AuthGate(
      authRepository: auth,
      profileRepository: profiles,
      scheduleStore: ScheduleStore(),
      medicationService: FakeMedicationLifecycleService(),
    )));
    await tester.pumpAndSettle();

    expect(find.text('متنساش مواعيدك'), findsOneWidget);
    expect(find.text('اقتصاد البيت تحت السيطرة'), findsOneWidget);
    expect(find.byTooltip('اسأل NUS'), findsOneWidget);
    expect(find.text('NUS Copilot', skipOffstage: false), findsNothing);
    expect(find.text('إعداد بيتك', skipOffstage: false), findsNothing);
    expect(find.byType(HouseholdOnboardingPage), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('registration flow calls the existing email registration boundary', (tester) async {
    var called = false;
    await tester.pumpWidget(MaterialApp(home: AuthPage(onSignUp: (email, password) async {
      called = email == 'new@example.com' && password == 'secret1';
      return true;
    })));
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'new@example.com');
    await tester.enterText(fields.at(1), 'secret1');
    await tester.enterText(fields.at(2), 'secret1');
    await tester.tap(find.text('إنشاء الحساب'));
    await tester.pumpAndSettle();
    expect(called, isTrue);
  });

  testWidgets('login explains an unconfirmed email instead of showing a generic network error', (tester) async {
    await tester.pumpWidget(MaterialApp(home: AuthPage(
      onSignIn: (email, password) async {
        throw Exception('Email not confirmed');
      },
    )));

    await tester.tap(find.text('لديك حساب بالفعل؟ تسجيل الدخول'));
    await tester.pump();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'user@example.com');
    await tester.enterText(fields.at(1), 'secret1');
    await tester.tap(find.text('تسجيل الدخول'));
    await tester.pumpAndSettle();

    expect(find.textContaining('البريد الإلكتروني لم يتم تأكيده بعد'), findsOneWidget);
    expect(find.textContaining('راجع الاتصال والإعدادات'), findsNothing);
  });

  testWidgets('login explains network failures separately from auth failures', (tester) async {
    await tester.pumpWidget(MaterialApp(home: AuthPage(
      onSignIn: (email, password) async {
        throw Exception('SocketException: Failed host lookup');
      },
    )));

    await tester.tap(find.text('لديك حساب بالفعل؟ تسجيل الدخول'));
    await tester.pump();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'user@example.com');
    await tester.enterText(fields.at(1), 'secret1');
    await tester.tap(find.text('تسجيل الدخول'));
    await tester.pumpAndSettle();

    expect(find.textContaining('تعذر الاتصال بالشبكة'), findsOneWidget);
    expect(find.textContaining('البريد الإلكتروني لم يتم تأكيده بعد'), findsNothing);
  });

  test('profile payload remains valid through the domain parser', () {
    final parsed = HouseholdProfile.fromJson(_profile().toJson());
    expect(parsed, _profile());
  });
}

Widget _host(Widget child) => MaterialApp(
      home: Directionality(textDirection: TextDirection.rtl, child: child),
    );

HouseholdProfile _profile() => const HouseholdProfile(
      userId: 'u1',
      countryCode: 'EG',
      region: 'Cairo',
      currencyCode: 'EGP',
      householdSize: 4,
      adults: 2,
      children: 2,
      housingType: 'rent',
      incomeFrequency: 'monthly',
      monthlyIncome: 10000,
      recurringObligations: 3000,
    );

AuthState _authenticatedState() => const AuthenticatedAuthState(
      session: FakeSession(userId: 'u1'),
    );

class FakeSession implements Session {
  const FakeSession({required this.userId});
  final String userId;
  @override
  String get accessToken => 'test-token';
  @override
  dynamic get user => _FakeUser(userId);
}

class _FakeUser {
  const _FakeUser(this.id);
  final String id;
}

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository(this.state);
  final AuthState state;
  @override
  Stream<AuthState> get authStateChanges => Stream<AuthState>.empty();
  @override
  Future<AuthState> initialize() async => state;
  @override
  Future<void> signOut() async {}
  @override
  Future<void> dispose() async {}
}

class FakeProfileRepository implements HouseholdProfileRepository {
  HouseholdProfile? profile;
  @override
  Future<HouseholdProfile?> load(String userId) async => profile;
  @override
  Future<HouseholdProfile> save(HouseholdProfile profile) async {
    this.profile = profile;
    return profile;
  }
}
