import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../data/models/phone.dart';
import '../../data/api_service.dart';
import '../../components/common.dart';
import '../../components/product_card.dart';
import '../../components/ux.dart';
import '../../hooks/language.dart';
import '../../theme/app_theme.dart';

// Add a new phone, or edit one when [phone] is given
class ProductFormScreen extends StatefulWidget {
  final Phone? phone;

  const ProductFormScreen({super.key, this.phone});

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.phone?.name);
  late final _brand = TextEditingController(text: widget.phone?.brand);
  late final _price = TextEditingController(
    text: (widget.phone?.oldPrice ?? widget.phone?.price)
        ?.toString(), // the regular price
  );
  late final _discount = TextEditingController(
    text: (widget.phone?.hasDiscount ?? false)
        ? discountLabel(widget.phone!.discountPercent).substring(1)
        : '',
  );
  late final _condition = TextEditingController(
    text: widget.phone?.condition ?? 'New',
  );
  late final _stock = TextEditingController(
    text: widget.phone?.stock.toString(),
  );
  late final _ram = TextEditingController(text: widget.phone?.ram);
  late final _storage = TextEditingController(text: widget.phone?.storage);
  // "256GB=1199, 512GB=1399"
  late final _storagePrices = TextEditingController(
    text: widget.phone?.storageOptions.join(', '),
  );
  late final _color = TextEditingController(text: widget.phone?.color);
  late final _description = TextEditingController(
    text: widget.phone?.description,
  );

  List<Map<String, dynamic>> _categories = [];
  int? _categoryId;
  XFile? _image;
  Uint8List? _imagePreview;
  // New pictures picked for each colour, waiting to be uploaded on save
  final Map<String, XFile> _colorImages = {};
  final Map<String, Uint8List> _colorPreviews = {};
  bool _isSaving = false;

  bool get _isEdit => widget.phone != null;

  List<String> get _colorList => _color.text
      .split(',')
      .map((c) => c.trim())
      .where((c) => c.isNotEmpty)
      .toList();

  @override
  void initState() {
    super.initState();
    _categoryId = widget.phone?.categoryId;
    // Rebuild the per-colour picture list while the admin types colours
    _color.addListener(() => setState(() {}));
    ApiService.fetchCategories().then((list) {
      if (mounted) setState(() => _categories = list);
    });
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _brand,
      _price,
      _discount,
      _condition,
      _stock,
      _ram,
      _storage,
      _storagePrices,
      _color,
      _description,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _pickImage() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 700,
      imageQuality: 85,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _image = file;
      _imagePreview = bytes;
    });
  }

  void _pickColorImage(String color) async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 700,
      imageQuality: 85,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _colorImages[color] = file;
      _colorPreviews[color] = bytes;
    });
  }

  // One row per colour: its dot, name and picture (tap to pick a new one)
  Widget _colorImagePicker(String color) {
    final preview = _colorPreviews[color];
    final current = widget.phone?.colorImageUrls[color] ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: () => _pickColorImage(color),
        leading: ColorDot(color: color, size: 22),
        title: Text(color),
        subtitle: Text(
          preview != null
              ? 'រូបថ្មី (រក្សាទុកដើម្បី upload)'
              : current.isNotEmpty
              ? 'ចុចដើម្បីប្តូររូប'
              : 'មិនទាន់មានរូប — ប្រើរូបមេ',
        ),
        trailing: SizedBox(
          width: 56,
          height: 56,
          child: preview != null
              ? Image.memory(preview, fit: BoxFit.contain)
              : current.isNotEmpty
              ? PhoneImage(url: current, size: 56)
              : const Icon(Icons.add_a_photo_outlined),
        ),
      ),
    );
  }

  void _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      await ApiService.saveProduct(
        {
          'name': _name.text.trim(),
          'brand': _brand.text.trim(),
          'price': _price.text.trim(),
          // Sent even when empty, so clearing it removes the discount
          'discount_percent': _discount.text.trim(),
          'condition': _condition.text.trim(),
          'stock': _stock.text.trim(),
          'ram': _ram.text.trim(),
          'storage': _storage.text.trim(),
          // Sent even when empty, so clearing it goes back to a single size
          'storage_prices': _storagePrices.text.trim(),
          'color': _color.text.trim(),
          'description': _description.text.trim(),
          if (_categoryId != null) 'category_id': '$_categoryId',
        },
        id: widget.phone?.id,
        image: _image,
        // Only colours still in the list (the admin may have renamed or removed some)
        colorImages: {
          for (final color in _colorList)
            if (_colorImages[color] != null) color: _colorImages[color]!,
        },
      );
      if (!mounted) return;
      showMessage(context, _isEdit ? 'បានកែប្រែ' : 'បានបន្ថែម');
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  static Color get _navy => AppColors.text;

  OutlineInputBorder _border(Color color, [double width = 1.2]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: color, width: width),
      );

  // Soft filled fields with light borders, like the rest of the app's forms
  InputDecoration _decor(String label) => InputDecoration(
    labelText: label,
    filled: true,
    fillColor: AppColors.surface,
    border: _border(AppColors.line),
    enabledBorder: _border(AppColors.line),
    focusedBorder: _border(const Color(0xFF3D7BFF), 1.8),
    errorBorder: _border(Colors.red),
    focusedErrorBorder: _border(Colors.red, 1.8),
  );

  // A white card with an icon heading, grouping related fields
  Widget _section(IconData icon, String title, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 2),
      decoration: BoxDecoration(
        color: AppColors.glass,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 15,
                backgroundColor: const Color(
                  0xFF3D7BFF,
                ).withValues(alpha: 0.12),
                child: Icon(icon, size: 17, color: const Color(0xFF3D7BFF)),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: _navy,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController c,
    String label, {
    bool required = false,
    bool number = false,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        maxLines: maxLines,
        keyboardType: number
            ? const TextInputType.numberWithOptions(decimal: true)
            : null,
        decoration: _decor(label),
        validator: (v) {
          if (required && v!.trim().isEmpty) return 'ត្រូវបំពេញ';
          if (number &&
              v!.trim().isNotEmpty &&
              num.tryParse(v.trim()) == null) {
            return 'ត្រូវជាលេខ';
          }
          return null;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.page,
      appBar: AppBar(
        title: Text(_isEdit ? 'កែប្រែទូរស័ព្ទ' : 'បន្ថែមទូរស័ព្ទ'),
      ),
      body: Form(
        key: _formKey,
        // Not a ListView: every field must stay built so validate() checks all of them
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // The main picture on the store's soft colours, with a camera button
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.surfaceHigh, AppColors.tileLow],
                  ),
                ),
                child: Center(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    onTap: _pickImage,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        SizedBox(
                          width: 170,
                          height: 170,
                          child: _imagePreview != null
                              ? Image.memory(
                                  _imagePreview!,
                                  fit: BoxFit.contain,
                                )
                              : (widget.phone?.imageUrl.isNotEmpty ?? false)
                              ? PhoneImage(
                                  url: widget.phone!.imageUrl,
                                  size: 170,
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.add_a_photo_outlined,
                                      size: 44,
                                      color: _navy,
                                    ),
                                    SizedBox(height: 6),
                                    Text('ជ្រើសរូបភាព'),
                                  ],
                                ),
                        ),
                        Positioned(
                          right: -4,
                          bottom: -4,
                          child: Container(
                            padding: const EdgeInsets.all(AppSpacing.xs),
                            decoration: BoxDecoration(
                              color: const Color(0xFF3D7BFF),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              size: 18,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              _section(Icons.info_outline, 'ព័ត៌មានទូទៅ', [
                _field(_name, 'ឈ្មោះ *', required: true),
                _field(_brand, 'ម៉ាក (Apple, Samsung...)'),
                if (_categories.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: DropdownButtonFormField<int>(
                      initialValue: _categoryId,
                      decoration: _decor('ប្រភេទ'),
                      items: [
                        for (final c in _categories)
                          DropdownMenuItem(
                            value: c['id'] as int,
                            child: Text(c['name']),
                          ),
                      ],
                      onChanged: (v) => _categoryId = v,
                    ),
                  ),
              ]),
              _section(Icons.sell_outlined, 'តម្លៃ និងស្តុក', [
                Row(
                  children: [
                    Expanded(
                      child: _field(
                        _price,
                        'តម្លៃ (\$) *',
                        required: true,
                        number: true,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _field(
                        _stock,
                        'ស្តុក *',
                        required: true,
                        number: true,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    // Takes this % off every storage size; the store shows a "%xx" badge
                    Expanded(
                      child: _field(_discount, 'Discount (%)', number: true),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    // "New" or e.g. "98%" for 2nd Hand
                    Expanded(child: _field(_condition, 'ស្ថានភាព (New / 98%)')),
                  ],
                ),
              ]),
              _section(Icons.memory, 'Spec', [
                Row(
                  children: [
                    Expanded(child: _field(_ram, 'RAM')),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: _field(_storage, 'Storage')),
                  ],
                ),
                // When filled, customers pick a size; the price above becomes the cheapest size
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextFormField(
                    controller: _storagePrices,
                    decoration: _decor('Storage ជាមួយតម្លៃ (ជម្រើស)').copyWith(
                      hintText: '256GB=1199, 512GB=1399, 1TB=1599',
                      helperText:
                          'បំពេញ ដើម្បីឱ្យអតិថិជនជ្រើស Storage — តម្លៃខាងលើនឹងស្មើទំហំថោកបំផុត',
                      helperMaxLines: 2,
                    ),
                    validator: (v) {
                      final format = RegExp(
                        r'^[^=:]{1,20}\s*[=:]\s*\$?\d+(\.\d{1,2})?$',
                      );
                      for (final part
                          in v!
                              .split(',')
                              .map((p) => p.trim())
                              .where((p) => p.isNotEmpty)) {
                        if (!format.hasMatch(part)) {
                          return 'ទម្រង់មិនត្រឹមត្រូវ: "$part" (ឧ. 512GB=1399)';
                        }
                      }
                      return null;
                    },
                  ),
                ),
              ]),
              _section(Icons.palette_outlined, 'ពណ៌ និងរូបតាមពណ៌', [
                // Customers pick one of these on the product screen
                _field(
                  _color,
                  'ពណ៌ (បំបែកដោយ , ឧ. Black, Blue, Natural Titanium)',
                ),
                for (final color in _colorList) _colorImagePicker(color),
                if (_colorList.isNotEmpty)
                  const SizedBox(height: AppSpacing.xxs),
              ]),
              _section(Icons.notes, 'ការពិពណ៌នា', [
                _field(_description, 'ការពិពណ៌នា', maxLines: 3),
              ]),
            ],
          ),
        ),
      ),
      // Same bottom bar as Checkout: white, rounded, with the orange main button
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.glass,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0x1A000000),
              blurRadius: 12,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: _isSaving
                ? BusyBar(label: trf('កំពុងរក្សាទុក...', 'Saving...'))
                : FilledButton.icon(
                    onPressed: _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF3D7BFF),
                      minimumSize: const Size.fromHeight(50),
                    ),
                    icon: const Icon(Icons.check),
                    label: const Text('រក្សាទុក'),
                  ),
          ),
        ),
      ),
    );
  }
}
