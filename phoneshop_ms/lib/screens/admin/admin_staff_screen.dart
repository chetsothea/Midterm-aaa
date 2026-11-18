import 'package:flutter/material.dart';
import '../../components/common.dart';
import '../../components/confirm_dialog.dart';
import '../../components/store_app_bar.dart';
import '../../components/ux.dart';
import '../../data/api_service.dart';
import '../../hooks/language.dart';
import '../../theme/app_theme.dart';

// Admin: staff accounts. Staff log in like the admin but only see the orders:
// confirm, ship, enter IMEIs, check warranties. No money, prices or settings.
class AdminStaffScreen extends StatefulWidget {
  const AdminStaffScreen({super.key});

  @override
  State<AdminStaffScreen> createState() => _AdminStaffScreenState();
}

class _AdminStaffScreenState extends State<AdminStaffScreen> {
  List<Map<String, dynamic>> _staff = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _staff = await ApiService.fetchStaff();
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _edit([Map<String, dynamic>? staff]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surfaceHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => _StaffForm(staff: staff),
    );
    if (saved == true) _load();
  }

  Future<void> _delete(Map<String, dynamic> s) async {
    final yes = await showConfirmDialog(
      context,
      icon: Icons.person_remove_outlined,
      color: AppColors.red,
      title: trf('លុបគណនីបុគ្គលិក?', 'Remove this staff account?'),
      code: '${s['name']}',
      message: trf(
        'គាត់នឹង Login មិនបានទៀតទេ',
        'They will no longer be able to log in',
      ),
      cancelLabel: trf('ទេ', 'No'),
      confirmLabel: trf('លុប', 'Remove'),
    );
    if (!yes) return;
    try {
      await ApiService.deleteStaff(s['id'] as int);
      if (!mounted) return;
      showMessage(context, trf('បានលុប', 'Removed'));
      _load();
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.page,
      appBar: storeAppBar(title: Text(trf('បុគ្គលិក', 'Staff'))),
      floatingActionButton: _loading || _error != null
          ? null
          : FloatingActionButton.extended(
              onPressed: _edit,
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.person_add_alt_1),
              label: Text(trf('បន្ថែមបុគ្គលិក', 'Add staff')),
            ),
      body: _loading
          ? const ListSkeleton(rows: 2)
          : _error != null
          ? StatusView(
              icon: Icons.wifi_off_rounded,
              error: true,
              title: trf('មិនអាចភ្ជាប់ទៅហាងបានទេ', "Can't reach the shop"),
              message: _error!,
              actionLabel: trf('ព្យាយាមម្តងទៀត', 'Try again'),
              onAction: _load,
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Text(
                    trf(
                      'បុគ្គលិកអាច: មើល និងរៀបចំ Order, ដឹកជញ្ជូន, បញ្ចូល IMEI, ពិនិត្យការធានា, Live។\n'
                          'មិនអាច: មើលចំណូល, កែតម្លៃ/ទូរស័ព្ទ, កូដបញ្ចុះ, ធនាគារ, អតិថិជន, លុប Order។',
                      'Staff can: see and handle orders, delivery, IMEIs, warranty checks, Live.\n'
                          "Can't: see revenue, change phones or prices, codes, banks, customers, delete orders.",
                    ),
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                if (_staff.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.lg,
                    ),
                    child: Text(
                      trf('មិនទាន់មានបុគ្គលិក', 'No staff yet'),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.muted),
                    ),
                  ),
                for (final s in _staff)
                  Container(
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    decoration: glassDecoration(
                      radius: AppRadius.lg,
                      shadow: false,
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.accent.withValues(
                          alpha: 0.15,
                        ),
                        child: Text(
                          '${s['name']}'.isEmpty
                              ? '?'
                              : '${s['name']}'.characters.first.toUpperCase(),
                          style: const TextStyle(
                            color: AppColors.accent,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      title: Text(
                        '${s['name']}',
                        style: TextStyle(
                          color: AppColors.text,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        [
                          s['email'],
                          s['phone'],
                        ].where((v) => '${v ?? ''}'.isNotEmpty).join(' · '),
                        style: TextStyle(color: AppColors.muted),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: trf(
                              'កែ / ប្តូរពាក្យសម្ងាត់',
                              'Edit / new password',
                            ),
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => _edit(s),
                          ),
                          IconButton(
                            tooltip: trf('លុប', 'Remove'),
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              color: AppColors.red,
                            ),
                            onPressed: () => _delete(s),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _StaffForm extends StatefulWidget {
  final Map<String, dynamic>? staff;

  const _StaffForm({this.staff});

  @override
  State<_StaffForm> createState() => _StaffFormState();
}

class _StaffFormState extends State<_StaffForm> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.staff?['name']);
  late final _email = TextEditingController(text: widget.staff?['email']);
  late final _phone = TextEditingController(text: widget.staff?['phone']);
  final _password = TextEditingController();
  bool _hide = true;
  bool _saving = false;

  bool get _isNew => widget.staff == null;

  @override
  void dispose() {
    for (final c in [_name, _email, _phone, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  InputDecoration _input(
    String label,
    IconData icon, {
    String? helper,
    Widget? suffix,
  }) => InputDecoration(
    labelText: label,
    helperText: helper,
    prefixIcon: Icon(icon),
    suffixIcon: suffix,
    filled: true,
    fillColor: AppColors.surface,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
    ),
  );

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ApiService.saveStaff({
        'name': _name.text.trim(),
        if (_isNew) 'email': _email.text.trim(),
        'phone': _phone.text.trim(),
        if (_password.text.isNotEmpty) 'password': _password.text,
      }, id: widget.staff?['id'] as int?);
      if (!mounted) return;
      showMessage(context, trf('បានរក្សាទុក', 'Saved'));
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _isNew
                    ? trf('បន្ថែមបុគ្គលិក', 'Add staff')
                    : trf('កែបុគ្គលិក', 'Edit staff'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: _input(
                  trf('ឈ្មោះ *', 'Name *'),
                  Icons.person_outline,
                ),
                validator: (v) => v!.trim().isEmpty
                    ? trf('សូមបញ្ចូលឈ្មោះ', 'Enter a name')
                    : null,
              ),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: _email,
                enabled: _isNew, // the login e-mail stays the same
                keyboardType: TextInputType.emailAddress,
                decoration: _input('Email (Login) *', Icons.email_outlined),
                validator: (v) =>
                    RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v!.trim())
                    ? null
                    : trf('Email មិនត្រឹមត្រូវ', 'Not a valid e-mail'),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: _input(
                  trf('លេខទូរស័ព្ទ', 'Phone'),
                  Icons.phone_outlined,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: _password,
                obscureText: _hide,
                autofillHints: const [AutofillHints.newPassword],
                decoration: _input(
                  _isNew
                      ? trf('ពាក្យសម្ងាត់ *', 'Password *')
                      : trf('ពាក្យសម្ងាត់ថ្មី', 'New password'),
                  Icons.lock_outline,
                  helper: _isNew
                      ? trf('យ៉ាងតិច 8 តួ', 'At least 8 characters')
                      : trf(
                          'ទុកទទេ = មិនប្តូរ',
                          'Empty = keep the current one',
                        ),
                  suffix: IconButton(
                    tooltip: _hide
                        ? trf('បង្ហាញ', 'Show')
                        : trf('លាក់', 'Hide'),
                    icon: Icon(
                      _hide
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () => setState(() => _hide = !_hide),
                  ),
                ),
                validator: (v) {
                  if (!_isNew && v!.isEmpty) return null;
                  return v!.length < 8
                      ? trf('យ៉ាងតិច 8 តួ', 'At least 8 characters')
                      : null;
                },
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  minimumSize: const Size.fromHeight(50),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(trf('រក្សាទុក', 'Save')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
