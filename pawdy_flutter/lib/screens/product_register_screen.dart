import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../api/client.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';

class ProductRegisterScreen extends StatefulWidget {
  const ProductRegisterScreen({super.key});

  @override
  State<ProductRegisterScreen> createState() => _ProductRegisterScreenState();
}

class _ProductRegisterScreenState extends State<ProductRegisterScreen> {
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _urlController = TextEditingController();
  final _stockController = TextEditingController(text: '99');
  
  String _category = 'fashion';
  String _species = 'dog';
  bool _fittable = true;
  
  final List<String> _selectedSizes = [];
  final List<String> _availableSizes = ['XS', 'S', 'M', 'L', 'XL'];

  Uint8List? _imageBytes;
  String? _imageFilename;
  
  Uint8List? _refImageBytes;
  String? _refImageFilename;

  bool _loading = false;

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(m), duration: const Duration(milliseconds: 1800)),
    );
  }

  Future<void> _pickImage(bool isRef) async {
    try {
      final x = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (x == null) return;
      final bytes = await x.readAsBytes();
      setState(() {
        if (isRef) {
          _refImageBytes = bytes;
          _refImageFilename = x.name;
        } else {
          _imageBytes = bytes;
          _imageFilename = x.name;
        }
      });
    } catch (e) {
      _toast('이미지를 불러오지 못했습니다: $e');
    }
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final priceStr = _priceController.text.trim();
    final url = _urlController.text.trim();
    final stockStr = _stockController.text.trim();

    if (name.isEmpty) return _toast('상품명을 입력해 주세요');
    if (priceStr.isEmpty) return _toast('가격을 입력해 주세요');
    final price = int.tryParse(priceStr);
    if (price == null || price <= 0) return _toast('올바른 가격을 입력해 주세요');
    
    if (stockStr.isEmpty) return _toast('재고량을 입력해 주세요');
    final stock = int.tryParse(stockStr);
    if (stock == null || stock < 0) return _toast('올바른 재고량을 입력해 주세요');

    if (_imageBytes == null || _imageFilename == null) return _toast('대표 상품 이미지를 업로드해 주세요');
    if (_fittable && _refImageBytes == null) return _toast('AI 피팅용 의상 이미지를 업로드해 주세요');

    setState(() => _loading = true);

    try {
      final brand = appState.shop?.name ?? '브랜드';
      await Api.createProduct(
        brand: brand,
        name: name,
        price: price,
        category: _category,
        species: _species,
        fittable: _fittable,
        url: url.isEmpty ? null : url,
        sizes: _category == 'fashion' && _selectedSizes.isNotEmpty ? _selectedSizes : null,
        stock: stock,
        imageBytes: _imageBytes!,
        imageFilename: _imageFilename!,
        refImageBytes: _fittable ? _refImageBytes : null,
        refImageFilename: _fittable ? _refImageFilename : null,
      );
      
      await appState.load(); // 상품 카탈로그 갱신
      _toast('상품 등록이 완료되었습니다');
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      _toast('$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }


  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700, color: T.sub)),
      );

  @override
  Widget build(BuildContext context) {
    final brand = appState.shop?.name ?? '내 브랜드';
    return Scaffold(
      backgroundColor: T.paper,
      appBar: AppBar(
        title: Text('$brand 상품 등록',
            style: const TextStyle(
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
              _label('상품명 *'),
              TextField(
                controller: _nameController,
                decoration: _inputDecoration('상품명 입력'),
                style: const TextStyle(fontSize: 14.5, color: T.ink),
              ),
              const SizedBox(height: 20),
              
              _label('판매가 (KRW) *'),
              TextField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                decoration: _inputDecoration('예: 89000'),
                style: const TextStyle(fontSize: 14.5, color: T.ink),
              ),
              const SizedBox(height: 20),

              _label('초기 재고량 *'),
              TextField(
                controller: _stockController,
                keyboardType: TextInputType.number,
                decoration: _inputDecoration('예: 99'),
                style: const TextStyle(fontSize: 14.5, color: T.ink),
              ),
              const SizedBox(height: 20),


              _label('카테고리 *'),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: T.line),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _category,
                    isExpanded: true,
                    icon: const Icon(Icons.keyboard_arrow_down, color: T.sub),
                    items: const [
                      DropdownMenuItem(value: 'fashion', child: Text('패션·스타일')),
                      DropdownMenuItem(value: 'care', child: Text('데일리케어')),
                      DropdownMenuItem(value: 'active', child: Text('액티브·아웃도어')),
                      DropdownMenuItem(value: 'wellness', child: Text('헬스·웰니스')),
                      DropdownMenuItem(value: 'home', child: Text('홈·인테리어')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _category = val;
                          if (_category != 'fashion') {
                            _fittable = false;
                          } else {
                            _fittable = true;
                          }
                        });
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),

              _label('대상 동물 *'),
              Row(
                children: [
                  _radioOption('강아지', 'dog'),
                  const SizedBox(width: 10),
                  _radioOption('고양이', 'cat'),
                  const SizedBox(width: 10),
                  _radioOption('공용', 'all'),
                ],
              ),
              const SizedBox(height: 20),

              if (_category == 'fashion') ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('AI 가상 피팅 지원',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: T.sub)),
                    Switch(
                      value: _fittable,
                      activeColor: T.accent,
                      onChanged: (val) => setState(() => _fittable = val),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (_fittable) ...[
                  _label('지원 사이즈 선택 (의류)'),
                  Wrap(
                    spacing: 8,
                    children: _availableSizes.map((sz) {
                      final isSel = _selectedSizes.contains(sz);
                      return ChoiceChip(
                        label: Text(sz,
                            style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: isSel ? Colors.white : T.sub)),
                        selected: isSel,
                        selectedColor: T.accent,
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(color: isSel ? T.accent : T.line)),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedSizes.add(sz);
                            } else {
                              _selectedSizes.remove(sz);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                ],
              ],

              _label('대표 상품 이미지 *'),
              _imagePickerBox(false),
              const SizedBox(height: 20),

              if (_fittable) ...[
                _label('AI 피팅용 의상 이미지 (누끼/단색 배경) *'),
                _imagePickerBox(true),
                const SizedBox(height: 20),
              ],

              _label('상세 판매 페이지 URL (선택)'),
              TextField(
                controller: _urlController,
                decoration: _inputDecoration('https://...'),
                style: const TextStyle(fontSize: 14.5, color: T.ink),
              ),
              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                height: 52,
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
                      : const Text('상품 등록 완료',
                          style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _radioOption(String label, String value) {
    final active = _species == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _species = value),
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? T.accentSoft : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: active ? T.accent : T.line),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: active ? T.accent : T.sub)),
        ),
      ),
    );
  }

  Widget _imagePickerBox(bool isRef) {
    final bytes = isRef ? _refImageBytes : _imageBytes;
    final filename = isRef ? _refImageFilename : _imageFilename;
    return GestureDetector(
      onTap: () => _pickImage(isRef),
      child: Container(
        width: double.infinity,
        height: 160,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: T.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: bytes != null
            ? Stack(
                children: [
                  Positioned.fill(child: Image.memory(bytes, fit: BoxFit.contain)),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                      color: Colors.black54,
                      child: Text(filename ?? 'image',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, color: Colors.white)),
                    ),
                  ),
                ],
              )
            : const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.photo_library_outlined, color: T.accent, size: 28),
                  SizedBox(height: 10),
                  Text('갤러리에서 이미지 선택하기',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: T.sub)),
                ],
              ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) => InputDecoration(
        hintText: hint,
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
      );

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _urlController.dispose();
    super.dispose();
  }
}
