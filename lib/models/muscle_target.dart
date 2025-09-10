import 'package:hive/hive.dart';
import 'daily_target.dart';



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
  Map<String, DailyTarget>? dailyTargets; // e.g. {'Mon': DailyTarget(...), ...}

  MuscleTarget({
    required this.id,
    required this.muscleGroup,
    this.targetSets,
    this.targetReps,
    this.dailyTargets,
  });
}
