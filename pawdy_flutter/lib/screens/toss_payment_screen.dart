import 'package:flutter/material.dart';
import '../models/commerce.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';

/// 토스페이먼츠(Toss Payments) 결제창 대행 및 승인 시뮬레이션 스크린
class TossPaymentScreen extends StatefulWidget {
  final Order pendingOrder;
  const TossPaymentScreen({super.key, required this.pendingOrder});

  @override
  State<TossPaymentScreen> createState() => _TossPaymentScreenState();
}

class _TossPaymentScreenState extends State<TossPaymentScreen> {
  bool _loading = false;
  String _payMethod = 'card'; // 'card' | 'toss' | 'transfer'

  Future<void> _processPayment() async {
    setState(() => _loading = true);

    // 모의 결제 키 생성 (실제 토스 결제 완료 시 리다이렉트되어 오는 paymentKey 값 역할)
    final mockPaymentKey = 'toss_pk_${DateTime.now().millisecondsSinceEpoch}';

    try {
      // 백엔드의 /me/payments/confirm API를 호출하여 Toss Payments 검증을 수행
      final order = await appState.confirmPayment(
        paymentKey: mockPaymentKey,
        orderId: widget.pendingOrder.id,
        amount: widget.pendingOrder.total,
      );

      if (mounted) {
        // 결제 승인 성공 시 완료 알림 후 화면 탈출
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('결제가 정상 완료되었습니다! (주문번호 ${order.orderCode})'),
            backgroundColor: T.accent,
            duration: const Duration(seconds: 2),
          ),
        );
        Navigator.of(context).pop(true); // 성공 플래그와 함께 이전 화면으로 복귀
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('결제 승인 실패: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.pendingOrder;

    return Scaffold(
      backgroundColor: T.paper,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.close, color: T.ink),
          onPressed: () => Navigator.of(context).pop(false),
        ),
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'toss',
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w900,
                fontSize: 22,
                color: Color(0xFF0064FF), // 토스 블루 고유 브랜드 컬러
                letterSpacing: -0.5,
              ),
            ),
            Text(
              ' payments',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: T.ink,
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: _loading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Color(0xFF0064FF), strokeWidth: 3),
                  const SizedBox(height: 20),
                  Text(
                    '결제 승인을 요청하고 있습니다...',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: T.sub,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '잠시만 기다려 주세요.',
                    style: TextStyle(
                      fontSize: 13,
                      color: T.muted2,
                    ),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 주문 금액 안내 카드
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F4F7),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '결제할 금액',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: T.muted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${order.total.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}원',
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: T.ink,
                          ),
                        ),
                        const Divider(height: 24, color: T.line),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('주문 정보', style: TextStyle(fontSize: 13, color: T.muted)),
                            Text('주문번호 #${order.id}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: T.sub)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  const Text(
                    '결제 수단 선택',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: T.ink,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 결제 수단 라디오 리스트
                  _payMethodTile('card', '신용/체크카드', Icons.credit_card),
                  _payMethodTile('toss', '토스페이 (Toss Pay)', Icons.account_balance_wallet_outlined),
                  _payMethodTile('transfer', '실시간 계좌이체', Icons.swap_horiz_outlined),

                  const SizedBox(height: 48),

                  // 결제하기 버튼
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _processPayment,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0064FF),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        '결제하기',
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Center(
                    child: Text(
                      '본 화면은 Toss Payments API 연동 시뮬레이터입니다.\n[결제하기] 클릭 시 즉시 백엔드 승인이 검증 및 진행됩니다.',
                      style: TextStyle(
                        fontSize: 11,
                        color: T.muted2,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _payMethodTile(String method, String label, IconData icon) {
    final selected = _payMethod == method;
    return GestureDetector(
      onTap: () => setState(() => _payMethod = method),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? const Color(0xFF0064FF) : T.line,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? const Color(0xFF0064FF) : T.muted),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                color: selected ? const Color(0xFF0064FF) : T.sub,
              ),
            ),
            const Spacer(),
            if (selected)
              const Icon(Icons.check_circle, color: Color(0xFF0064FF), size: 20)
            else
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: T.line, width: 2),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
