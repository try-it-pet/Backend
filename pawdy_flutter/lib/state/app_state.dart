import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api/client.dart';
import '../models/product.dart';
import '../models/user.dart';
import '../models/commerce.dart';
import '../models/shop.dart';
import '../services/notification_service.dart';



/// 화면 간 공유 상태: 상품·찜·인증(카카오 딥링크)·펫·통계. 전역 ChangeNotifier 싱글턴.
class AppState extends ChangeNotifier {
  // 카탈로그
  List<Product> products = [];
  bool loading = true;
  bool error = false;

  // 찜(로그인 시 백엔드와 동기화, 비로그인 시 로컬)
  final Set<int> likedIds = {};

  // 인증/계정
  User? user;
  Shop? shop;
  List<Pet> pets = [];

  Stats? stats;
  List<CartItem> cart = [];
  int unreadNotificationsCount = 0;
  int? _lastMaxNotifId;
  bool get loggedIn => user != null;
  int get cartCount => cart.fold(0, (n, it) => n + it.qty);

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSub;

  Future<void> load({String? q}) async {
    loading = true;
    error = false;
    notifyListeners();
    try {
      products = await Api.fetchProducts(q: q);
    } catch (_) {
      error = true;
    } finally {
      loading = false;
      notifyListeners();
    }
  }


  Future<void> fetchUnreadNotificationsCount() async {
    if (!loggedIn) {
      unreadNotificationsCount = 0;
      _lastMaxNotifId = null;
      notifyListeners();
      return;
    }
    try {
      final notifs = await Api.fetchNotifications();
      unreadNotificationsCount = notifs.where((n) => !n.isRead).length;

      if (notifs.isNotEmpty) {
        final currentMaxId = notifs.map((n) => n.id).fold(0, (max, id) => id > max ? id : max);
        if (_lastMaxNotifId != null && currentMaxId > _lastMaxNotifId!) {
          // 새 알림 존재! 읽지 않은 새로운 알림을 시스템 팝업 노출
          final newUnreads = notifs.where((n) => !n.isRead && n.id > _lastMaxNotifId!);
          for (final n in newUnreads) {
            await NotificationService.showNotification(title: n.title, body: n.content);
          }
        }
        _lastMaxNotifId = currentMaxId;
      }
      notifyListeners();
    } catch (_) {}
  }

  
  
  /// 앱 시작 시 딥링크 리스너 등록(카카오 로그인 후 pawdy://login?token= 수신).
  Future<void> initDeepLinks() async {
    _linkSub = _appLinks.uriLinkStream.listen(_onLink, onError: (_) {});
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) _onLink(initial);
    } catch (_) {}
  }

  void _onLink(Uri uri) {
    final token = uri.queryParameters['token'];
    if (token != null && token.isNotEmpty) {
      Api.setToken(token);
      _afterLogin();
    }
  }

  // ── 로그인 ──
  Future<void> startKakaoLogin() async {
    final uri = Uri.parse(Api.kakaoLoginUrl());
    await launchUrl(uri, mode: LaunchMode.externalApplication);
    // 이후 카카오 콜백 → pawdy://login?token= 딥링크가 _onLink 로 들어옴
  }

  Future<void> devLogin() async {
    user = await Api.devLogin();
    notifyListeners();
    await _afterLogin();
  }

  Future<void> _afterLogin() async {
    user = await Api.fetchMe();
    if (user == null) return;
    try {
      final ids = await Api.fetchLikes();
      likedIds
        ..clear()
        ..addAll(ids);
    } catch (_) {}
    try {
      pets = await Api.fetchPets();
    } catch (_) {}
    try {
      stats = await Api.fetchStats();
    } catch (_) {}
    try {
      cart = await Api.fetchCart();
    } catch (_) {}
    try {
      shop = await Api.fetchMyShop();
    } catch (_) {}
    try {
      await fetchUnreadNotificationsCount();
    } catch (_) {}
    notifyListeners();
  }


  void logout() {
    Api.setToken(null);
    user = null;
    shop = null;
    pets = [];
    stats = null;
    cart = [];
    unreadNotificationsCount = 0;
    likedIds.clear();
    notifyListeners();
  }


  Future<void> refreshShop() async {
    if (!loggedIn) return;
    try {
      shop = await Api.fetchMyShop();
      notifyListeners();
    } catch (_) {}
  }


  // ── 찜 ──
  bool isLiked(int id) => likedIds.contains(id);

  void toggleLike(int id) {
    if (!likedIds.remove(id)) likedIds.add(id); // 낙관적
    notifyListeners();
    if (loggedIn) {
      Api.toggleLike(id).then((ids) {
        likedIds
          ..clear()
          ..addAll(ids);
        notifyListeners();
      }).catchError((_) {});
    }
  }

  List<Product> get liked =>
      products.where((p) => likedIds.contains(p.id)).toList();

  // ── 장바구니 / 결제 ──
  Future<void> addToCart(int productId, String size) async {
    cart = await Api.addToCart(productId, size);
    notifyListeners();
  }

  Future<void> refreshCartSafe() async {
    if (!loggedIn) return;
    try {
      cart = await Api.fetchCart();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> removeCartItem(int itemId) async {
    cart = await Api.removeCartItem(itemId);
    notifyListeners();
  }

  int get cartTotal =>
      cart.fold(0, (sum, it) => sum + it.product.price * it.qty);

  Future<Order> checkout() async {
    final order = await Api.checkout();
    cart = [];
    notifyListeners();
    try {
      stats = await Api.fetchStats(); // 주문 수 갱신
      await fetchUnreadNotificationsCount(); // 알림 배지 개수 갱신
    } catch (_) {}
    notifyListeners();
    return order;
  }


  // ── 펫 ──
  Future<void> registerPet(Map<String, dynamic> body) async {
    final p = await Api.createPet(body);
    if (p != null) {
      pets = [...pets, p];
      notifyListeners();
    }
  }

  Pet? get firstPet => pets.isNotEmpty ? pets.first : null;

  @override
  void dispose() {
    _linkSub?.cancel();
    super.dispose();
  }
}

final appState = AppState();
