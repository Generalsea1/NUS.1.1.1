import 'package:flutter_test/flutter_test.dart';

import 'package:nus/core/ai/ai_insight.dart';
import 'package:nus/core/ai/ai_insight_provider.dart';
import 'package:nus/core/domain/domain_entity.dart';
import 'package:nus/features/appointments/domain/appointment.dart';
import 'package:nus/features/bills/domain/bill.dart';
import 'package:nus/features/expenses/domain/expense.dart';
import 'package:nus/features/expenses/domain/expense_date.dart';
import 'package:nus/features/expenses/domain/money.dart';
import 'package:nus/features/finance/domain/budget.dart';
import 'package:nus/features/medications/domain/medication.dart';
import 'package:nus/features/notes/domain/note.dart';
import 'package:nus/features/shopping/domain/shopping_item.dart';

class _FakeAppointmentRepository implements AppointmentRepository {
  Appointment? value;

  @override
  Future<Appointment?> getById(String id) async => value?.id == id ? value : null;

  @override
  Future<List<Appointment>> list() async => value == null ? [] : [value!];

  @override
  Future<void> save(Appointment entity) async {
    value = entity;
  }

  @override
  Future<void> deleteById(String id) async {
    if (value?.id == id) value = null;
  }
}

class _FakeAiProvider implements AiInsightProvider {
  @override
  Future<AiInsight> generateInsight(AiInsightRequest request) async {
    return AiInsight(
      id: 'insight-1',
      summary: request.objective,
      generatedAt: DateTime.utc(2026, 9, 3),
      sourceDomain: request.context.first.domain,
    );
  }
}

void main() {
  test('future domain models implement only the shared identity contract', () {
    final entities = <DomainEntity>[
      Appointment(id: 'a', title: 'Appointment', startsAt: DateTime.utc(2026)),
      Medication(
        id: 'm',
        name: 'Medication',
        dosage: const Dosage(amount: '1', unit: DosageUnit.tablet),
        startDate: DateTime.utc(2026, 9, 3),
        schedules: <MedicationSchedule>[
          MedicationSchedule(
            id: 'schedule-1',
            minutesSinceMidnight: 8 * 60,
            frequency: MedicationFrequency.daily,
          ),
        ],
      ),
      ShoppingItem(id: 's', name: 'Milk'),
      Expense(
        id: 'e',
        amount: Money(minorUnits: 10, currencyCode: 'USD'),
        date: ExpenseDate(year: 2026, month: 1, day: 1),
      ),
      Budget(
        id: 'b',
        name: 'Monthly',
        limitMinorUnits: 100,
        currencyCode: 'USD',
        periodStart: DateTime.utc(2026, 9, 1),
        periodEnd: DateTime.utc(2026, 9, 30),
      ),
      Bill(
        id: 'bill',
        title: 'Internet',
        amountMinorUnits: 50,
        currencyCode: 'USD',
        dueAt: DateTime.utc(2026, 9, 15),
      ),
      Note(
        id: 'n',
        title: 'Note',
        body: 'Body',
        updatedAt: DateTime.utc(2026),
      ),
    ];

    expect(entities.map((item) => item.id), [
      'a',
      'm',
      's',
      'e',
      'b',
      'bill',
      'n',
    ]);
  });

  test('repository boundary is independently testable with a fake', () async {
    final repository = _FakeAppointmentRepository();
    final appointment = Appointment(
      id: 'appointment-1',
      title: 'Doctor visit',
      startsAt: DateTime.utc(2026, 9, 4, 10),
    );

    await repository.save(appointment);

    expect(await repository.getById('appointment-1'), same(appointment));
    expect(await repository.list(), [same(appointment)]);

    await repository.deleteById('appointment-1');
    expect(await repository.getById('appointment-1'), isNull);
  });

  test('AI boundary consumes provider-neutral domain context', () async {
    final provider = _FakeAiProvider();
    final insight = await provider.generateInsight(
      const AiInsightRequest(
        objective: 'Summarize today',
        context: [
          AiContextItem(
            domain: 'appointments',
            entityId: 'appointment-1',
            summary: 'Doctor visit at 10:00',
          ),
        ],
      ),
    );

    expect(insight.summary, 'Summarize today');
    expect(insight.sourceDomain, 'appointments');
  });

  test('AI request context is independent from Flutter and provider SDKs', () {
    const request = AiInsightRequest(
      objective: 'Review my day',
      context: [
        AiContextItem(
          domain: 'notes',
          entityId: 'note-1',
          summary: 'Prepare quarterly review',
        ),
      ],
    );

    expect(request.objective, 'Review my day');
    expect(request.context.single.domain, 'notes');
  });
}
