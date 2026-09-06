import 'package:flutter_test/flutter_test.dart';
import 'package:nus/features/appointments/domain/appointment.dart';

void main() {
  test('scheduled call requires contact name and phone', () {
    final base = Appointment(
      id: 'call-1',
      title: 'اتصال',
      type: AppointmentType.phoneCall,
      startsAt: DateTime.now().add(const Duration(hours: 1)),
    );

    expect(
      AppointmentValidator.validate(base),
      containsAll(<String>['call_contact_required', 'call_phone_required']),
    );
  });

  test('scheduled call accepts valid contact details', () {
    final appointment = Appointment(
      id: 'call-2',
      title: 'اتصال أحمد',
      type: AppointmentType.phoneCall,
      startsAt: DateTime.now().add(const Duration(hours: 1)),
      contactName: 'أحمد',
      contactPhone: '+201001234567',
      reminder: AppointmentReminder.atTime,
    );

    expect(AppointmentValidator.validate(appointment), isEmpty);
  });
}
