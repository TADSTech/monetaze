import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

part 'user_model.g.dart';

@HiveType(typeId: 2)
class User {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String? email;

  @HiveField(3)
  final String? gender;

  @HiveField(4)
  final String? financialGoal;

  @HiveField(5)
  final String? profileImagePath;

  @HiveField(6)
  final DateTime createdAt;

  @HiveField(7)
  final DateTime updatedAt;

  @HiveField(8)
  final ThemeMode themeMode;

  @HiveField(9)
  final int themeIndex;

  User({
    required this.id,
    required this.name,
    this.email,
    this.gender,
    this.financialGoal,
    this.profileImagePath,
    DateTime? createdAt,
    DateTime? updatedAt,
    ThemeMode? themeMode,
    int? themeIndex,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now(),
       themeMode = themeMode ?? ThemeMode.system,
       themeIndex = themeIndex ?? 0;

  factory User.empty() => User(
    id: 'current_user',
    name: '',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
    themeMode: ThemeMode.system,
    themeIndex: 0,
  );

  User copyWith({
    String? id,
    String? name,
    String? email,
    String? gender,
    String? financialGoal,
    String? profileImagePath,
    DateTime? createdAt,
    DateTime? updatedAt,
    ThemeMode? themeMode,
    int? themeIndex,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      gender: gender ?? this.gender,
      financialGoal: financialGoal ?? this.financialGoal,
      profileImagePath: profileImagePath ?? this.profileImagePath,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      themeMode: themeMode ?? this.themeMode,
      themeIndex: themeIndex ?? this.themeIndex,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'gender': gender,
      'financialGoal': financialGoal,
      'profileImagePath': profileImagePath,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'themeMode': themeMode.index,
      'themeIndex': themeIndex,
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] as String,
      name: map['name'] as String,
      email: map['email'] as String?,
      gender: map['gender'] as String?,
      financialGoal: map['financialGoal'] as String?,
      profileImagePath: map['profileImagePath'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int),
      themeMode: ThemeMode.values[map['themeMode'] as int],
      themeIndex: map['themeIndex'] as int,
    );
  }

  @override
  String toString() {
    return 'User(id: $id, name: $name, email: $email, gender: $gender, '
        'financialGoal: $financialGoal, profileImagePath: $profileImagePath, '
        'createdAt: $createdAt, updatedAt: $updatedAt, '
        'themeMode: $themeMode, themeIndex: $themeIndex)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is User &&
        other.id == id &&
        other.name == name &&
        other.email == email &&
        other.gender == gender &&
        other.financialGoal == financialGoal &&
        other.profileImagePath == profileImagePath &&
        other.themeMode == themeMode &&
        other.themeIndex == themeIndex;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        name.hashCode ^
        email.hashCode ^
        gender.hashCode ^
        financialGoal.hashCode ^
        profileImagePath.hashCode ^
        createdAt.hashCode ^
        updatedAt.hashCode ^
        themeMode.hashCode ^
        themeIndex.hashCode;
  }
}
