// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recipe.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class RecipeAdapter extends TypeAdapter<Recipe> {
  @override
  final int typeId = 1;

  @override
  Recipe read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Recipe(
      videoId: fields[0] as String,
      title: fields[1] as String,
      channelTitle: fields[2] as String,
      thumbnailUrl: fields[3] as String?,
      rawDescription: fields[4] as String,
      ingredients: (fields[5] as List).cast<Ingredient>(),
      steps: (fields[6] as List).cast<RecipeStep>(),
      servings: fields[7] as String?,
      addedAt: fields[8] as DateTime,
      isEdited: fields[9] as bool,
      parserVersion: fields[10] as int,
    );
  }

  @override
  void write(BinaryWriter writer, Recipe obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.videoId)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.channelTitle)
      ..writeByte(3)
      ..write(obj.thumbnailUrl)
      ..writeByte(4)
      ..write(obj.rawDescription)
      ..writeByte(5)
      ..write(obj.ingredients)
      ..writeByte(6)
      ..write(obj.steps)
      ..writeByte(7)
      ..write(obj.servings)
      ..writeByte(8)
      ..write(obj.addedAt)
      ..writeByte(9)
      ..write(obj.isEdited)
      ..writeByte(10)
      ..write(obj.parserVersion);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecipeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
