import 'package:flutter/material.dart';
import '../api/client.dart';
import '../models/commerce.dart';
import '../theme/tokens.dart';
import 'coming_soon_screen.dart' show PawdyBar;

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  List<NotificationItem> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _loading = true);
    try {
      final data = await Api.fetchNotifications();
      setState(() {
        _items = data;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      _toast('알림 목록을 불러오지 못했습니다: $e');
    }
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(m), duration: const Duration(milliseconds: 1400)),
    );
  }

  Future<void> _markRead(NotificationItem item) async {
    if (item.isRead) return;
    try {
      await Api.markNotificationRead(item.id);
      // 로컬 리스트 갱신
      setState(() {
        final idx = _items.indexWhere((x) => x.id == item.id);
        if (idx != -1) {
          _items[idx] = NotificationItem(
            id: item.id,
            userId: item.userId,
            title: item.title,
            content: item.content,
            isRead: true,
            createdAt: item.createdAt,
          );
        }
      });
    } catch (e) {
      _toast('읽음 처리 실패: $e');
    }
  }

  Future<void> _markAllRead() async {
    if (_items.isEmpty || _items.every((x) => x.isRead)) return;
    try {
      await Api.markAllNotificationsRead();
      _toast('모든 알림을 읽음 처리했습니다');
      _loadNotifications();
    } catch (e) {
      _toast('처리 실패: $e');
    }
  }

  Future<void> _clearAll() async {
    if (_items.isEmpty) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('알림 전체 삭제', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: const Text('수신된 모든 알림을 삭제하시겠습니까?'),
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
        await Api.deleteAllNotifications();
        _toast('알림이 모두 삭제되었습니다');
        setState(() => _items = []);
      } catch (e) {
        _toast('삭제 실패: $e');
      }
    }
  }

  Future<void> _deleteItem(NotificationItem item) async {
    try {
      await Api.deleteNotification(item.id);
      setState(() {
        _items.removeWhere((x) => x.id == item.id);
      });
    } catch (e) {
      _toast('알림 삭제 실패: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: T.paper,
      body: SafeArea(
        child: Column(
          children: [
            const PawdyBar(title: '알림 센터'),
            
            // 전체 읽음 및 전체 삭제 메뉴 바
            if (!_loading && _items.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: _markAllRead,
                      icon: const Icon(Icons.done_all, size: 16, color: T.sub),
                      label: const Text('모두 읽음', style: TextStyle(color: T.sub, fontSize: 12.5, fontWeight: FontWeight.w600)),
                      style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                    ),
                    const SizedBox(width: 16),
                    TextButton.icon(
                      onPressed: _clearAll,
                      icon: const Icon(Icons.delete_outline, size: 16, color: T.accent),
                      label: const Text('전체 삭제', style: TextStyle(color: T.accent, fontSize: 12.5, fontWeight: FontWeight.w600)),
                      style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                    ),
                  ],
                ),
              ),

            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: T.accent, strokeWidth: 3))
                  : _items.isEmpty
                      ? _empty()
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(22, 4, 22, 24),
                          itemCount: _items.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (ctx, i) => _dismissibleCard(_items[i]),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dismissibleCard(NotificationItem item) {
    return Dismissible(
      key: Key('notif_${item.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: T.accent.withOpacity(0.9),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete, color: Colors.white, size: 24),
      ),
      onDismissed: (_) => _deleteItem(item),
      child: GestureDetector(
        onTap: () => _markRead(item),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: item.isRead ? Colors.white : const Color(0xFFFAF7F2), // 읽지 않은 알림은 옅은 샌드베이지색
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: item.isRead ? T.line : T.accent.withOpacity(0.3),
              width: item.isRead ? 1.0 : 1.5,
            ),
            boxShadow: item.isRead
                ? null
                : [
                    BoxShadow(
                      color: T.accent.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 아이콘 지시자
              Container(
                margin: const EdgeInsets.only(top: 2),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: item.isRead ? Colors.transparent : T.accent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          item.title,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: item.isRead ? FontWeight.bold : FontWeight.w900,
                            color: item.isRead ? T.sub : T.ink,
                          ),
                        ),
                        Text(
                          item.createdAt.split('T').first,
                          style: const TextStyle(fontSize: 11, color: T.muted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.content,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.45,
                        color: item.isRead ? T.muted : T.sub,
                        fontWeight: item.isRead ? FontWeight.w500 : FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _empty() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.notifications_none_outlined, size: 40, color: T.muted2),
            SizedBox(height: 10),
            Text('새로운 알림이 없습니다',
                style: TextStyle(
                    fontSize: 13.5, color: T.muted, fontWeight: FontWeight.bold)),
          ],
        ),
      );
}
