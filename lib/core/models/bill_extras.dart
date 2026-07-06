// lib/core/models/bill_extras.dart

class BillExtras {
  final double vatPct;      // e.g. 5.0 means 5%
  final double servicePct;  // e.g. 10.0 means 10%
  final double tipPct;      // e.g. 15.0 means 15% (optional)

  const BillExtras({
    this.vatPct = 0,
    this.servicePct = 0,
    this.tipPct = 0,
  });

  factory BillExtras.empty() => const BillExtras();

  double vatAmount(double subtotal)     => subtotal * vatPct / 100;
  double serviceAmount(double subtotal) => subtotal * servicePct / 100;
  double tipAmount(double subtotal)     => subtotal * tipPct / 100;

  double totalExtras(double subtotal) =>
      vatAmount(subtotal) + serviceAmount(subtotal) + tipAmount(subtotal);

  BillExtras copyWith({double? vatPct, double? servicePct, double? tipPct}) =>
      BillExtras(
        vatPct:     vatPct     ?? this.vatPct,
        servicePct: servicePct ?? this.servicePct,
        tipPct:     tipPct     ?? this.tipPct,
      );

  Map<String, dynamic> toJson() => {
    'vatPct': vatPct, 'servicePct': servicePct, 'tipPct': tipPct,
  };

  factory BillExtras.fromJson(Map<String, dynamic> j) => BillExtras(
    vatPct:     (j['vatPct']     as num).toDouble(),
    servicePct: (j['servicePct'] as num).toDouble(),
    tipPct:     (j['tipPct']     as num).toDouble(),
  );
}
