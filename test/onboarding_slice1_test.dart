import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nus/features/onboarding/application/household_profile_repository.dart';
import 'package:nus/features/onboarding/application/household_profile_validator.dart';
import 'package:nus/features/onboarding/data/supabase_household_profile_repository.dart';
import 'package:nus/features/onboarding/domain/household_profile.dart';
import 'package:nus/features/onboarding/presentation/auth_gate.dart';
import 'package:nus/features/onboarding/presentation/auth_page.dart';
import 'package:nus/features/onboarding/presentation/financial_dashboard_page.dart';
import 'package:nus/features/onboarding/presentation/household_onboarding_page.dart';

void main() {
  test('Slice 1 domain accepts a complete real household profile', () {
    final profile = _profile();
    final result = const HouseholdProfileValidator().validate(profile);

    expect(result.isValid, isTrue);
    expect(result.errors, isEmpty);
  });

  test('Slice 1 domain rejects impossible counts, invalid currency, and negative money', () {
    final profile = _profile().copyWith(
      householdSize: 5,
      adults: 2,
      children: 2,
      currencyCode: 'EGP',
      monthlyIncome: -1,
      recurringObligations: -5,
    );

    final result = const HouseholdProfileValidator().validate(profile);

    expect(result.isValid, isFalse);
    expect(result.errors.keys, containsAll(<String>[
      'householdSize',
      'adults',
      'children',
      'monthlyIncome',
      'recurringObligations',
    ]));
  });

  testWidgets('unauthenticated user is routed to registration/login', (tester) async {
    final auth = FakeAuthRepository(const UnauthenticatedAuthState());
    final profiles = FakeProfileRepository();
    await tester.pumpWidget(_host(AuthGate(authRepository: auth, profileRepository: profiles)));
    await tester.pumpAndSettle();

    expect(find.byType(AuthPage), findsOneWidget);
    expect(find.text('إنشاء حساب'), findsOneWidget);
  });

  testWidgets('new authenticated user is routed to household onboarding', (tester) async {
    final auth = FakeAuthRepository(_authenticatedState());
    final profiles = FakeProfileRepository();
    await tester.pumpWidget(_host(AuthGate(authRepository: auth, profileRepository: profiles)));
    await tester.pumpAndSettle();

    expect(find.byType(HouseholdOnboardingPage), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('household-onboarding-page')), findsOneWidget);
  });

  testWidgets('existing valid profile bypasses onboarding', (tester) async {
    final auth = FakeAuthRepository(_authenticatedState());
    final profiles = FakeProfileRepository(initial: _profile());
    await tester.pumpWidget(_host(AuthGate(authRepository: auth, profileRepository: profiles)));
    await tester.pumpAndSettle();

    expect(find.byType(HouseholdOnboardingPage), findsNothing);
    expect(find.byType(FinancialDashboardPage), findsOneWidget);
    expect(find.text('10000'), findsOneWidget);
    expect(find.text('3000'), findsOneWidget);
  });

  testWidgets('persistence failure keeps onboarding on screen with entered data', (tester) async {
    final profiles = FakeProfileRepository()..shouldFailSave = true;
    HouseholdProfile? completed;
    await tester.pumpWidget(MaterialApp(home: HouseholdOnboardingPage(
      userId: 'u1', repository: profiles, onCompleted: (profile) => completed = profile,
    )));

    final scrollableFinder = find.byKey(const ValueKey<String>('onboarding-form-scroll'));

    Future<void> enterField(Key key, String value) async {
      final field = find.byKey(key, skipOffstage: false);
      await tester.scrollUntilVisible(
        field,
        400,
        scrollable: scrollableFinder,
      );
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

    final saveButton = find.byKey(const ValueKey<String>('onboarding-save'), skipOffstage: false);
    await tester.scrollUntilVisible(
      saveButton,
      400,
      scrollable: scrollableFinder,
    );
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

  testWidgets('registration flow calls the existing email registration boundary', (tester) async {
    final auth = FakeAuthRepository(const UnauthenticatedAuthState());
    await tester.pumpWidget(_host(AuthPage(authRepository: auth)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('إنشاء حساب'));
    await tester.pumpAndSettle();

    expect(find.text('تأكيد كلمة السر'), findsOneWidget);
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'test@example.com');
    await tester.enterText(fields.at(1), 'secret123');
    await tester.enterText(fields.at(2), 'secret123');
    await tester.tap(find.text('إنشاء حساب').last);
    await tester.pumpAndSettle();

    expect(auth.registerCalls, 1);
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
  int registerCalls = 0;

  @override
  Stream<AuthState> get authStateChanges => Stream<AuthState>.value(state);

  @override
  AuthState get currentState => state;

  @override
  Future<AuthSession?> login({required String email, required String password}) async => state.session;

  @override
  Future<void> logout() async {}

  @override
  Future<AuthSession?> register({required String email, required String password}) async {
    registerCalls++;
    return state.session;
  }

  @override
  Future<AuthSession?> signInWithGoogle() async => state.session;

  void dispose() => _controller.close();
}

class FakeProfileRepository implements HouseholdProfileRepository {
  FakeProfileRepository({HouseholdProfile? initial}) : _profile = initial;

  HouseholdProfile? _profile;
  bool shouldFailSave = false;
  int saveCalls = 0;

  @override
  Future<HouseholdProfile?> currentProfile(String userId) async => _profile;

  @override
  Future<void> save(HouseholdProfile profile) async {
    saveCalls++;
    if (shouldFailSave) throw StateError('persistence unavailable');
    _profile = profile;
  }
}
