import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';


/// 우리 아이 등록 폼 — 이름·종·체중·체형 치수(사이즈 추천용).
class PetFormSheet extends StatefulWidget {
  const PetFormSheet({super.key});

  @override
  State<PetFormSheet> createState() => _PetFormSheetState();
}

class _PetFormSheetState extends State<PetFormSheet> {
  final _name = TextEditingController();
  final _weight = TextEditingController();
  final _chest = TextEditingController();
  final _neck = TextEditingController();
  final _back = TextEditingController();
  String _species = 'dog';
  bool _saving = false;

  Uint8List? _imageBytes;
  String? _imageName;

  @override
  void dispose() {
    for (final c in [_name, _weight, _chest, _neck, _back]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (file != null) {
        final bytes = await file.readAsBytes();
        setState(() {
          _imageBytes = bytes;
          _imageName = file.name;
        });
      }
    } catch (e) {
      _toast('이미지 선택에 실패했습니다: $e');
    }
  }

  void _clearImage() {
    setState(() {
      _imageBytes = null;
      _imageName = null;
    });
  }

  double? _num(TextEditingController c) =>
      c.text.trim().isEmpty ? null : double.tryParse(c.text.trim());

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      _toast('이름을 입력해주세요');
      return;
    }
    setState(() => _saving = true);
    try {
      await appState.registerPet(
        name: name,
        species: _species,
        weightKg: _num(_weight),
        chestCm: _num(_chest),
        neckCm: _num(_neck),
        backCm: _num(_back),
        imageBytes: _imageBytes,
        imageName: _imageName,
      );
      if (mounted) {
        Navigator.of(context).pop();
        _toast('$name 등록됐어요');
      }
    } catch (e) {
      if (mounted) _toast('$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }


  void _toast(String m) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(m), duration: const Duration(milliseconds: 1400)));

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
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
                    color: T.line, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            const Text('우리 아이 등록',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: T.ink)),
            const SizedBox(height: 4),
            const Text('체형 치수를 입력하면 AI가 딱 맞는 사이즈를 추천해요',
                style: TextStyle(
                    fontSize: 12.5, color: T.muted, fontWeight: FontWeight.w500)),
            const SizedBox(height: 16),
            const SizedBox(height: 16),
            Center(
              child: Stack(
                children: [
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: T.soft,
                        shape: BoxShape.circle,
                        border: Border.all(color: T.line, width: 1.5),
                      ),
                      child: ClipOval(
                        child: _imageBytes != null
                            ? Image.memory(
                                _imageBytes!,
                                fit: BoxFit.cover,
                              )
                            : const Icon(
                                Icons.camera_alt_outlined,
                                size: 28,
                                color: T.muted,
                              ),
                      ),
                    ),
                  ),
                  if (_imageBytes != null)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _clearImage,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            size: 12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _field(_name, '이름'),

            const SizedBox(height: 10),
            Row(
              children: [
                for (final sp in const [
                  ['dog', '강아지'],
                  ['cat', '고양이']
                ])
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: sp[0] == 'dog' ? 8 : 0),
                      child: _speciesBtn(sp[0], sp[1]),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _field(_weight, '몸무게(kg)', number: true)),
              const SizedBox(width: 8),
              Expanded(child: _field(_chest, '가슴둘레(cm)', number: true)),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _field(_neck, '목둘레(cm)', number: true)),
              const SizedBox(width: 8),
              Expanded(child: _field(_back, '등길이(cm)', number: true)),
            ]),
            const SizedBox(height: 18),
            SizedBox(
              height: 52,
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: T.accent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15)),
                ),
                child: Text(_saving ? '등록 중…' : '등록하기',
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

  Widget _field(TextEditingController c, String hint, {bool number = false}) =>
      SizedBox(
        height: 46,
        child: TextField(
          controller: c,
          keyboardType: number
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          inputFormatters: number
              ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]
              : null,
          style: const TextStyle(fontSize: 14, color: T.ink),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: T.muted2, fontSize: 14),
            filled: true,
            fillColor: T.surface,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
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
      );

  Widget _speciesBtn(String key, String label) {
    final on = _species == key;
    return SizedBox(
      height: 44,
      child: OutlinedButton(
        onPressed: () => setState(() => _species = key),
        style: OutlinedButton.styleFrom(
          backgroundColor: on ? T.accentSoft : T.surface,
          side: BorderSide(color: on ? T.accent : T.line, width: on ? 1.5 : 1),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(label,
            style: TextStyle(
                color: on ? T.accent : T.sub,
                fontSize: 14,
                fontWeight: FontWeight.w700)),
      ),
    );
  }
}
