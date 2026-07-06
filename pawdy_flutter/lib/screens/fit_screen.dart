import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../api/client.dart';
import '../models/product.dart';
import '../models/tryon.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';

class FitScreen extends StatefulWidget {
  const FitScreen({super.key});

  @override
  State<FitScreen> createState() => _FitScreenState();
}

class _FitScreenState extends State<FitScreen> {
  static const petName = '초코';

  String _provider = 'mock'; // mock=키불필요 / openai / replicate
  String _style = 'winter';
  String _composition = 'front_full';
  String _size = 'M';

  List<Product> _fittable = [];
  int? _fitId; // 선택된 옷 상품 id

  Uint8List? _photo;
  bool _loading = false;
  TryOnResult? _result;
  String _msg = '';

  static const _providers = ['mock', 'openai', 'replicate'];
  static const _styles = [
    ['winter', '겨울 감성'],
    ['ghibli', '지브리'],
    ['riso', '리소'],
    ['mood', '무드'],
  ];
  static const _comps = [
    ['front_full', '정면 전신'],
    ['side', '측면'],
    ['closeup', '클로즈업'],
    ['sitting', '앉은 자세'],
  ];

  @override
  void initState() {
    super.initState();
    Api.fetchProducts().then((all) {
      if (!mounted) return;
      setState(() {
        _fittable = all.where((p) => p.fittable).toList();
        _fitId = _fittable.isNotEmpty ? _fittable.first.id : null;
      });
    }).catchError((_) {});
  }

  Product? get _selected {
    for (final p in _fittable) {
      if (p.id == _fitId) return p;
    }
    return _fittable.isNotEmpty ? _fittable.first : null;
  }

  Future<void> _pickPhoto() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (x == null) return;
    final bytes = await x.readAsBytes();
    setState(() {
      _photo = bytes;
      _result = null;
      _msg = '';
    });
  }

  Future<void> _run({required bool fourcut}) async {
    final product = _selected;
    if (_loading || product == null) return;
    if (_provider != 'mock' && _photo == null) {
      setState(() =>
          _msg = fourcut ? '펫 사진을 추가하면 인생네컷을 만들어드려요' : '펫 사진을 추가하면 AI가 입혀드려요');
      return;
    }
    setState(() {
      _loading = true;
      _result = null;
      _msg = '';
    });
    try {
      if (!Api.isLoggedIn) await appState.devLogin(); // 미로그인 시 둘러보기 토큰(quota/인증)
      final petId = appState.firstPet?.id;
      final job = fourcut
          ? await Api.runFourcut(
              productId: product.id,
              size: _size,
              provider: _provider,
              petId: petId,
              style: _style,
              petImageBytes: _photo,
            )
          : await Api.runTryOn(
              productId: product.id,
              size: _size,
              provider: _provider,
              petId: petId,
              style: _style,
              composition: _composition,
              background: _style == 'studio' ? 'studio' : 'keep',
              petImageBytes: _photo,
            );
      if (!mounted) return;
      if (job.isDone && job.result != null) {
        setState(() => _result = job.result);
      } else {
        setState(() => _msg = job.error ?? '생성 실패');
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _msg = e.message);
    } catch (e) {
      if (mounted) setState(() => _msg = '백엔드 연결이 필요해요');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = _selected;
    return Container(
      color: T.paper,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const SizedBox(height: 6),
            const Text('AI 피팅',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: T.ink)),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  _chipRow('AI 모델', _providers,
                      (p) => p == 'openai' ? 'gpt-image-2' : p, _provider,
                      (v) => setState(() {
                            _provider = v;
                            _result = null;
                          }),
                      dark: true),
                  _labeledChips('감성 룩', _styles, _style,
                      (v) => setState(() => _style = v)),
                  _labeledChips('구도', _comps, _composition,
                      (v) => setState(() => _composition = v)),
                  _preview(),
                  _scoreCards(product),
                  _garmentPicker(),
                  _runButtons(),
                  _analysis(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chipRow(String label, List<String> keys, String Function(String) text,
      String current, ValueChanged<String> onTap,
      {bool dark = false}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 2),
      child: Row(
        children: [
          SizedBox(
              width: 44,
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 11,
                      color: T.muted,
                      fontWeight: FontWeight.w600))),
          Expanded(
            child: Wrap(
              spacing: 6,
              children: keys.map((k) {
                final on = current == k;
                return GestureDetector(
                  onTap: () => onTap(k),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: on ? (dark ? T.ink : T.accent) : T.surface,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: on ? Colors.transparent : T.line),
                    ),
                    child: Text(text(k),
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: on ? Colors.white : T.sub)),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _labeledChips(String label, List<List<String>> opts, String current,
          ValueChanged<String> onTap) =>
      _chipRow(
        label,
        opts.map((e) => e[0]).toList(),
        (k) => opts.firstWhere((e) => e[0] == k)[1],
        current,
        onTap,
      );

  Widget _preview() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 0),
      child: AspectRatio(
        aspectRatio: 4 / 5,
        child: Container(
          decoration: BoxDecoration(
            color: T.soft,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: T.line),
          ),
          clipBehavior: Clip.antiAlias,
          child: _loading
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: T.accent, strokeWidth: 3),
                      SizedBox(height: 16),
                      Text('AI가 $petName에게 입히는 중…',
                          style: TextStyle(
                              fontSize: 13,
                              color: T.sub,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                )
              : _result != null && _result!.imageUrl.isNotEmpty
                  ? Image.network(Api.resultImageUrl(_result!.imageUrl),
                      fit: BoxFit.cover)
                  : _photo != null
                      ? Image.memory(_photo!, fit: BoxFit.cover)
                      : _addPhotoButton(),
        ),
      ),
    );
  }

  Widget _addPhotoButton() => Center(
        child: GestureDetector(
          onTap: _pickPhoto,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: T.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: T.line),
                ),
                child: const Icon(Icons.photo_camera_outlined,
                    color: T.accent, size: 24),
              ),
              const SizedBox(height: 10),
              Text('$petName 사진 추가',
                  style: const TextStyle(
                      fontSize: 13, color: T.sub, fontWeight: FontWeight.w600)),
              if (_msg.isNotEmpty) ...[
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Text(_msg,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 11, color: T.muted)),
                ),
              ],
            ],
          ),
        ),
      );

  Widget _scoreCards(Product? product) {
    final score = _result?.fitScore ?? product?.fit ?? 0;
    final recSize = _result?.recommendedSize ?? _size;
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 0),
      child: Row(
        children: [
          Expanded(child: _card('AI 핏 스코어', _loading ? '…' : '$score%', T.accent)),
          const SizedBox(width: 10),
          Expanded(child: _card('추천 사이즈', recSize, T.ink)),
        ],
      ),
    );
  }

  Widget _card(String label, String value, Color valueColor) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: T.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 11.5, color: T.muted, fontWeight: FontWeight.w600)),
            const SizedBox(height: 3),
            Text(value,
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: valueColor)),
          ],
        ),
      );

  Widget _garmentPicker() {
    if (_fittable.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(22, 24, 22, 0),
          child: Text('입혀볼 옷',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: T.ink)),
        ),
        SizedBox(
          height: 74,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 4),
            itemCount: _fittable.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final p = _fittable[i];
              final on = p.id == _fitId;
              final img = Api.imageUrl(p);
              return GestureDetector(
                onTap: () => setState(() {
                  _fitId = p.id;
                  _result = null;
                }),
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: on ? T.accent : Colors.transparent, width: 2),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Container(
                    color: T.soft,
                    child: img == null
                        ? const Icon(Icons.checkroom, color: T.muted2, size: 22)
                        : Image.network(img, fit: BoxFit.cover),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _runButtons() => Padding(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 0),
        child: Row(
          children: [
            Expanded(
              flex: 13,
              child: SizedBox(
                height: 50,
                child: FilledButton(
                  onPressed: _loading ? null : () => _run(fourcut: false),
                  style: FilledButton.styleFrom(
                    backgroundColor: _loading ? T.muted : T.ink,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15)),
                  ),
                  child: Text(
                      _loading
                          ? '만드는 중…'
                          : _result != null
                              ? '다시 입혀보기'
                              : '입혀보기',
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                          color: Colors.white)),
                ),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              flex: 10,
              child: SizedBox(
                height: 50,
                child: OutlinedButton(
                  onPressed: _loading ? null : () => _run(fourcut: true),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: _loading ? T.line : T.ink, width: 1.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15)),
                  ),
                  child: Text('인생네컷',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                          color: _loading ? T.muted : T.ink)),
                ),
              ),
            ),
          ],
        ),
      );

  Widget _analysis() {
    final text = _result != null
        ? _result!.analysis
        : _loading
            ? 'AI가 체형을 분석하고 있어요…'
            : '$petName의 체형에는 ${_result?.recommendedSize ?? _size} 사이즈가 가장 잘 맞아요.';
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: T.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('AI 핏 분석',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: T.ink)),
            const SizedBox(height: 9),
            Text(text,
                style: const TextStyle(
                    fontSize: 13,
                    height: 1.65,
                    color: T.sub,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
