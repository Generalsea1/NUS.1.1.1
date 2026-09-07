import 'dart:math';

final Random _random = Random();

String newEntityId() {
  final time = DateTime.now().microsecondsSinceEpoch.toRadixString(16).padLeft(16, '0');
  final random = List<int>.generate(16, (_) => _random.nextInt(16));
  final hex = '${time.substring(time.length - 8)}${random.map((v) => v.toRadixString(16)).join()}';
  final value = hex.padRight(32, '0').substring(0, 32);
  return '${value.substring(0, 8)}-${value.substring(8, 12)}-4${value.substring(13, 16)}-${(8 + _random.nextInt(4)).toRadixString(16)}${value.substring(17, 20)}-${value.substring(20, 32)}';
}
