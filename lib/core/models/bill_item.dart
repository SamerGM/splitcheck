// lib/core/models/bill_item.dart

class BillItem {
  final String id;
  final String name;

  /// Line total (unit price × quantity).
  final double price;

  /// How many were ordered — shown as "Cola ×2". Informational; [price] is the total.
  final int quantity;

  /// Empty = shared equally by ALL people.
  /// One ID = that person pays 100%.
  /// Multiple IDs = split between those people (see [portions]).
  final List<String> personIds;

  /// Optional unequal split: personId → number of portions (e.g. Ahmed 2, Sara 1).
  /// Missing IDs count as 1 portion. Empty = equal split.
  final Map<String, int> portions;

  const BillItem({
    required this.id,
    required this.name,
    required this.price,
    this.quantity = 1,
    this.personIds = const [],
    this.portions = const {},
  });

  bool get isShared => personIds.isEmpty;

  /// Name with quantity, e.g. "Cola ×2".
  String get label => quantity > 1 ? '$name ×$quantity' : name;

  int portionsOf(String personId) => portions[personId] ?? 1;

  BillItem copyWith({String? name, double? price, int? quantity,
      List<String>? personIds, Map<String, int>? portions}) => BillItem(
    id: id,
    name: name ?? this.name,
    price: price ?? this.price,
    quantity: quantity ?? this.quantity,
    personIds: personIds ?? this.personIds,
    portions: portions ?? this.portions,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'price': price, 'quantity': quantity,
    'personIds': personIds, 'portions': portions,
  };

  factory BillItem.fromJson(Map<String, dynamic> j) => BillItem(
    id: j['id'] as String,
    name: j['name'] as String,
    price: (j['price'] as num).toDouble(),
    quantity: (j['quantity'] as num? ?? 1).toInt(),
    personIds: List<String>.from(j['personIds'] as List),
    portions: (j['portions'] as Map? ?? const {})
        .map((k, v) => MapEntry(k as String, (v as num).toInt())),
  );
}
