  });

  testWidgets('existing valid profile bypasses onboarding and opens the NUS household shell', (tester) async {
    final auth = FakeAuthRepository(_authenticatedState());
    final profiles = FakeProfileRepository()..profile = _profile();
    final notifications = NotificationService();
    final medicationService = MedicationLifecycleService(
      repository: LocalMedicationRepository(),
      reminders: MedicationReminderCoordinator(
        MedicationReminderAdapter(notifications),
      ),
    );
    await tester.pumpWidget(_host(AuthGate(
      authRepository: auth,
      profileRepository: profiles,
      scheduleStore: ScheduleStore(),
      medicationService: medicationService,
    )));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('مواعيدي وتذكيراتي'), findsOneWidget);
    expect(find.text('NUS الذكي'), findsOneWidget);
    expect(find.text('اقتصاد البيت تحت السيطرة'), findsOneWidget);
    expect(find.text('مركز البيت — كل أدوات NUS في متناولك'), findsOneWidget);
    expect(find.text('البيت'), findsOneWidget);
    expect(find.text('NUS Copilot', skipOffstage: false), findsNothing);
    expect(find.text('إعداد بيتك', skipOffstage: false), findsNothing);
    expect(find.byType(HouseholdOnboardingPage), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('registration flow calls the existing email registration boundary', (tester) async {