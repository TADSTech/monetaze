// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'goal_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class GoalAdapter extends TypeAdapter<Goal> {
  @override
  final int typeId = 0;

  @override
  Goal read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Goal(
      id: fields[0] as String,
      name: fields[1] as String,
      targetAmount: fields[2] as double,
      currency: fields[4] as String,
      currentAmount: fields[3] as double,
      targetDate: fields[6] as DateTime?,
      category: fields[7] as String?,
      description: fields[8] as String?,
      isCompleted: fields[9] as bool,
      savingsInterval: fields[10] as SavingsInterval,
      startingAmount: fields[11] as double,
      startDate: fields[12] as DateTime?,
      createdAt: fields[5] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, Goal obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.targetAmount)
      ..writeByte(3)
      ..write(obj.currentAmount)
      ..writeByte(4)
      ..write(obj.currency)
      ..writeByte(5)
      ..write(obj.createdAt)
      ..writeByte(6)
      ..write(obj.targetDate)
      ..writeByte(7)
      ..write(obj.category)
      ..writeByte(8)
      ..write(obj.description)
      ..writeByte(9)
      ..write(obj.isCompleted)
      ..writeByte(10)
      ..write(obj.savingsInterval)
      ..writeByte(11)
      ..write(obj.startingAmount)
      ..writeByte(12)
      ..write(obj.startDate);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GoalAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SavingsIntervalAdapter extends TypeAdapter<SavingsInterval> {
  @override
  final int typeId = 5;

  @override
  SavingsInterval read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return SavingsInterval.daily;
      case 1:
        return SavingsInterval.weekly;
      case 2:
        return SavingsInterval.monthly;
      case 3:
        return SavingsInterval.yearly;
      default:
        return SavingsInterval.daily;
    }
  }

  @override
  void write(BinaryWriter writer, SavingsInterval obj) {
    switch (obj) {
      case SavingsInterval.daily:
        writer.writeByte(0);
        break;
      case SavingsInterval.weekly:
        writer.writeByte(1);
        break;
      case SavingsInterval.monthly:
        writer.writeByte(2);
        break;
      case SavingsInterval.yearly:
        writer.writeByte(3);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SavingsIntervalAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
