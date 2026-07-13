import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../api/client.dart';
import '../models/product.dart';
import '../models/tryon.dart';
import '../models/commerce.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/login_sheet.dart';

class FitScreen extends StatefulWidget {
  final int? initialProductId; // 상세에서 '이 옷으로 피팅' 진입 시 선택 상품
  const FitScreen({super.key, this.initialProductId});

  @override
  State<FitScreen> createState() => _FitScreenState();
}

class _FitScreenState extends State<FitScreen> {
  // 등록된 펫(활성 펫) 이름 — 미등록이면 기본 호칭
  String get _petName => appState.activePet?.name ?? '우리 아이';

  // 실제 생성 = replicate(winter LoRA 등). 사용자에겐 모델 선택을 노출하지 않는다.
  // (개발 중 A/B 가 필요하면 아래 _providers + 'AI 모델' 칩을 임시로 되살려 쓸 것.)
  final String _provider = 'replicate';
  String _style = 'winter';
  String _composition = 'front_full';
  String _size = 'M';

  List<Product> _fittable = [];
  int? _fitId; // 선택된 옷 상품 id

  Uint8List? _photo;
  final List<Uint8List?> _four = [null, null, null, null]; // 인생네컷 4장
  bool _loading = false;
  TryOnResult? _result;
  String _msg = '';
  Generations? _gen; // AI 생성 잔여 횟수

  // 일러스트 4종(plush/clay/cartoon/pixel)은 fal flux-kontext 검증 완료 라인업(2026-07).
  // 구세대 ghibli/riso/mood 칩은 내림 — 은은한 회화 계열은 화풍 LoRA 학습 후 승격 예정.
  static const _styles = [
    ['winter', '겨울 감성'],
    ['sakura', '벚꽃 감성'],
    ['plush', '플러시 토이'],
    ['clay', '클레이'],
    ['cartoon', '카툰'],
    ['pixel', '픽셀'],
  ];

  // 사진풍 타일 틴트 — 새 사진풍이 추가되면 여기 없어도 키 해시 기반 파스텔이 자동 배정된다.
  static const Map<String, List<Color>> _styleTints = {
    'winter': [Color(0xFFDDEAF6), Color(0xFF9FC0DD)],
    'sakura': [Color(0xFFFBE3EA), Color(0xFFF0B3C9)],
    'plush': [Color(0xFFF6E7D8), Color(0xFFDDBB99)],
    'clay': [Color(0xFFEDE0D4), Color(0xFFC4A78D)],
    'cartoon': [Color(0xFFFDEBD2), Color(0xFFF3BC5D)],
    'pixel': [Color(0xFFE4E0F5), Color(0xFFAA9EDF)],
  };

  List<Color> _tintFor(String key) {
    final hit = _styleTints[key];
    if (hit != null) return hit;
    final hue = (key.hashCode % 360).toDouble().abs();
    return [
      HSLColor.fromAHSL(1, hue, 0.45, 0.90).toColor(),
      HSLColor.fromAHSL(1, hue, 0.42, 0.72).toColor(),
    ];
  }
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
        final init = widget.initialProductId;
        final hasInit = init != null && _fittable.any((p) => p.id == init);
        _fitId = hasInit
            ? init
            : (_fittable.isNotEmpty ? _fittable.first.id : null);
      });
    }).catchError((_) {});
    _loadGen();
  }

  void _loadGen() {
    if (!appState.loggedIn) return;
    Api.fetchGenerations().then((g) {
      if (mounted) setState(() => _gen = g);
    }).catchError((_) {});
  }

  Product? get _selected {
    for (final p in _fittable) {
      if (p.id == _fitId) return p;
    }
    return _fittable.isNotEmpty ? _fittable.first : null;
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(m), duration: const Duration(milliseconds: 1800)));

  Future<void> _pickPhoto() async {
    try {
      final x = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (x == null) return; // 사용자가 취소
      final bytes = await x.readAsBytes();
      if (!mounted) return;
      setState(() {
        _photo = bytes;
        _result = null;
        _msg = '';
      });
    } catch (e) {
      if (mounted) _snack('사진을 불러오지 못했어요: $e');
    }
  }

  Future<void> _pickFour(int idx) async {
    try {
      final x = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (x == null) return;
      final bytes = await x.readAsBytes();
      if (!mounted) return;
      setState(() {
        _four[idx] = bytes;
        _result = null;
        _msg = '';
      });
    } catch (e) {
      if (mounted) _snack('사진을 불러오지 못했어요: $e');
    }
  }

  Future<void> _run({required bool fourcut}) async {
    final product = _selected;
    if (_loading || product == null) return;
    final fourPhotos = _four.whereType<Uint8List>().toList();
    if (_provider != 'mock') {
      if (fourcut && fourPhotos.length < 4) {
        final missing = 4 - fourPhotos.length;
        final m = fourPhotos.isEmpty
            ? '인생네컷 사진 4장을 올리지 않았어요. 아래 인생네컷 칸에 사진을 넣어주세요'
            : '인생네컷 사진이 $missing장 부족해요 (4장 필요)';
        setState(() => _msg = m);
        _snack(m);
        return;
      }
      if (!fourcut && _photo == null) {
        setState(() => _msg = '펫 사진을 추가하면 AI가 입혀드려요');
        return;
      }
    }
    setState(() {
      _loading = true;
      _result = null;
      _msg = '';
    });
    if (!appState.loggedIn) {
      setState(() => _loading = false);
      await showLoginSheet(context);
      if (!appState.loggedIn) return; // 로그인 안 하면 중단(카카오는 딥링크 복귀 후 재시도)
      setState(() => _loading = true);
    }
    try {
      final petId = appState.activePet?.id;

      final job = fourcut
          ? await Api.runFourcut(
              productId: product.id,
              size: _size,
              provider: _provider,
              petId: petId,
              style: _style,
              petImagesBytes: fourPhotos,
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
        _loadGen(); // 생성 후 잔여 횟수 갱신
      } else {
        final e = job.error ?? '생성에 실패했어요. 잠시 후 다시 시도해주세요.';
        setState(() => _msg = e);
        _snack(e);
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _msg = e.message);
        _snack(e.message); // 402(횟수)·401(로그인) 등 서버 메시지 노출
      }
    } catch (e) {
      if (mounted) {
        setState(() => _msg = '생성 중 오류가 났어요');
        _snack('생성 중 오류: $e');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = _selected;
    return Material(
      color: T.paper,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              height: 30,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Text('AI 피팅',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                          color: T.ink)),
                  if (_gen != null)
                    Positioned(
                      right: 22,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                            color: T.accentSoft,
                            borderRadius: BorderRadius.circular(999)),
                        child: Text(_gen!.label,
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: T.accent)),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  _styleSection(),
                  _compSection(),
                  _preview(),
                  _scoreCards(product),
                  _garmentPicker(),
                  _fourcutSlots(),
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

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 6, 22, 0),
        child: Text(title,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: T.ink)),
      );

  /// 사진풍 선택 — 가로 스크롤 타일. 사진풍이 계속 늘어나도 그대로 확장된다.
  Widget _styleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('사진풍'),
        SizedBox(
          height: 98,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(22, 10, 22, 0),
            itemCount: _styles.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) => _styleTile(_styles[i][0], _styles[i][1]),
          ),
        ),
      ],
    );
  }

  Widget _styleTile(String key, String label) {
    final on = _style == key;
    final tint = _tintFor(key);
    return GestureDetector(
      onTap: () => setState(() => _style = key),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 62,
            height: 62,
            padding: const EdgeInsets.all(2.5),
            decoration: BoxDecoration(
              color: T.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                  color: on ? T.accent : T.line, width: on ? 2 : 1),
              boxShadow: on
                  ? [
                      BoxShadow(
                          color: T.accent.withValues(alpha: 0.28),
                          blurRadius: 10,
                          offset: const Offset(0, 3)),
                    ]
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(13.5),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: tint,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight),
                ),
                child: on
                    ? Center(
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: const BoxDecoration(
                              color: Colors.white, shape: BoxShape.circle),
                          child: const Icon(Icons.check_rounded,
                              size: 15, color: T.accent),
                        ),
                      )
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: on ? FontWeight.w800 : FontWeight.w600,
                  color: on ? T.accent : T.sub)),
        ],
      ),
    );
  }

  /// 구도 선택 — 가로 스크롤 칩
  Widget _compSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        _sectionTitle('구도'),
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(22, 10, 22, 0),
            itemCount: _comps.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final k = _comps[i][0];
              final on = _composition == k;
              return GestureDetector(
                onTap: () => setState(() => _composition = k),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: on ? T.ink : T.surface,
                    borderRadius: BorderRadius.circular(999),
                    border:
                        Border.all(color: on ? Colors.transparent : T.line),
                  ),
                  child: Text(_comps[i][1],
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: on ? Colors.white : T.sub)),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _preview() {
    final hasPhoto = _photo != null;
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
          child: Stack(
            fit: StackFit.expand,
            children: [
              _previewContent(),
              // 사진을 올렸으면(결과 유무 무관) 언제든 다시 고를 수 있게 '사진 변경' 버튼.
              if (hasPhoto && !_loading)
                Positioned(top: 10, right: 10, child: _changePhotoBtn()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _changePhotoBtn() => GestureDetector(
        onTap: _pickPhoto,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(999),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.refresh, color: Colors.white, size: 14),
              SizedBox(width: 4),
              Text('사진 변경',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      );

  Widget _previewContent() {
    return _loading
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(
                          color: T.accent, strokeWidth: 3),
                      const SizedBox(height: 16),
                      Text('AI가 $_petName에게 입히는 중…',
                          style: const TextStyle(
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
                      : _addPhotoButton();
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
              Text('$_petName 사진 추가',
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
          height: 80,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 4),
            itemCount: _fittable.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final p = _fittable[i];
              final on = p.id == _fitId;
              final img = Api.imageUrl(p);
              // 보더(바깥)와 이미지 클립(안쪽)을 분리 — 이미지가 보더를 덮어
              // 주황 테두리가 깨져 보이던 문제 방지.
              return GestureDetector(
                onTap: () => setState(() {
                  _fitId = p.id;
                  _result = null;
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 64,
                  height: 64,
                  padding: const EdgeInsets.all(2.5),
                  decoration: BoxDecoration(
                    color: T.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: on ? T.accent : T.line, width: on ? 2 : 1),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(11.5),
                    child: Container(
                      color: T.soft,
                      child: img == null
                          ? const Icon(Icons.checkroom,
                              color: T.muted2, size: 22)
                          : Image.network(img, fit: BoxFit.cover),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _fourcutSlots() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(22, 24, 22, 0),
          child: Text('인생네컷 사진 (4장)',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: T.ink)),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(22, 3, 22, 0),
          child: Text('네 장을 올리면 각 사진에 감성 룩·옷을 입혀 4컷으로 만들어드려요',
              style: TextStyle(fontSize: 11.5, color: T.muted)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 0),
          child: Row(
            children: List.generate(4, (i) {
              final img = _four[i];
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i < 3 ? 8 : 0),
                  child: GestureDetector(
                    onTap: () => _pickFour(i),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Container(
                        decoration: BoxDecoration(
                          color: T.soft,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: img == null ? T.line : T.accent,
                              width: img == null ? 1 : 1.5),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: img == null
                            ? const Icon(Icons.add, color: T.muted2, size: 22)
                            : Image.memory(img, fit: BoxFit.cover),
                      ),
                    ),
                  ),
                ),
              );
            }),
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
            : '$_petName의 체형에는 ${_result?.recommendedSize ?? _size} 사이즈가 가장 잘 맞아요.';
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
