// lib/core/services/history_service.dart
import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/models.dart';

class HistoryService {
  static const _box = 'splitcheck_history';

  Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox<String>(_box);
  }

  Future<void> save(Bill bill) async {
    final box = Hive.box<String>(_box);
    await box.put(bill.id, jsonEncode(bill.toJson()));
  }

  List<Bill> loadAll() {
    final box = Hive.box<String>(_box);
    return box.values
        .map((json) {
          try { return Bill.fromJson(jsonDecode(json) as Map<String, dynamic>); }
          catch (_) { return null; }
        })
        .whereType<Bill>()
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  Future<void> delete(String id) async {
    final box = Hive.box<String>(_box);
    await box.delete(id);
  }
}
