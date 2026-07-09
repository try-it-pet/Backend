import 'product.dart';

class CartItem {
  final int id;
  final String size;
  final int qty;
  final Product product;
  const CartItem(
      {required this.id,
      required this.size,
      required this.qty,
      required this.product});

  factory CartItem.fromJson(Map<String, dynamic> j) => CartItem(
        id: j['id'] as int,
        size: j['size'] as String? ?? 'M',
        qty: (j['qty'] as num?)?.toInt() ?? 1,
        product: Product.fromJson(j['product'] as Map<String, dynamic>),
      );
}

class Order {
  final int id;
  final int total;
  final String createdAt;
  final List<CartItem> items;
  final String status;
  final String? carrier;
  final String? trackingNo;

  const Order({
    required this.id,
    required this.total,
    required this.createdAt,
    required this.items,
    required this.status,
    this.carrier,
    this.trackingNo,
  });

  factory Order.fromJson(Map<String, dynamic> j) => Order(
        id: j['id'] as int,
        total: (j['total'] as num?)?.toInt() ?? 0,
        createdAt: j['created_at'] as String? ?? '',
        items: ((j['items'] as List?) ?? [])
            .map((e) => CartItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        status: j['status'] as String? ?? '결제완료',
        carrier: j['carrier'] as String?,
        trackingNo: j['tracking_no'] as String?,
      );



  String get summary {
    if (items.isEmpty) return '상품 없음';
    final first = items.first.product.name;
    return items.length == 1 ? first : '$first 외 ${items.length - 1}건';
  }
}

/// AI 생성 잔여 횟수(요금 방어). unlimited면 무제한, 아니면 remaining 표시.
class Generations {
  final bool unlimited;
  final int? remaining;
  final int? granted;
  final int used;
  const Generations(
      {required this.unlimited, this.remaining, this.granted, this.used = 0});

  factory Generations.fromJson(Map<String, dynamic> j) => Generations(
        unlimited: j['unlimited'] as bool? ?? false,
        remaining: (j['remaining'] as num?)?.toInt(),
        granted: (j['granted'] as num?)?.toInt(),
        used: (j['used'] as num?)?.toInt() ?? 0,
      );

  String get label => unlimited ? '무제한' : '남은 ${remaining ?? 0}회';
}
