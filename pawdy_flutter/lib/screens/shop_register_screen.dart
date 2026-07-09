import 'package:flutter/material.dart';
import '../api/client.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';

class ShopRegisterScreen extends StatefulWidget {
  const ShopRegisterScreen({super.key});

  @override
  State<ShopRegisterScreen> createState() => _ShopRegisterScreenState();
}

class _ShopRegisterScreenState extends State<ShopRegisterScreen> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  bool _loading = false;

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(m), duration: const Duration(milliseconds: 1400)),
    );
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final desc = _descController.text.trim();

    if (name.isEmpty) {
      _toast('상점 이름을 입력해 주세요');
      return;
    }

    setState(() => _loading = true);

    try {
      await Api.createShop(name, desc.isEmpty ? null : desc);
      await appState.refreshShop();
      _toast('상점 개설이 완료되었습니다');
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      _toast('$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: T.paper,
      appBar: AppBar(
        title: const Text('판매자 상점 등록',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w800, color: T.ink)),
        backgroundColor: T.paper,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: T.ink),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('나만의 상점을 개설하여\n반려동물 용품을 직접 판매해 보세요.',
                  style: TextStyle(
                      fontSize: 18,
                      height: 1.45,
                      fontWeight: FontWeight.w800,
                      color: T.ink)),
              const SizedBox(height: 28),
              const Text('상점/브랜드 이름 *',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: T.sub)),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: '예: maxbone, Ruffwear 등',
                  hintStyle: const TextStyle(color: T.muted2, fontSize: 13.5),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: T.line),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: T.line),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: T.accent),
                  ),
                ),
                style: const TextStyle(fontSize: 14.5, color: T.ink),
              ),
              const SizedBox(height: 20),
              const Text('상점 소개글',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: T.sub)),
              const SizedBox(height: 8),
              TextField(
                controller: _descController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: '상점이나 브랜드를 한 줄로 간단히 소개해 주세요.',
                  hintStyle: const TextStyle(color: T.muted2, fontSize: 13.5),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: T.line),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: T.line),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: T.accent),
                  ),
                ),
                style: const TextStyle(fontSize: 14.5, color: T.ink),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: _loading ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: _loading ? T.muted : T.accent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('상점 등록 완료',
                          style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }
}
