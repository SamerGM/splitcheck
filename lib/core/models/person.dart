// lib/core/models/person.dart
import 'package:flutter/material.dart';

class Person {
  final String id;
  final String name;
  final Color color;

  const Person({required this.id, required this.name, required this.color});

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'color': color.value};

  factory Person.fromJson(Map<String, dynamic> j) =>
      Person(id: j['id'] as String, name: j['name'] as String, color: Color(j['color'] as int));

  @override
  bool operator ==(Object other) => other is Person && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

const List<Color> kPersonColors = [
  Color(0xFF63B3ED), Color(0xFF68D391), Color(0xFFF6AD55),
  Color(0xFFFC8181), Color(0xFFB794F4), Color(0xFF76E4F7),
  Color(0xFFFBB6CE), Color(0xFF9AE6B4), Color(0xFFFDA74F),
];
