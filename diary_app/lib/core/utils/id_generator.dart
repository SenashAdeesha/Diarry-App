import 'package:uuid/uuid.dart';

class IdGenerator {
  static final IdGenerator instance = IdGenerator._();
  IdGenerator._();

  final _uuid = const Uuid();

  String newId() => _uuid.v4();

  String newShortId() => _uuid.v4().substring(0, 8);
}
