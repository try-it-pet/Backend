import 'package:flutter/material.dart';
import '../api/client.dart';
import '../theme/tokens.dart';

/// 리뷰 작성 — 별점(1~5) + 텍스트. 성공 시 true 반환(pop).
class ReviewWriteSheet extends StatefulWidget {
  final int productId;
  final String productName;
  const ReviewWriteSheet(
      {super.key, required this.productId, required this.productName});

  @override
  State<ReviewWriteSheet> createState() => _ReviewWriteSheetState();
}

class _ReviewWriteSheetState extends State<ReviewWriteSheet> {
  int _rating = 5;
  final _text = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _toast(String m) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(m), duration: const Duration(milliseconds: 1400)));

  Future<void> _submit() async {
    setState(() => _saving = true);
    try {
      await Api.createReview(widget.productId, _rating, _text.text.trim());
      if (mounted) {
        Navigator.of(context).pop(true);
        _toast('리뷰가 등록됐어요');
      }
    } catch (e) {
      if (mounted) _toast('$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: T.paper,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        padding: const EdgeInsets.fromLTRB(22, 16, 22, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: T.line, borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 16),
            const Text('리뷰 쓰기',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: T.ink)),
            const SizedBox(height: 4),
            Text(widget.productName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 12.5, color: T.muted, fontWeight: FontWeight.w500)),
            const SizedBox(height: 16),
            Row(
              children: [
                for (var i = 1; i <= 5; i++)
                  GestureDetector(
                    onTap: () => setState(() => _rating = i),
                    child: Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Icon(
                        i <= _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                        size: 34,
                        color: i <= _rating ? T.accent : T.line,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _text,
              maxLines: 4,
              style: const TextStyle(fontSize: 14, color: T.ink),
              decoration: InputDecoration(
                hintText: '우리 아이 반응은 어땠나요? (선택)',
                hintStyle: const TextStyle(color: T.muted2, fontSize: 14),
                filled: true,
                fillColor: T.surface,
                contentPadding: const EdgeInsets.all(14),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: T.line),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: T.accent),
                ),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 52,
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: T.accent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15)),
                ),
                child: Text(_saving ? '등록 중…' : '리뷰 등록',
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
