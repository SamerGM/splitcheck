// lib/core/models/bill_extras.dart
class BillExtras {
  final double vatPct;        // e.g. 5.0 means 5%
  final double servicePct;    // e.g. 10.0 means 10%
  final double tipPct;        // e.g. 15.0 means 15% (optional)
  final double discountPct;   // e.g. 10.0 means 10% off subtotal
  final double discountFixed; // e.g. 50.0 means $50 off subtotal

  const BillExtras({
    this.vatPct = 0,
    this.servicePct = 0,
    this.tipPct = 0,
    this.discountPct = 0,
    this.discountFixed = 0,
  });

  factory BillExtras.empty() => const BillExtras();

  // Discount applied first on subtotal
  double discountAmount(double subtotal) {
    if (discountPct > 0) return subtotal * discountPct / 100;
    if (discountFixed > 0) return discountFixed.clamp(0, subtotal);
    return 0;
  }

  // VAT/service/tip calculated on discounted subtotal
  double discountedSubtotal(double subtotal) => subtotal - discountAmount(subtotal);
  double vatAmount(double subtotal)     => discountedSubtotal(subtotal) * vatPct / 100;
  double serviceAmount(double subtotal) => discountedSubtotal(subtotal) * servicePct / 100;
  double tipAmount(double subtotal)     => discountedSubtotal(subtotal) * tipPct / 100;
  double totalExtras(double subtotal)   =>
      vatAmount(subtotal) + serviceAmount(subtotal) + tipAmount(subtotal);

  BillExtras copyWith({
    double? vatPct, double? servicePct, double? tipPct,
    double? discountPct, double? discountFixed,
  }) => BillExtras(
    vatPct:        vatPct        ?? this.vatPct,
    servicePct:    servicePct    ?? this.servicePct,
    tipPct:        tipPct        ?? this.tipPct,
    discountPct:   discountPct   ?? this.discountPct,
    discountFixed: discountFixed ?? this.discountFixed,
  );

  Map<String, dynamic> toJson() => {
    'vatPct': vatPct, 'servicePct': servicePct, 'tipPct': tipPct,
    'discountPct': discountPct, 'discountFixed': discountFixed,
  };

  factory BillExtras.fromJson(Map<String, dynamic> j) => BillExtras(
    vatPct:        (j['vatPct']        as num).toDouble(),
    servicePct:    (j['servicePct']    as num).toDouble(),
    tipPct:        (j['tipPct']        as num).toDouble(),
    discountPct:   (j['discountPct']   as num? ?? 0).toDouble(),
    discountFixed: (j['discountFixed'] as num? ?? 0).toDouble(),
  );
}
