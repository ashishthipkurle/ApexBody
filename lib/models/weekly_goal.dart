import 'package:hive/hive.dart';

part 'weekly_goal.g.dart';

// TypeId for String to DailyTarget Map
class DailyTargetMapAdapter extends TypeAdapter<Map<String, DailyTarget>> {
  @override
  final typeId = 4;

  @override
  Map<String, DailyTarget> read(BinaryReader reader) {
    final numOfElements = reader.readByte();
    final map = <String, DailyTarget>{};
    for (var i = 0; i < numOfElements; i++) {
      final key = reader.read() as String;
      final value = reader.read() as DailyTarget;
      map[key] = value;
    }
    return map;
  }

  @override
  void write(BinaryWriter writer, Map<String, DailyTarget> map) {
    writer.writeByte(map.length);
    map.forEach((key, value) {
      writer.write(key);
      writer.write(value);
    });
  }
}

@HiveType(typeId: 1)
class WeeklyGoal extends HiveObject {
  @HiveField(0)
  String id;
  @HiveField(1)
  String clientId;
  @HiveField(2)
  DateTime weekStart;
  @HiveField(3)
  double? targetBodyWeight;
  @HiveField(4)
  double? targetCalories;
  @HiveField(5)
  String? notes;
  @HiveField(6)
  List<MuscleTarget> muscleTargets;

  WeeklyGoal({
    required this.id,
    required this.clientId,
    required this.weekStart,
    this.targetBodyWeight,
    this.targetCalories,
    this.notes,
    required this.muscleTargets,
  });
}

@HiveType(typeId: 2)
class MuscleTarget extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String muscleGroup;

  @HiveField(2)
  int? targetSets;

  @HiveField(3)
  int? targetReps;

  @HiveField(4)
  double? targetWeight;

  @HiveField(5)
  Map<String, DailyTarget>? dailyTargets;

  @HiveField(6)
  List<Map<String, dynamic>>? exercises;

  MuscleTarget({
    required this.id,
    required this.muscleGroup,
    this.targetSets,
    this.targetReps,
    this.targetWeight,
    this.dailyTargets,
    this.exercises,
  });
}

@HiveType(typeId: 3)
class DailyTarget extends HiveObject {
  @HiveField(0)
  int sets;

  @HiveField(1)
  int reps;

  @HiveField(2)
  double? weight;

  @HiveField(3)
  List<Map<String, dynamic>>? exercises;

  DailyTarget({
    required this.sets,
    required this.reps,
    this.weight,
    this.exercises,
  });
}
