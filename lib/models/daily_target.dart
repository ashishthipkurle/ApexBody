import 'package:hive/hive.dart';


@HiveType(typeId: 3)
class DailyTarget extends HiveObject {
  @HiveField(0)
  int sets;

  @HiveField(1)
  int reps;

  @HiveField(2)
  double? weight;

  DailyTarget({
    required this.sets,
    required this.reps,
    this.weight,
  });
}
