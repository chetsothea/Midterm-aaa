import 'package:flutter/material.dart';
import '../../data/models/customer.dart';
import '../../data/api_service.dart';
import '../../components/common.dart';
import '../../components/ux.dart';
import '../../theme/app_theme.dart';

// The admin corrects a customer's details, or gives them a new password.
// Returns true when something was saved.
class CustomerFormScreen extends StatefulWidget {
  final Customer customer;

  const CustomerFormScreen({super.key, required this.customer});

  @override
  State<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends State<CustomerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.customer.name);
  late final _email = TextEditingController(text: widget.customer.email);
  late final _phone = TextEditingController(text: widget.customer.phone);
  late final _address = TextEditingController(text: widget.customer.address);
  final _password = TextEditingController();
  bool _hidePassword = true;
  bool _isSaving = false;

  @override
  void dispose() {
    for (final c in [_name, _email, _phone, _address, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSaving = true;
    });
    final newPassword = _password.text;
    try {
      await ApiService.updateCustomer(
        widget.customer.id,
        name: _name.text.trim(),
        email: _email.text.trim(),
        phone: _phone.text.trim(),
        address: _address.text.trim(),
        password: newPassword,
      );
      if (!mounted) return;
      showMessage(
        context,
        newPassword.isEmpty
            ? 'បានកែព័ត៌មានរួចហើយ'
            : 'បានប្តូរពាក្យសម្ងាត់រួចហើយ សូមប្រាប់ពាក្យសម្ងាត់ថ្មីទៅអតិថិជន',
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

  static Color get _navy => AppColors.text;

  OutlineInputBorder _border(Color color, [double width = 1.2]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: color, width: width),
      );

  // Soft filled fields with light borders, like the rest of the app's forms
  InputDecoration _decor(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, color: AppColors.textSoft),
    filled: true,
    fillColor: AppColors.surface,
    border: _border(AppColors.line),
    enabledBorder: _border(AppColors.line),
    focusedBorder: _border(const Color(0xFF3D7BFF), 1.8),
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
          if (hint != null) ...[
            const SizedBox(height: 6),
            Text(hint, style: TextStyle(color: AppColors.muted, fontSize: 13)),
          ],
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  // Who is being edited: their initial, email, when they joined and their orders
  Widget _header() {
    final customer = widget.customer;
    String two(int n) => n.toString().padLeft(2, '0');
    final joined = customer.joined;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_navy, Color(0xFF3D7BFF)],
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: AppColors.surface,
            child: Text(
              customer.name.isEmpty ? '?' : customer.name[0].toUpperCase(),
              style: TextStyle(
                color: _navy,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customer.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _headerPill(
                      Icons.event_outlined,
                      'ចុះឈ្មោះ ${two(joined.day)}/${two(joined.month)}/${joined.year}',
                    ),
                    _headerPill(
                      Icons.receipt_long_outlined,
                      '${customer.orders} Order',
                    ),
                    if (customer.blocked)
                      _headerPill(Icons.block, 'គណនីបានបិទ'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerPill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: const Color(0xFFFBBF24)),
          const SizedBox(width: AppSpacing.xxs),
          // Ends in "…" rather than overflowing on a narrow phone
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.page,
      appBar: AppBar(title: const Text('កែព័ត៌មានអតិថិជន')),
      body: Form(
        key: _formKey,
        // Not a ListView: every field must stay built so validate() checks all of them
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(),
              _section(Icons.badge_outlined, 'ព័ត៌មានអតិថិជន', [
                TextFormField(
                  controller: _name,
                  decoration: _decor('ឈ្មោះ *', Icons.person_outline),
                  validator: (v) => v!.trim().isEmpty ? 'សូមបញ្ចូលឈ្មោះ' : null,
                ),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: _decor('Email *', Icons.mail_outline),
                  validator: (v) =>
                      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v!.trim())
                      ? null
                      : 'Email មិនត្រឹមត្រូវ',
                ),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: _decor('លេខទូរស័ព្ទ', Icons.phone_outlined),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: _address,
                  maxLines: 2,
                  decoration: _decor('អាសយដ្ឋាន', Icons.location_on_outlined),
                ),
              ]),
              _section(
                Icons.lock_outline,
                'ពាក្យសម្ងាត់',
                hint:
                    'មិនអាចមើលពាក្យសម្ងាត់ចាស់បានទេ។ បើអតិថិជនភ្លេច សូមវាយពាក្យសម្ងាត់ថ្មី ហើយប្រាប់ទៅគាត់។ ទុកទទេ បើមិនចង់ប្តូរ។',
                [
                  TextFormField(
                    controller: _password,
                    obscureText: _hidePassword,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: _decor('ពាក្យសម្ងាត់ថ្មី', Icons.lock_outline)
                        .copyWith(
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
                    validator: (v) =>
                        v!.isNotEmpty && v.length < 6 ? 'យ៉ាងតិច 6 តួ' : null,
                  ),
                ],
              ),
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
            child: FilledButton.icon(
              onPressed: _isSaving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF3D7BFF),
                minimumSize: const Size.fromHeight(50),
              ),
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: DotsLoader(color: Colors.white, size: 5),
                    )
                  : const Icon(Icons.check),
              label: const Text('រក្សាទុក'),
            ),
          ),
        ),
      ),
    );
  }
}
