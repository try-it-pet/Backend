import 'package:flutter/material.dart';
import '../api/client.dart';
import '../models/commerce.dart';
import '../theme/tokens.dart';
import 'coming_soon_screen.dart' show PawdyBar;

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
                Text(o.createdAt.split('T').first,
                    style: const TextStyle(
                        fontSize: 12, color: T.muted, fontWeight: FontWeight.w500)),
              ],
            ),
            const SizedBox(height: 8),
            Text(o.summary,
                style: const TextStyle(
                    fontSize: 13.5, color: T.sub, fontWeight: FontWeight.w500)),
            const SizedBox(height: 10),
            Text.rich(TextSpan(children: [
              const TextSpan(
                  text: '결제 ',
                  style: TextStyle(
                      fontSize: 12, color: T.muted, fontWeight: FontWeight.w600)),
              TextSpan(
                  text: '${won(o.total)}원',
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: T.ink)),
            ])),
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
