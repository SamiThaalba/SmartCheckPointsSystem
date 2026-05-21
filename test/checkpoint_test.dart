import 'package:flutter_test/flutter_test.dart';
import 'package:smart_checkpoint/checkpoint.dart';

void main() {
  test('statusFromString parses supported status values', () {
    expect(statusFromString('open'), CheckpointStatus.open);
    expect(statusFromString('closed'), CheckpointStatus.closed);
    expect(statusFromString('crowded'), CheckpointStatus.crowded);
  });

  test('unknown Firestore status defaults to open', () {
    expect(statusFromString('unexpected'), CheckpointStatus.open);
  });
}
