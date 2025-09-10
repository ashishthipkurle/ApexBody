// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'weekly_goal.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class WeeklyGoalAdapter extends TypeAdapter<WeeklyGoal> {
  @override
  final int typeId = 1;

  @override
  WeeklyGoal read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (var i = 0; i < numOfFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return WeeklyGoal(
      id: fields[0] as String,
      clientId: fields[1] as String,
      weekStart: fields[2] as DateTime,
      targetBodyWeight: fields[3] as double?,
      targetCalories: fields[4] as double?,
      notes: fields[5] as String?,
      muscleTargets: (fields[6] as List).cast<MuscleTarget>(),
    );
  }

  @override
  void write(BinaryWriter writer, WeeklyGoal obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.clientId)
      ..writeByte(2)
      ..write(obj.weekStart)
      ..writeByte(3)
      ..write(obj.targetBodyWeight)
      ..writeByte(4)
      ..write(obj.targetCalories)
      ..writeByte(5)
      ..write(obj.notes)
      ..writeByte(6)
      ..write(obj.muscleTargets);
  }
}

class MuscleTargetAdapter extends TypeAdapter<MuscleTarget> {
  @override
  final int typeId = 2;

  @override
  MuscleTarget read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (var i = 0; i < numOfFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return MuscleTarget(
      id: fields[0] as String,
      muscleGroup: fields[1] as String,
      targetSets: fields[2] as int?,
      targetReps: fields[3] as int?,
      dailyTargets: (fields[4] as Map?)
          ?.map((k, v) => MapEntry(k as String, v as DailyTarget)),
    );
  }

  @override
  void write(BinaryWriter writer, MuscleTarget obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.muscleGroup)
      ..writeByte(2)
      ..write(obj.targetSets)
      ..writeByte(3)
      ..write(obj.targetReps)
      ..writeByte(4)
      ..write(obj.dailyTargets);
  }
}

class DailyTargetAdapter extends TypeAdapter<DailyTarget> {
  @override
  final int typeId = 3;

  @override
  DailyTarget read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (var i = 0; i < numOfFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return DailyTarget(
      sets: fields[0] as int,
      reps: fields[1] as int,
      weight: fields[2] as double?,
    );
  }

  @override
  void write(BinaryWriter writer, DailyTarget obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.sets)
      ..writeByte(1)
      ..write(obj.reps)
      ..writeByte(2)
      ..write(obj.weight);
  }
}
