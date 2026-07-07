import 'package:flutter/material.dart';
import '../api/client.dart';
import '../models/fitting.dart';
import '../theme/tokens.dart';
import 'coming_soon_screen.dart' show PawdyBar;

class FittingHistoryScreen extends StatefulWidget {
  const FittingHistoryScreen({super.key});

  @override
  State<FittingHistoryScreen> createState() => _FittingHistoryScreenState();
}

class _FittingHistoryScreenState extends State<FittingHistoryScreen> {
  late Future<List<Fitting>> _future;

  @override
  void initState() {
    super.initState();
    _future = Api.fetchFittings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: T.paper,
      body: SafeArea(
        child: Column(
          children: [
            const PawdyBar(title: 'AI 피팅 기록'),
            Expanded(
              child: FutureBuilder<List<Fitting>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator(
                            color: T.accent, strokeWidth: 3));
                  }
                  // mock(데모 SVG)은 갤러리에서 제외 — 실제 생성만 표시
                  final items =
                      (snap.data ?? []).where((f) => !f.isSvg).toList();
                  if (snap.hasError || items.isEmpty) return _empty();
                  return GridView.builder(
                    padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: 0.8,
                    ),
                    itemCount: items.length,
                    itemBuilder: (_, i) => _cell(items[i]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cell(Fitting f) {
    final url = Api.resultImageUrl(f.imageUrl);
    return GestureDetector(
      onTap: f.isSvg ? null : () => _openViewer(url),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              color: T.soft,
              child: f.isSvg
                  ? const _MockPlaceholder()
                  : Image.network(url,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const _MockPlaceholder()),
            ),
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(999)),
                child: Text(f.isFourcut ? '인생네컷' : 'AI 피팅',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700)),
              ),
            ),
            Positioned(
              bottom: 8,
              left: 10,
              child: Text(f.createdAt.split('T').first,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      shadows: const [
                        Shadow(color: Colors.black45, blurRadius: 4)
                      ])),
            ),
          ],
        ),
      ),
    );
  }

  void _openViewer(String url) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      builder: (_) => GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: InteractiveViewer(
          child: Center(
            child: Image.network(url,
                errorBuilder: (_, __, ___) => const Icon(Icons.broken_image,
                    color: Colors.white38, size: 48)),
          ),
        ),
      ),
    );
  }

  Widget _empty() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                  color: T.soft, borderRadius: BorderRadius.circular(18)),
              child: const Icon(Icons.auto_awesome,
                  color: Color(0xFFC4BDB3), size: 28),
            ),
            const SizedBox(height: 18),
            const Text('아직 AI 피팅 기록이 없어요',
                style: TextStyle(
                    fontSize: 14, color: T.muted, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            const Text('AI 피팅 탭에서 우리 아이에게 옷을 입혀보세요',
                style: TextStyle(
                    fontSize: 12.5, color: T.muted2, fontWeight: FontWeight.w500)),
          ],
        ),
      );
}

class _MockPlaceholder extends StatelessWidget {
  const _MockPlaceholder();
  @override
  Widget build(BuildContext context) => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome, color: T.muted2, size: 26),
            SizedBox(height: 6),
            Text('미리보기(mock)',
                style: TextStyle(
                    fontSize: 11, color: T.muted2, fontWeight: FontWeight.w600)),
          ],
        ),
      );
}
