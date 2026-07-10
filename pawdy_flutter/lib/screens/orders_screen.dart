import 'package:flutter/material.dart';
import '../api/client.dart';
import '../models/commerce.dart';
import '../theme/tokens.dart';
import 'coming_soon_screen.dart' show PawdyBar;
import 'detail_screen.dart';
import 'review_write_sheet.dart';



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

  Future<void> _confirmOrder(int orderId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: const Text('구매 확정', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: T.ink)),
        content: const Text('구매 확정을 진행하시겠습니까?\n구매 확정 후에는 교환/반품이 불가합니다.', style: TextStyle(color: T.sub, fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('취소', style: TextStyle(color: T.sub))),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('확인', style: TextStyle(color: T.accent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await Api.confirmOrder(orderId);
        setState(() {
          _future = Api.fetchOrders();
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('구매 확정이 정상 처리되었습니다.'), backgroundColor: T.accent),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('구매 확정 실패: $e')),
          );
        }
      }
    }
  }

  void _openReviewSheet(int productId, String productName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReviewWriteSheet(productId: productId, productName: productName),
    ).then((ok) {
      if (ok == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('리뷰가 성공적으로 등록되었습니다!'), backgroundColor: T.accent),
        );
      }
    });
  }

  void _showProductSelectForReview(Order o) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '리뷰를 작성할 상품을 선택해 주세요',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: T.ink),
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: o.items.length,
                    separatorBuilder: (_, __) => const Divider(color: T.line, height: 1),
                    itemBuilder: (context, idx) {
                      final it = o.items[idx];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            width: 40,
                            height: 40,
                            color: T.soft,
                            child: Api.imageUrl(it.product) != null
                                ? Image.network(Api.imageUrl(it.product)!, fit: BoxFit.cover)
                                : const Icon(Icons.shopping_bag_outlined, color: T.muted),
                          ),
                        ),
                        title: Text(
                          it.product.name,
                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: T.ink),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '사이즈: ${it.size}',
                          style: const TextStyle(fontSize: 11, color: T.muted),
                        ),
                        trailing: const Icon(Icons.edit_note, color: T.accent),
                        onTap: () {
                          Navigator.of(ctx).pop();
                          _openReviewSheet(it.product.id, it.product.name);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
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
            
            if (o.status == '배송중' || o.status == '배송완료' || o.status == '구매확정') ...[
              const Divider(height: 20, color: T.line),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (o.status == '배송중' || o.status == '배송완료')
                    OutlinedButton(
                      onPressed: () => _confirmOrder(o.id),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: T.sub,
                        side: const BorderSide(color: T.line),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                      child: const Text('구매확정', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  if (o.status == '구매확정')
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: T.soft,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('구매확정 완료', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: T.muted)),
                    ),
                  const SizedBox(width: 8),
                  if (o.status == '배송완료' || o.status == '구매확정')
                    ElevatedButton(
                      onPressed: () {
                        if (o.items.length == 1) {
                          _openReviewSheet(o.items[0].product.id, o.items[0].product.name);
                        } else {
                          _showProductSelectForReview(o);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: T.accent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                      child: const Text('리뷰작성', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
            ],

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
