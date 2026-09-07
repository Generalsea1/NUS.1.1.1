import 'dart:async';

import 'package:flutter/material.dart';
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

  testWidgets('existing valid profile bypasses onboarding', (tester) async {
    final auth = FakeAuthRepository(_authenticatedState());
    final profiles = FakeProfileRepository()..profile = _profile();
    await tester.pumpWidget(_host(AuthGate(authRepository: auth, profileRepository: profiles)));
    await tester.pumpAndSettle();
    expect(find.text('حالتي المالية'), findsOneWidget);
    expect(find.text('10,000 EGP'), findsOneWidget);
    expect(find.text('7,000 EGP'), findsOneWidget);
    expect(find.text('إعداد بيتك'), findsNothing);
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

  testWidgets('persistence failure keeps onboarding on screen with entered data', (tester) async {
    final profiles = FakeProfileRepository()..shouldFailSave = true;
    HouseholdProfile? completed;
    await tester.pumpWidget(MaterialApp(home: HouseholdOnboardingPage(
      userId: 'u1', repository: profiles, onCompleted: (profile) => completed = profile,
    )));

    Future<void> enterField(Key key, String value) async {
      final field = find.byKey(key);
      expect(field, findsOneWidget);
      await tester.enterText(field, value);
    }

    await enterField(const ValueKey<String>('onboarding-country'), 'EG');
    await enterField(const ValueKey<String>('onboarding-region'), 'Cairo');
    await enterField(const ValueKey<String>('onboarding-currency'), 'EGP');
    await enterField(const ValueKey<String>('onboarding-household-size'), '3');
    await enterField(const ValueKey<String>('onboarding-adults'), '2');
    await enterField(const ValueKey<String>('onboarding-children'), '1');
    await enterField(const ValueKey<String>('onboarding-monthly-income'), '10000');
    await enterField(const ValueKey<String>('onboarding-recurring-obligations'), '3000');

    final saveButton = find.byKey(const ValueKey<String>('onboarding-save'));
    expect(saveButton, findsOneWidget);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('household-onboarding-page')), findsOneWidget);
    expect(find.text('ماقدرناش نحفظ بيانات البيت دلوقتي. بياناتك مازالت موجودة، حاول تاني.'), findsOneWidget);
    expect(find.text('10000'), findsOneWidget);
    expect(find.text('3000'), findsOneWidget);
    expect(completed, isNull);
    expect(profiles.saveCalls, 1);

    profiles.shouldFailSave = false;
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(completed, isNotNull);
    expect(profiles.saveCalls, 2);
  });
}

Widget _host(Widget child) => MaterialApp(theme: ThemeData(useMaterial3: true), home: child);
AuthenticatedAuthState _authenticatedState() => const AuthenticatedAuthState(AuthSession(user: AuthUser(id: 'u1', email: 'test@example.com')));
HouseholdProfile _profile() => const HouseholdProfile(
  userId: 'u1', countryCode: 'EG', region: 'Cairo', currencyCode: 'EGP', householdSize: 4,
  adults: 2, children: 2, housingType: 'rent', incomeFrequency: 'monthly', monthlyIncome: 10000,
  recurringObligations: 3000,
);

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository(this.state);
  final AuthState state;
  final _controller = StreamController<AuthState>.broadcast();
  @override AuthState get currentState => state;
  @override Stream<AuthState> get authStateChanges => _controller.stream;
  @override Future<AuthState> initialize() async => state;
  @override Future<void> signInWithGoogle() async {}
  @override Future<void> signOut() async => _controller.add(const UnauthenticatedAuthState());
  @override Future<void> dispose() async => _controller.close();
}

class FakeProfileRepository implements HouseholdProfileRepository {
  HouseholdProfile? profile;
  bool shouldFailSave = false;
  int saveCalls = 0;
  @override Future<HouseholdProfile?> load(String userId) async => profile;
  @override Future<void> save(HouseholdProfile value) async {
    saveCalls++;
    if (shouldFailSave) throw StateError('simulated persistence failure');
    profile = value;
  }
}
