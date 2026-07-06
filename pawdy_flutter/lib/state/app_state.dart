import 'package:flutter/foundation.dart';
import '../api/client.dart';
import '../models/product.dart';

/// 화면 간 공유 상태(상품 카탈로그 1회 로드 + 찜). 간단히 전역 ChangeNotifier 싱글턴.
class AppState extends ChangeNotifier {
  List<Product> products = [];
  bool loading = true;
  bool error = false;
  final Set<int> likedIds = {};

  Future<void> load() async {
    loading = true;
    error = false;
    notifyListeners();
    try {
      products = await Api.fetchProducts();
    } catch (_) {
      error = true;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  bool isLiked(int id) => likedIds.contains(id);

  void toggleLike(int id) {
    if (!likedIds.remove(id)) likedIds.add(id);
    notifyListeners();
  }

  List<Product> get liked =>
      products.where((p) => likedIds.contains(p.id)).toList();
}

final appState = AppState();
