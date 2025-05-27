// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'quote_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MotivationalQuoteAdapter extends TypeAdapter<MotivationalQuote> {
  @override
  final int typeId = 3;

  @override
  MotivationalQuote read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MotivationalQuote(
      id: fields[0] as String,
      text: fields[1] as String,
      author: fields[2] as String,
      category: fields[3] as String,
      dateAdded: fields[4] as DateTime,
      isFavorite: fields[5] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, MotivationalQuote obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.text)
      ..writeByte(2)
      ..write(obj.author)
      ..writeByte(3)
      ..write(obj.category)
      ..writeByte(4)
      ..write(obj.dateAdded)
      ..writeByte(5)
      ..write(obj.isFavorite);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MotivationalQuoteAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
