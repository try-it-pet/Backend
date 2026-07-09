import 'package:flutter/material.dart';
import '../api/client.dart';
import '../models/commerce.dart';
import '../theme/tokens.dart';
import 'coming_soon_screen.dart' show PawdyBar;
import 'detail_screen.dart';


class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  late Future<List<Order>> _future;

  @override
  void initState() {
    super.initState();
    _future = Api.fetchOrders();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: T.paper,
      body: SafeArea(
        child: Column(
          children: [
            const PawdyBar(title: '주문 내역'),
            Expanded(
              child: FutureBuilder<List<Order>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator(
                            color: T.accent, strokeWidth: 3));
                  }
                  final orders = snap.data ?? [];
                  if (snap.hasError || orders.isEmpty) {
                    return _empty();
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
                    itemCount: orders.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => _orderCard(orders[i]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _orderCard(Order o) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: T.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('주문 #${o.id}',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: T.ink)),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: o.status == '결제완료' ? T.soft : T.accentSoft,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        o.status,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: o.status == '결제완료' ? T.sub : T.accent,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(o.createdAt.split('T').first,
                        style: const TextStyle(
                            fontSize: 12, color: T.muted, fontWeight: FontWeight.w500)),
                  ],
                ),
              ],
            ),
            const Divider(height: 24, color: T.line),
            
            // 주문한 개별 상품 목록 표시
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: o.items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (ctx, idx) {
                final it = o.items[idx];
                final img = Api.imageUrl(it.product);
                return GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => DetailScreen(product: it.product),
                      ),
                    );
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 상품 이미지
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 48,
                          height: 48,
                          color: T.soft,
                          child: img == null
                              ? const Icon(Icons.shopping_bag_outlined, color: T.muted, size: 20)
                              : Image.network(img, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.shopping_bag_outlined, color: T.muted, size: 20)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // 상품명 & 사이즈 정보
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              it.product.brand,
                              style: const TextStyle(fontSize: 11, color: T.muted2, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              it.product.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: T.ink),
                            ),
                            const SizedBox(height: 4),
                            // 사이즈 및 수량 정보 노출
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: T.soft,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '주문 사이즈: ${it.size} | ${it.qty}개',
                                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: T.sub),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, size: 18, color: T.muted2),
                    ],
                  ),
                );
              },
            ),
            
            const Divider(height: 24, color: T.line),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('총 결제금액',
                    style: TextStyle(
                        fontSize: 12.5, color: T.sub, fontWeight: FontWeight.w600)),
                Text('${won(o.total)}원',
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: T.ink)),
              ],
            ),
          ],
        ),
      );



  Widget _empty() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                  color: T.soft, borderRadius: BorderRadius.circular(18)),
              child: const Icon(Icons.receipt_long_outlined,
                  color: Color(0xFFC4BDB3), size: 28),
            ),
            const SizedBox(height: 18),
            const Text('아직 주문 내역이 없어요',
                style: TextStyle(
                    fontSize: 14, color: T.muted, fontWeight: FontWeight.w600)),
          ],
        ),
      );
}
