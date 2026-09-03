import 'package:flutter_test/flutter_test.dart';
import 'package:nus/features/appointments/application/appointment_reminder_coordinator.dart';
import 'package:nus/features/appointments/data/local_appointment_repository.dart';
import 'package:nus/features/appointments/domain/appointment.dart';
import 'package:nus/features/appointments/domain/appointment_reminder_port.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakePort implements AppointmentReminderPort {
  final scheduled = <({String id, String title, DateTime dateTime})>[];
  final cancelled = <String>[];
  @override Future<void> schedule({required String id, required String title, required DateTime dateTime}) async => scheduled.add((id: id,title: title,dateTime: dateTime));
  @override Future<void> cancel(String id) async => cancelled.add(id);
}

Appointment make({String id='a1', AppointmentType type=AppointmentType.personal, DateTime? start, DateTime? end, AppointmentReminder reminder=AppointmentReminder.none, AppointmentRecurrence recurrence=AppointmentRecurrence.none, AppointmentStatus status=AppointmentStatus.upcoming, String? doctorName, String? phone}) => Appointment(id:id,title:'Important',type:type,startsAt:start ?? DateTime.now().add(const Duration(hours:2)),endsAt:end,reminder:reminder,recurrence:recurrence,status:status,doctorName:doctorName,contactPhone:phone,specialty:type==AppointmentType.doctor?'Cardiology':null);

void main(){
  setUp(()=>SharedPreferences.setMockInitialValues({}));
  test('model round trip preserves feature data',(){ final a=make(type:AppointmentType.doctor,end:DateTime(2026,9,4,11),reminder:AppointmentReminder.thirtyMinutesBefore,recurrence:AppointmentRecurrence.weekly,doctorName:'Dr Samir',phone:'+201001234567'); expect(Appointment.fromJson(a.toJson()).toJson(),a.toJson()); });
  test('repository create edit delete',() async { final r=LocalAppointmentRepository(); final a=make(); await r.save(a); expect(await r.getById(a.id),isNotNull); await r.save(a.copyWith(title:'Edited')); expect((await r.getById(a.id))!.title,'Edited'); await r.deleteById(a.id); expect(await r.getById(a.id),isNull); });
  test('repository reload persists data',() async { final r=LocalAppointmentRepository(); final a=make(id:'persist'); await r.save(a); final restored=await LocalAppointmentRepository().getById('persist'); expect(restored!.startsAt,a.startsAt); });
  test('doctor data and validation',(){ expect(AppointmentValidator.validate(make(type:AppointmentType.doctor,doctorName:'Dr Hanna')),isEmpty); expect(AppointmentValidator.validate(make(type:AppointmentType.doctor)),contains('doctor_name_required')); });
  test('invalid input is rejected',() async { final now=DateTime(2026,9,3,12); expect(AppointmentValidator.validate(Appointment(id:'b',title:' ',type:AppointmentType.personal,startsAt:DateTime(2026,9,4,10)),now:now),contains('title_required')); expect(AppointmentValidator.validate(make(start:DateTime(2026,9,4,10),end:DateTime(2026,9,4,9)),now:now),contains('end_after_start')); final bad=make(phone:'abc'); expect(AppointmentValidator.validate(bad,now:now),contains('invalid_phone')); await expectLater(LocalAppointmentRepository().save(bad),throwsArgumentError); });
  test('reminder offset is applied',() async { final p=FakePort(); final start=DateTime.now().add(const Duration(hours:2)); await AppointmentReminderCoordinator(p).sync(make(start:start,reminder:AppointmentReminder.fifteenMinutesBefore)); expect(p.scheduled.single.dateTime,start.subtract(const Duration(minutes:15))); });
  test('daily recurrence uses existing scheduler boundary',() async { final p=FakePort(); final start=DateTime.now().add(const Duration(hours:2)); final a=make(start:start,reminder:AppointmentReminder.atTime,recurrence:AppointmentRecurrence.daily); await AppointmentReminderCoordinator(p).sync(a); expect(p.scheduled.length,12); expect(p.scheduled[1].dateTime,start.add(const Duration(days:1))); expect(p.cancelled,hasLength(13)); });
  test('completed appointment has no active reminder',() async { final p=FakePort(); final a=make(start:DateTime.now().add(const Duration(hours:2)),reminder:AppointmentReminder.atTime); await AppointmentReminderCoordinator(p).sync(a); final before=p.scheduled.length; await AppointmentReminderCoordinator(p).sync(a.copyWith(status:AppointmentStatus.completed)); expect(before,1); expect(p.scheduled.length,1); expect(p.cancelled,hasLength(13)); });
  test('phone normalization is safe',(){ expect(AppointmentValidator.isValidPhone('+20 100-123-4567'),isTrue); expect(AppointmentValidator.normalizePhone('+20 100-123-4567'),'+201001234567'); expect(AppointmentValidator.isValidPhone('abc123'),isFalse); });
}
