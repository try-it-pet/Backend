import 'package:flutter/material.dart';
import '../api/client.dart';
import '../models/commerce.dart';
import '../theme/tokens.dart';
import 'coming_soon_screen.dart' show PawdyBar;

class ShippingStatusScreen extends StatefulWidget {
  const ShippingStatusScreen({super.key});

  @override
  State<ShippingStatusScreen> createState() => _ShippingStatusScreenState();
}

class _ShippingStatusScreenState extends State<ShippingStatusScreen> {
  late Future<List<Order>> _future;

  @override
  void initState() {
    super.initState();
    _future = Api.fetchOrders();
  }

  int _getStatusStep(String status) {
    switch (status) {
      case '결제완료':
        return 0;
      case '배송준비중':
        return 1;
      case '배송중':
        return 2;
      case '배송완료':
        return 3;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: T.paper,
      body: SafeArea(
        child: Column(
          children: [
            const PawdyBar(title: '배송 현황'),
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
                    padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
                    itemCount: orders.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                    itemBuilder: (_, i) => _shippingCard(orders[i]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _shippingCard(Order o) {
    final currentStep = _getStatusStep(o.status);
    final isShippingOrDone = currentStep >= 2;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: T.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('주문번호 #${o.id}',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: T.sub)),
              Text(o.createdAt.split('T').first,
                  style: const TextStyle(
                      fontSize: 12, color: T.muted, fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 6),
          Text(o.summary,
              style: const TextStyle(
                  fontSize: 14.5, color: T.ink, fontWeight: FontWeight.w800)),
          const SizedBox(height: 18),
          
          // 배송 프로세스 스텝 바 (Horizontal Progress Line)
          _stepProgressBar(currentStep),
          const SizedBox(height: 20),

          // 택배사 및 가상 송장번호 노출 영역
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: T.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  isShippingOrDone ? Icons.local_shipping : Icons.info_outline,
                  color: isShippingOrDone ? T.accent : T.muted,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isShippingOrDone ? 'CJ대한통운 배송' : '배송 준비 안내',
                        style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: T.ink),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isShippingOrDone
                            ? '송장번호: 58120309${o.id}'
                            : '판매자가 상품 공급을 준비하고 있습니다.',
                        style: const TextStyle(
                            fontSize: 11.5,
                            color: T.sub,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepProgressBar(int currentStep) {
    final steps = ['결제완료', '배송준비', '배송중', '배송완료'];
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(4, (i) {
        final active = i <= currentStep;
        final current = i == currentStep;
        return Expanded(
          child: Row(
            children: [
              // 스텝 노드
              Column(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: current
                          ? T.accent
                          : (active ? T.ink : Colors.white),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: active ? Colors.transparent : T.line,
                        width: 1.5,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      i == 3 ? Icons.check : Icons.circle,
                      size: i == 3 ? 12 : 6,
                      color: active ? Colors.white : T.muted2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    steps[i],
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: current ? FontWeight.w800 : FontWeight.w600,
                      color: current
                          ? T.accent
                          : (active ? T.ink : T.muted),
                    ),
                  ),
                ],
              ),
              // 연결 라인 (마지막 스텝은 제외)
              if (i < 3)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: Container(
                      height: 2.5,
                      color: i < currentStep ? T.ink : T.line,
                    ),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }

  Widget _empty() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.local_shipping_outlined, size: 40, color: T.muted2),
            SizedBox(height: 10),
            Text('진행 중인 배송 내역이 없습니다',
                style: TextStyle(
                    fontSize: 13.5, color: T.muted, fontWeight: FontWeight.bold)),
          ],
        ),
      );
}
