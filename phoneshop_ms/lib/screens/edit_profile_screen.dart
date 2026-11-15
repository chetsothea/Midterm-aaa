import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../widgets/address_picker.dart';
import '../widgets/common.dart';
import 'avatar_crop_screen.dart';
import '../services/language.dart';

// The customer changes their own details, password and picture.
// Returns true when something was saved.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _user = ApiService.currentUser!;
  late final _name = TextEditingController(text: _user.name);
  late final _email = TextEditingController(text: _user.email);
  late final _phone = TextEditingController(text: _user.phone);
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _hidePassword = true;
  // The saved address stays unless the customer picks a new one
  late bool _keepAddress = _user.address.isNotEmpty;
  String? _address;
  XFile? _avatar;
  Uint8List? _avatarPreview;
  bool _isSaving = false;

  @override
  void dispose() {
    for (final c in [_name, _email, _phone, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  void _pickAvatar() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      imageQuality: 85,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    final cropped = await Navigator.push<Uint8List>(
      context,
      MaterialPageRoute(builder: (_) => AvatarCropScreen(bytes: bytes)),
    );
    if (cropped == null) return;
    setState(() {
      _avatar = XFile.fromData(
        cropped,
        name: 'avatar.png',
        mimeType: 'image/png',
      );
      _avatarPreview = cropped;
    });
  }

  void _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSaving = true;
    });
    try {
      await ApiService.updateProfile(
        name: _name.text.trim(),
        email: _email.text.trim(),
        phone: _phone.text.trim(),
        password: _password.text,
        // With the picker on screen, validate() above made sure every level is picked
        address: _keepAddress ? _user.address : _address!,
        avatar: _avatar,
      );
      if (!mounted) return;
      showMessage(
        context,
        _password.text.isEmpty
            ? tr('បានកែព័ត៌មានរួចហើយ')
            : tr('បានកែព័ត៌មាន និងប្តូរពាក្យសម្ងាត់រួចហើយ'),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  static const _navy = Color(0xFF0F2A5F);

  OutlineInputBorder _border(Color color, [double width = 1.2]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color, width: width),
      );

  // Soft filled fields with light borders, like the rest of the app's forms
  InputDecoration _decor(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, color: const Color(0xFF475569)),
    filled: true,
    fillColor: const Color(0xFFF8FAFC),
    border: _border(const Color(0xFFE2E8F0)),
    enabledBorder: _border(const Color(0xFFE2E8F0)),
    focusedBorder: _border(const Color(0xFF0E7490), 1.8),
    errorBorder: _border(Colors.red),
    focusedErrorBorder: _border(Colors.red, 1.8),
  );

  // A white card with an icon heading, like the other pages
  Widget _section(
    IconData icon,
    String title,
    List<Widget> children, {
    String? hint,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
                  0xFF0E7490,
                ).withValues(alpha: 0.12),
                child: Icon(icon, size: 17, color: const Color(0xFF0E7490)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: _navy,
                  ),
                ),
              ),
            ],
          ),
          if (hint != null) ...[
            const SizedBox(height: 6),
            Text(
              hint,
              style: const TextStyle(color: Colors.black54, fontSize: 13),
            ),
          ],
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  // The picture on the shop's colours, with a camera button to change it
  Widget _photo() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_navy, Color(0xFF0E7490)],
        ),
      ),
      child: Column(
        children: [
          InkWell(
            customBorder: const CircleBorder(),
            onTap: _pickAvatar,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: _avatarPreview != null
                      ? CircleAvatar(
                          radius: 48,
                          backgroundImage: MemoryImage(_avatarPreview!),
                        )
                      : UserAvatar(user: _user, radius: 48),
                ),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF97316),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: _pickAvatar,
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            icon: const Icon(Icons.photo_library_outlined, size: 18),
            label: Text(tr('ជ្រើសរូបភាព')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(title: Text(tr('កែព័ត៌មាន'))),
      body: Form(
        key: _formKey,
        // Not a ListView: every field must stay built so validate() checks all of them
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _photo(),
              _section(
                Icons.badge_outlined,
                trf('ព័ត៌មានផ្ទាល់ខ្លួន', 'Your details'),
                [
                  TextFormField(
                    controller: _name,
                    decoration: _decor(tr('ឈ្មោះ *'), Icons.person_outline),
                    validator: (v) =>
                        v!.trim().isEmpty ? tr('សូមបញ្ចូលឈ្មោះ') : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: _decor('Email *', Icons.mail_outline),
                    validator: (v) =>
                        RegExp(
                          r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                        ).hasMatch(v!.trim())
                        ? null
                        : tr('Email មិនត្រឹមត្រូវ'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: _decor(
                      tr('លេខទូរស័ព្ទ *'),
                      Icons.phone_outlined,
                    ),
                    validator: (v) =>
                        v!.replaceAll(RegExp(r'[^0-9]'), '').length < 8
                        ? tr('លេខទូរស័ព្ទមិនត្រឹមត្រូវ')
                        : null,
                  ),
                ],
              ),
              _section(Icons.location_on_outlined, tr('អាសយដ្ឋាន'), [
                if (_keepAddress)
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 12, 4, 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.location_on,
                              color: Colors.redAccent,
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(_user.address)),
                          ],
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () => setState(() {
                              _keepAddress = false;
                            }),
                            icon: const Icon(
                              Icons.edit_location_alt_outlined,
                              size: 18,
                            ),
                            label: Text(tr('ប្តូរទីតាំង')),
                          ),
                        ),
                      ],
                    ),
                  )
                else ...[
                  AddressPicker(onChanged: (address) => _address = address),
                  if (_user.address.isNotEmpty)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => setState(() {
                          _keepAddress = true;
                        }),
                        child: Text(tr('ប្រើទីតាំងដែលបានរក្សាទុក')),
                      ),
                    ),
                ],
              ]),
              _section(
                Icons.lock_outline,
                tr('ប្តូរពាក្យសម្ងាត់'),
                hint: tr(
                  'បើភ្លេចពាក្យសម្ងាត់ចាស់ អាចវាយថ្មីនៅទីនេះបាន។ ទុកទទេ បើមិនចង់ប្តូរ។',
                ),
                [
                  TextFormField(
                    controller: _password,
                    obscureText: _hidePassword,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration:
                        _decor(
                          tr('ពាក្យសម្ងាត់ថ្មី'),
                          Icons.lock_outline,
                        ).copyWith(
                          suffixIcon: IconButton(
                            tooltip: _hidePassword
                                ? 'Show password'
                                : 'Hide password',
                            icon: Icon(
                              _hidePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed: () => setState(() {
                              _hidePassword = !_hidePassword;
                            }),
                          ),
                        ),
                    validator: (v) => v!.isNotEmpty && v.length < 6
                        ? tr('យ៉ាងតិច 6 តួ')
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _confirm,
                    obscureText: _hidePassword,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: _decor(
                      tr('បញ្ជាក់ពាក្យសម្ងាត់ថ្មី'),
                      Icons.lock_outline,
                    ),
                    validator: (v) => v != _password.text
                        ? tr('ពាក្យសម្ងាត់មិនដូចគ្នា')
                        : null,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      // Same bottom bar as Checkout: white, rounded, with the orange main button
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
            padding: const EdgeInsets.all(12),
            child: FilledButton.icon(
              onPressed: _isSaving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFF97316),
                minimumSize: const Size.fromHeight(50),
              ),
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check),
              label: Text(tr('រក្សាទុក')),
            ),
          ),
        ),
      ),
    );
  }
}
