import 'package:flutter/material.dart';
import '../api/client.dart';
import '../models/commerce.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import 'toss_payment_screen.dart';
import 'coming_soon_screen.dart' show PawdyBar;


class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  bool _paying = false;

  @override
  void initState() {
    super.initState();
    appState.refreshCartSafe();
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(m), duration: const Duration(milliseconds: 1400)));

  Future<void> _checkout() async {
    if (appState.cart.isEmpty || _paying) return;
    setState(() => _paying = true);
    try {
      final pendingOrder = await Api.createPendingOrder();
      if (mounted) {
        final success = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => TossPaymentScreen(pendingOrder: pendingOrder),
          ),
        );
        if (success == true && mounted) {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) _snack('$e');
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: T.paper,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: appState,
          builder: (_, __) {
            final items = appState.cart;
            return Column(
              children: [
                const PawdyBar(title: '장바구니'),
                Expanded(
                  child: items.isEmpty
                      ? _empty()
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(22, 8, 22, 16),
                          itemCount: items.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (_, i) => _cartCard(items[i]),
                        ),
                ),
                if (items.isNotEmpty) _checkoutBar(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _cartCard(CartItem it) {
    final img = Api.imageUrl(it.product);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: T.line),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 64,
              height: 64,
              color: T.soft,
              child: img == null
                  ? const Icon(Icons.image_outlined, color: T.muted2)
                  : Image.network(img, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(it.product.brand,
                    style: const TextStyle(
                        fontSize: 11.5,
                        color: T.muted2,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(it.product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: T.ink)),
                const SizedBox(height: 4),
                Text('${it.size} · ${it.qty}개',
                    style: const TextStyle(
                        fontSize: 12, color: T.muted, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text('${won(it.product.price * it.qty)}원',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: T.ink)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => appState.removeCartItem(it.id).catchError((e) {
              if (mounted) _snack('$e');
            }),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.close, size: 18, color: T.muted2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _checkoutBar() => Container(
        padding: EdgeInsets.fromLTRB(
            22, 12, 22, 12 + MediaQuery.of(context).padding.bottom),
        decoration: const BoxDecoration(
            color: T.paper, border: Border(top: BorderSide(color: T.line))),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('총 결제금액',
                    style: TextStyle(
                        fontSize: 11.5, color: T.muted, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text('${won(appState.cartTotal)}원',
                    style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        color: T.ink)),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: _paying ? null : _checkout,
                  style: FilledButton.styleFrom(
                    backgroundColor: _paying ? T.muted : T.accent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15)),
                  ),
                  child: Text(_paying ? '결제 중…' : '결제하기',
                      style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white)),
                ),
              ),
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
              child: const Icon(Icons.shopping_bag_outlined,
                  color: Color(0xFFC4BDB3), size: 28),
            ),
            const SizedBox(height: 18),
            const Text('장바구니가 비어 있어요',
                style: TextStyle(
                    fontSize: 14, color: T.muted, fontWeight: FontWeight.w600)),
          ],
        ),
      );
}
