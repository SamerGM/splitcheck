// lib/core/models/person.dart
import 'package:flutter/material.dart';

class Person {
  final String id;
  final String name;
  final Color color;

  const Person({required this.id, required this.name, required this.color});

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'color': color.toARGB32()};

  factory Person.fromJson(Map<String, dynamic> j) =>
      Person(id: j['id'] as String, name: j['name'] as String, color: Color(j['color'] as int));

  @override
  bool operator ==(Object other) => other is Person && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Avatar colours — iOS system palette.
const List<Color> kPersonColors = [
  Color(0xFF007AFF), Color(0xFF34C759), Color(0xFFFF9500), Color(0xFFFF2D55),
  Color(0xFFAF52DE), Color(0xFF5AC8FA), Color(0xFFFFCC00), Color(0xFF5856D6),
  Color(0xFFFF3B30),
];
