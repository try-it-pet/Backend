import 'package:flutter/material.dart';
import '../api/client.dart';
import '../models/product.dart';
import '../models/commerce.dart';
import '../theme/tokens.dart';
import 'product_register_screen.dart';
import '../state/app_state.dart';


class SellerDashboardScreen extends StatefulWidget {
  const SellerDashboardScreen({super.key});

  @override
  State<SellerDashboardScreen> createState() => _SellerDashboardScreenState();
}

class _SellerDashboardScreenState extends State<SellerDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  List<Product> _products = [];
  List<Order> _orders = [];
  
  bool _loadingProducts = true;
  bool _loadingOrders = true;
  String _ordersSubTab = 'pending'; // 'pending' | 'shipping' | 'completed'
  String _searchQuery = '';
  String _productFilter = 'all'; // 'all' | 'low' | 'out'



  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadProducts();
    _loadOrders();
  }

  Future<void> _loadProducts() async {
    setState(() => _loadingProducts = true);
    try {
      final data = await Api.fetchSellerProducts();
      setState(() => _products = data);
    } catch (e) {
      _toast('상품 조회 실패: $e');
    } finally {
      setState(() => _loadingProducts = false);
    }
  }

  Future<void> _loadOrders() async {
    setState(() => _loadingOrders = true);
    try {
      final data = await Api.fetchSellerOrders();
      setState(() => _orders = data);
    } catch (e) {
      _toast('주문 조회 실패: $e');
    } finally {
      setState(() => _loadingOrders = false);
    }
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(m), duration: const Duration(milliseconds: 1400)),
    );
  }

  void _showShippingInputDialog(Order o, String targetStatus) {
    String selectedCarrier = 'CJ대한통운';
    final trackingCtrl = TextEditingController(text: o.trackingNo ?? '');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          title: Text('$targetStatus 처리', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('배송 택배사', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: T.sub)),
              const SizedBox(height: 6),
              DropdownButton<String>(
                value: selectedCarrier,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: 'CJ대한통운', child: Text('CJ대한통운')),
                  DropdownMenuItem(value: '우체국택배', child: Text('우체국택배')),
                  DropdownMenuItem(value: '한진택배', child: Text('한진택배')),
                  DropdownMenuItem(value: '롯데택배', child: Text('롯데택배')),
                  DropdownMenuItem(value: '로젠택배', child: Text('로젠택배')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setDlgState(() => selectedCarrier = val);
                  }
                },
              ),
              const SizedBox(height: 16),
              const Text('송장번호', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: T.sub)),
              const SizedBox(height: 6),
              TextField(
                controller: trackingCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: '숫자만 입력',
                  isDense: true,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('취소', style: TextStyle(color: T.sub)),
            ),
            TextButton(
              onPressed: () async {
                final trackingNo = trackingCtrl.text.trim();
                if (trackingNo.isEmpty) {
                  _toast('송장번호를 입력해 주세요');
                  return;
                }
                Navigator.of(ctx).pop();
                try {
                  await Api.updateOrderStatus(
                    o.id,
                    targetStatus,
                    carrier: selectedCarrier,
                    trackingNo: trackingNo,
                  );
                  _toast('배송 정보가 등록되어 [$targetStatus] 처리되었습니다');
                  _loadOrders();
                  appState.fetchUnreadNotificationsCount();
                } catch (e) {
                  _toast('배송 처리 실패: $e');
                }
              },

              child: const Text('저장', style: TextStyle(color: T.accent, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }


  void _openEditDialog(Product p) {
    final nameCtrl = TextEditingController(text: p.name);
    final priceCtrl = TextEditingController(text: p.price.toString());
    final stockCtrl = TextEditingController(text: (p.stock ?? 99).toString());
    
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          title: const Text('상품 정보 수정', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: '상품명'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: priceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '가격 (KRW)'),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: stockCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: '재고량'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () {
                        final val = int.tryParse(stockCtrl.text) ?? 0;
                        if (val > 0) {
                          setDlgState(() {
                            stockCtrl.text = (val - 1).toString();
                          });
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(36, 36),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        side: const BorderSide(color: T.line),
                      ),
                      child: const Icon(Icons.remove, size: 16, color: T.sub),
                    ),
                    const SizedBox(width: 4),
                    OutlinedButton(
                      onPressed: () {
                        final val = int.tryParse(stockCtrl.text) ?? 0;
                        setDlgState(() {
                          stockCtrl.text = (val + 1).toString();
                        });
                      },
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(36, 36),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        side: const BorderSide(color: T.line),
                      ),
                      child: const Icon(Icons.add, size: 16, color: T.sub),
                    ),
                    const SizedBox(width: 4),
                    OutlinedButton(
                      onPressed: () {
                        final val = int.tryParse(stockCtrl.text) ?? 0;
                        setDlgState(() {
                          stockCtrl.text = (val + 10).toString();
                        });
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        minimumSize: const Size(40, 36),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        side: const BorderSide(color: T.line),
                      ),
                      child: const Text('+10', style: TextStyle(fontSize: 11, color: T.sub, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('취소', style: TextStyle(color: T.sub)),
            ),
            TextButton(
              onPressed: () async {
                final newName = nameCtrl.text.trim();
                final newPrice = int.tryParse(priceCtrl.text.trim()) ?? p.price;
                final newStock = int.tryParse(stockCtrl.text.trim()) ?? (p.stock ?? 99);
                
                if (newName.isEmpty) {
                  _toast('상품명을 입력해 주세요');
                  return;
                }
                
                Navigator.of(ctx).pop();
                try {
                  await Api.updateProduct(p.id, {
                    'name': newName,
                    'price': newPrice,
                    'stock': newStock,
                  });
                  _toast('상품 정보가 수정되었습니다');
                  _loadProducts();
                } catch (e) {
                  _toast('수정 실패: $e');
                }
              },
              child: const Text('저장', style: TextStyle(color: T.accent, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }


  Future<void> _deleteConfirm(Product p) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('상품 삭제', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text('${p.name} 상품을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소', style: TextStyle(color: T.sub)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('삭제', style: TextStyle(color: T.accent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await Api.deleteProduct(p.id);
        _toast('상품이 삭제되었습니다');
        _loadProducts();
      } catch (e) {
        _toast('삭제 실패: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: T.paper,
      appBar: AppBar(
        title: const Text('내 상점 관리자', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: T.ink)),
        backgroundColor: T.paper,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: T.ink),
          onPressed: () => Navigator.of(context).pop(),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: T.ink,
          unselectedLabelColor: T.muted,
          indicatorColor: T.accent,
          indicatorWeight: 2.5,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: const [
            Tab(text: '등록 상품 관리'),
            Tab(text: '들어온 주문 관리'),
          ],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            _productsTab(),
            _ordersTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color, String filterKey) {
    final isSelected = _productFilter == filterKey;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _productFilter = filterKey),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.08) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? color : T.line, width: isSelected ? 1.5 : 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 4,
                offset: const Offset(0, 2),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: T.muted, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(value, style: TextStyle(fontSize: 14, color: color, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _productsTab() {
    if (_loadingProducts) {
      return const Center(child: CircularProgressIndicator(color: T.accent, strokeWidth: 3));
    }

    final lowStockCount = _products.where((p) => (p.stock ?? 0) > 0 && (p.stock ?? 0) <= 5).length;
    final outOfStockCount = _products.where((p) => p.isOutOfStock).length;

    // 필터링 및 검색 연산
    final filtered = _products.where((p) {
      if (_searchQuery.isNotEmpty && !p.name.toLowerCase().contains(_searchQuery.toLowerCase())) {
        return false;
      }
      if (_productFilter == 'low') {
        final stock = p.stock ?? 0;
        return stock > 0 && stock <= 5;
      } else if (_productFilter == 'out') {
        return p.isOutOfStock;
      }
      return true;
    }).toList();

    return Column(
      children: [
        // 1. 개요 통계 카드 세트
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 6),
          child: Row(
            children: [
              _buildStatCard('전체 상품', '${_products.length}개', T.sub, 'all'),
              const SizedBox(width: 8),
              _buildStatCard('품절 임박', '$lowStockCount개', Colors.orange, 'low'),
              const SizedBox(width: 8),
              _buildStatCard('품절 상품', '$outOfStockCount개', T.accent, 'out'),
            ],
          ),
        ),

        // 2. 검색 바
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: T.line),
            ),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
              style: const TextStyle(fontSize: 13.5, color: T.ink),
              decoration: const InputDecoration(
                hintText: '등록 상품명으로 검색...',
                hintStyle: TextStyle(color: T.muted, fontSize: 13),
                prefixIcon: Icon(Icons.search, size: 18, color: T.muted),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 11),
              ),
            ),
          ),
        ),

        // 3. 상품 목록 수량 정보 & 등록 버튼
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('조회된 상품 ${filtered.length}개', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: T.sub)),
              GestureDetector(
                onTap: () async {
                  await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProductRegisterScreen()));
                  _loadProducts();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: T.accent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.add, size: 14, color: Colors.white),
                      SizedBox(width: 4),
                      Text('새 상품 등록', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: filtered.isEmpty
              ? _emptyState(_searchQuery.isNotEmpty ? '검색 결과와 일치하는 상품이 없습니다' : '조회된 상품이 없습니다')
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _productItem(filtered[i]),
                ),
        ),
      ],
    );
  }


  Widget _productItem(Product p) {
    final imgUrl = Api.imageUrl(p);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: T.line),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: T.soft,
              borderRadius: BorderRadius.circular(10),
            ),
            clipBehavior: Clip.antiAlias,
            child: imgUrl != null ? Image.network(imgUrl, fit: BoxFit.cover) : const Icon(Icons.checkroom, color: T.muted2),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.name, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: T.ink), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text('${won(p.price)}원', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: T.ink)),
                const SizedBox(height: 3),
                Text(p.isOutOfStock ? '품절' : '재고: ${p.stock ?? 0}개', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: p.isOutOfStock ? T.accent : T.sub)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18, color: T.sub),
            onPressed: () => _openEditDialog(p),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 18, color: T.accent),
            onPressed: () => _deleteConfirm(p),
          ),
        ],
      ),
    );
  }

  Widget _ordersTab() {
    if (_loadingOrders) {
      return const Center(child: CircularProgressIndicator(color: T.accent, strokeWidth: 3));
    }

    // 1. 상태별 그룹 분리
    final pendingOrders = _orders.where((o) => o.status == '결제완료' || o.status == '배송준비중').toList();
    final shippingOrders = _orders.where((o) => o.status == '배송중').toList();
    final completedOrders = _orders.where((o) => o.status == '배송완료').toList();

    // 2. 현재 선택된 서브 탭에 맞는 목록 선택
    List<Order> displayOrders;
    if (_ordersSubTab == 'pending') {
      displayOrders = pendingOrders;
    } else if (_ordersSubTab == 'shipping') {
      displayOrders = shippingOrders;
    } else {
      displayOrders = completedOrders;
    }

    return Column(
      children: [
        // 새로고침 헤더
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('주문/배송 관리', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: T.ink)),
              IconButton(
                icon: const Icon(Icons.refresh, size: 18, color: T.sub),
                onPressed: _loadOrders,
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
        ),

        // 세그먼트 탭 필터 바 (디자인 시스템 반영)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: T.soft,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: T.line),
            ),
            child: Row(
              children: [
                _subTabButton('pending', '배송대기', pendingOrders.length),
                _subTabButton('shipping', '배송중', shippingOrders.length),
                _subTabButton('completed', '배송완료', completedOrders.length),
              ],
            ),
          ),
        ),

        const SizedBox(height: 6),

        // 필터링된 주문 리스트 출력
        Expanded(
          child: displayOrders.isEmpty
              ? _emptyState(
                  _ordersSubTab == 'pending'
                      ? '배송 대기 중인 주문이 없습니다'
                      : _ordersSubTab == 'shipping'
                          ? '배송 진행 중인 주문이 없습니다'
                          : '완료된 주문 내역이 없습니다',
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(22, 4, 22, 24),
                  itemCount: displayOrders.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _orderItem(displayOrders[i]),
                ),
        ),
      ],
    );
  }

  Widget _subTabButton(String tabKey, String label, int count) {
    final isSelected = _ordersSubTab == tabKey;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _ordersSubTab = tabKey),
        behavior: HitTestBehavior.opaque,
        child: Container(
          margin: const EdgeInsets.all(4),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.0,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? T.ink : T.sub,
                ),
              ),
              const SizedBox(width: 4),
              // 건수 동그라미 배지 표시
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: isSelected ? T.accent : T.muted2.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : T.sub,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _orderItem(Order o) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: T.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text('주문번호 ${o.orderCode}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: T.ink)),
                  const SizedBox(width: 8),
                  Text('·  구매자: ${o.buyerName ?? '알 수 없음'}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: T.sub)),
                ],
              ),

              DropdownButton<String>(
                value: o.status,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: T.accent),
                underline: const SizedBox.shrink(),
                icon: const Icon(Icons.keyboard_arrow_down, size: 16, color: T.accent),
                items: const [
                  DropdownMenuItem(value: '결제완료', child: Text('결제완료')),
                  DropdownMenuItem(value: '배송준비중', child: Text('배송준비중')),
                  DropdownMenuItem(value: '배송중', child: Text('배송중')),
                  DropdownMenuItem(value: '배송완료', child: Text('배송완료')),
                ],
                onChanged: (val) async {
                  if (val != null && val != o.status) {
                    if (val == '배송중' || val == '배송완료') {
                      _showShippingInputDialog(o, val);
                    } else {
                      try {
                        await Api.updateOrderStatus(o.id, val);
                        _toast('배송 상태가 [$val](으)로 변경되었습니다');
                        _loadOrders();
                        appState.fetchUnreadNotificationsCount();
                      } catch (e) {
                        _toast('상태 변경 실패: $e');
                      }
                    }
                  }
                },

              ),
            ],
          ),
          if (o.carrier != null && o.carrier!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: T.soft,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    o.carrier!,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: T.sub),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '송장: ${o.trackingNo ?? ''}',
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: T.sub),
                ),
              ],
            ),
          ],

          const SizedBox(height: 8),
          Text(o.summary, style: const TextStyle(fontSize: 13, color: T.sub, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text('주문 일자: ${o.createdAt.split('T').first}', style: const TextStyle(fontSize: 11, color: T.muted)),
        ],
      ),
    );
  }

  Widget _emptyState(String text) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inbox_outlined, size: 36, color: T.muted2),
            const SizedBox(height: 8),
            Text(text, style: const TextStyle(fontSize: 12.5, color: T.muted, fontWeight: FontWeight.bold)),
          ],
        ),
      );

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
