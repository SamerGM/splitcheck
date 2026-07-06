// lib/core/models/bill_item.dart

class BillItem {
  final String id;
  final String name;
  final double price;

  /// Empty = shared equally by ALL people.
  /// One ID = that person pays 100%.
  /// Multiple IDs = split equally among those people only.
  final List<String> personIds;

  const BillItem({
    required this.id,
    required this.name,
    required this.price,
    this.personIds = const [],
  });

  bool get isShared => personIds.isEmpty;

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'price': price, 'personIds': personIds,
  };

  factory BillItem.fromJson(Map<String, dynamic> j) => BillItem(
    id: j['id'] as String,
    name: j['name'] as String,
    price: (j['price'] as num).toDouble(),
    personIds: List<String>.from(j['personIds'] as List),
  );
}
