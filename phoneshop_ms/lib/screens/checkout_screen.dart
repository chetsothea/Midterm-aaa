import '../data/riel.dart';
import 'package:flutter/material.dart';
import '../data/api_service.dart';
import '../data/models/voucher.dart';
import '../hooks/cart.dart';
import '../components/address_picker.dart';
import '../components/buying_steps.dart';
import '../components/common.dart';
import '../components/store_app_bar.dart';
import 'invoice_screen.dart';
import 'my_orders_screen.dart';
import 'payment_screen.dart';
import '../components/motion.dart';
import '../hooks/language.dart';
import '../components/ux.dart';
import '../components/order_success.dart';
import '../theme/app_theme.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  // Pre-filled from the account; the customer can change them for this order.
  final _name = TextEditingController(text: ApiService.currentUser?.name);
  final _email = TextEditingController(text: ApiService.currentUser?.email);
  final _phone = TextEditingController(text: ApiService.currentUser?.phone);
  // The address saved on the account at registration, used unless the customer changes it
  final String _savedAddress = ApiService.currentUser?.address ?? '';
  // The other saved addresses (id, label, address): "Work", "Mum's" ...
  List<(int, String, String)> _extra = [];
  // The saved address this order goes to; null = typing a new one below
  late String? _picked = _savedAddress.isEmpty ? null : _savedAddress;
  late String _pickedLabel = trf('អាសយដ្ឋានគណនី', 'Account address');
  // Built by AddressPicker from province → village (+ house/street); null until complete
  String? _address;
  // A new address can be kept for next time, under a name
  bool _keepNew = false;
  String _newLabel = 'ការងារ';
  String _paymentMethod = 'khqr';
  bool _isLoading = false;

  // Price from the server: phones, delivery for this address, and the code
  Quote? _quote;
  int _quoteRun = 0; // only the newest answer counts
  final _voucher = TextEditingController();
  String _appliedCode = '';
  String? _voucherError;
  bool _checkingCode = false;

  String get _currentAddress => _picked ?? (_address ?? '');

  @override
  void initState() {
    super.initState();
    _refreshQuote();
    if (ApiService.isLoggedIn) {
      ApiService.fetchAddresses()
          .then((list) {
            if (!mounted) return;
            setState(() {
              _extra = list;
              // No address on the account: start on the first saved one
              if (_picked == null && _address == null && list.isNotEmpty) {
                _pickedLabel = list.first.$2;
                _picked = list.first.$3;
              }
            });
            _refreshQuote();
          })
          .catchError((_) {});
    }
  }

  void _pick(String? address, [String label = '']) {
    setState(() {
      _picked = address;
      if (label.isNotEmpty) _pickedLabel = label;
    });
    _refreshQuote();
  }

  Future<void> _forget((int, String, String) a) async {
    try {
      await ApiService.deleteAddress(a.$1);
      if (mounted) setState(() => _extra.remove(a));
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    }
  }

  // Asks the server again (address or code changed). A code that no longer
  // works is dropped with its reason, and the price falls back to no code.
  Future<void> _refreshQuote({String? tryCode}) async {
    final run = ++_quoteRun;
    final code = tryCode ?? _appliedCode;
    try {
      final quote = await ApiService.quote(
        items: Cart.instance.toOrderItems(),
        address: _currentAddress,
        voucherCode: code,
      );
      if (!mounted || run != _quoteRun) return;
      setState(() {
        _quote = quote;
        _appliedCode = quote.voucherCode;
        _voucherError = null;
      });
      if (tryCode != null && quote.voucherCode.isNotEmpty) {
        Haptics.success();
      }
    } on ApiException catch (e) {
      if (!mounted || run != _quoteRun) return;
      if (code.isNotEmpty) {
        setState(() {
          _voucherError = e.message;
          _appliedCode = '';
        });
        if (tryCode == null) _refreshQuote(); // price without the dead code
      }
    } catch (_) {
      // Offline or mock mode: the cart total is shown instead
    }
  }

  Future<void> _applyCode() async {
    final code = _voucher.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() => _voucherError = trf('សូមបញ្ចូលកូដ', 'Enter a code'));
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _checkingCode = true);
    await _refreshQuote(tryCode: code);
    if (mounted) setState(() => _checkingCode = false);
  }

  void _removeCode() {
    setState(() {
      _appliedCode = '';
      _voucher.clear();
      _voucherError = null;
    });
    _refreshQuote();
  }

  void _placeOrder() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final order = await ApiService.placeOrder(
        items: Cart.instance.toOrderItems(),
        paymentMethod: _paymentMethod,
        customerName: _name.text.trim(),
        customerEmail: _email.text.trim(),
        phone: _phone.text.trim(),
        // With the picker on screen, validate() above made sure every level is picked
        address: _picked ?? _address!,
        voucherCode: _appliedCode,
      );
      // A new address the customer wants to keep for next time
      if (_picked == null && _keepNew && _address != null) {
        ApiService.saveAddress(
          _newLabel.trim().isEmpty ? 'ផ្សេងៗ' : _newLabel.trim(),
          _address!,
        ).catchError((_) {});
      }
      Cart.instance.clear();
      if (!mounted) return;

      // KHQR goes straight to payment; COD is paid on delivery
      final next = order.paymentMethod == 'khqr'
          ? PaymentScreen(order: order)
          : const MyOrdersScreen();
      // ✓ draws itself, confetti, a firm haptic, over the page that opens next
      celebrateOrder(
        context,
        orderRef: order.ref,
        payNow: order.paymentMethod == 'khqr',
      );
      Navigator.of(context)
        ..popUntil((route) => route.isFirst)
        ..push(MaterialPageRoute(builder: (_) => next));
      // COD is done here, so hand over the bill; KHQR customers pay first
      if (order.paymentMethod != 'khqr') {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => InvoiceScreen(order: order)));
      }
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _email, _phone, _voucher]) {
      c.dispose();
    }
    super.dispose();
  }

  static Color get _navy => AppColors.text;
  static const _orange = Color(0xFF3D7BFF);

  // Soft filled fields with rounded corners
  InputDecoration _decor(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon),
    filled: true,
    fillColor: AppColors.surface,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: BorderSide(color: AppColors.line),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: BorderSide(color: AppColors.line),
    ),
  );

  // A white card headed by its step number, like the other pages
  Widget _section(
    int step,
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
              // The step number on the store's navy-to-teal
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_navy, Color(0xFF3D7BFF)],
                  ),
                ),
                child: Text(
                  '$step',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: _navy,
                  ),
                ),
              ),
            ],
          ),
          if (hint != null) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(hint, style: TextStyle(color: AppColors.muted, fontSize: 13)),
          ],
          const SizedBox(height: AppSpacing.sm),
          ...children,
        ],
      ),
    );
  }

  Widget _cartRow(CartItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            padding: const EdgeInsets.all(AppSpacing.xxs),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.md),
              gradient: LinearGradient(
                colors: [AppColors.surfaceHigh, AppColors.tileLow],
              ),
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadow,
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: PhoneImage(url: item.phone.imageFor(item.color), size: 44),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item.phone.name} × ${item.qty}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (item.options.isNotEmpty) CartOptionsLabel(item: item),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            money(item.subtotal),
            style: TextStyle(fontWeight: FontWeight.w800, color: _navy),
          ),
        ],
      ),
    );
  }

  // One of the two ways to pay, as a tile that lights up when picked
  Widget _payOption(String method, IconData icon) {
    final selected = _paymentMethod == method;
    final color = method == 'cod' ? const Color(0xFF30D158) : _navy;
    return Expanded(
      child: Material(
        color: selected ? color.withValues(alpha: 0.08) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(
            color: selected ? color : AppColors.line,
            width: selected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => setState(() => _paymentMethod = method),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: 10,
            ),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  size: 18,
                  color: selected ? color : Colors.black38,
                ),
                const SizedBox(width: 6),
                Icon(icon, size: 20, color: color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    paymentMethodLabels[method]!,
                    maxLines: 2,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Code field, or the applied code as a chip that can be taken off
  Widget _voucherBox() {
    if (_appliedCode.isNotEmpty) {
      return Container(
        padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
        decoration: BoxDecoration(
          color: AppColors.green.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.green.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Icon(Icons.local_offer, size: 20, color: AppColors.green),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                trf(
                  '$_appliedCode · បញ្ចុះ ${_quote?.voucherLabel ?? ''}',
                  '$_appliedCode · ${_quote?.voucherLabel ?? ''} off',
                ),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
            ),
            IconButton(
              tooltip: trf('ដកកូដចេញ', 'Remove code'),
              onPressed: _removeCode,
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextField(
            controller: _voucher,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _applyCode(),
            decoration: _decor(
              trf('កូដបញ្ចុះតម្លៃ (បើមាន)', 'Discount code (optional)'),
              Icons.local_offer_outlined,
            ).copyWith(errorText: _voucherError, errorMaxLines: 2),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        SizedBox(
          height: 56,
          child: OutlinedButton(
            onPressed: _checkingCode ? null : _applyCode,
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
            child: _checkingCode
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(trf('ប្រើ', 'Apply')),
          ),
        ),
      ],
    );
  }

  Widget _priceRow(
    String label,
    String value, {
    Color? color,
    bool bold = false,
  }) {
    final style = TextStyle(
      color: color ?? (bold ? AppColors.text : AppColors.muted),
      fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
      fontSize: bold ? 16 : 14,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }

  // Phones, delivery, discount and total, as the server priced them
  Widget _summary(double cartTotal) {
    final q = _quote;
    final hasAddress = _currentAddress.isNotEmpty;
    final more = q?.moreForFreeDelivery;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _priceRow(trf('ទំនិញ', 'Phones'), money(q?.subtotal ?? cartTotal)),
        _priceRow(
          q == null || !hasAddress
              ? trf('ថ្លៃដឹកជញ្ជូន', 'Delivery')
              : q.phnomPenh
              ? trf('ថ្លៃដឹក (ភ្នំពេញ)', 'Delivery (Phnom Penh)')
              : trf('ថ្លៃដឹក (ខេត្ត)', 'Delivery (province)'),
          q == null
              ? '—'
              : !hasAddress
              ? trf('ជ្រើសទីតាំងសិន', 'Pick an address')
              : q.shippingFee == 0
              ? trf('ឥតគិតថ្លៃ', 'Free')
              : money(q.shippingFee),
          color: q != null && hasAddress && q.shippingFee == 0
              ? AppColors.green
              : null,
        ),
        if ((q?.discount ?? 0) > 0)
          _priceRow(
            trf(
              'បញ្ចុះតម្លៃ (${q!.voucherCode})',
              'Discount (${q.voucherCode})',
            ),
            '-${money(q.discount)}',
            color: AppColors.green,
          ),
        Divider(height: AppSpacing.md, color: AppColors.line),
        _priceRow(
          trf('សរុប', 'Total'),
          money(q?.total ?? cartTotal),
          bold: true,
        ),
        if (Riel.shown)
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '≈ ${Riel.of(q?.total ?? cartTotal)}',
              style: TextStyle(color: AppColors.muted, fontSize: 13),
            ),
          ),
        if (more != null && hasAddress)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xxs),
            child: Text(
              trf(
                'ទិញបន្ថែម ${money(more)} ទៀត ដើម្បីដឹកឥតគិតថ្លៃ',
                'Spend ${money(more)} more for free delivery',
              ),
              style: TextStyle(color: AppColors.accent, fontSize: 13),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = Cart.instance;
    return Scaffold(
      backgroundColor: AppColors.page,
      appBar: storeAppBar(title: const Text('Checkout')),
      body: Form(
        key: _formKey,
        // Not a ListView: every field must stay built so validate() checks all of them
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: Entrance.stagger([
              const BuyingSteps(current: 1),
              const SizedBox(height: AppSpacing.sm),
              _section(1, tr('ទំនិញ'), [
                for (final item in cart.items) _cartRow(item),
              ]),
              _section(
                2,
                tr('ព័ត៌មានអ្នកទិញ'),
                hint: tr('សម្រាប់ដឹកជញ្ជូន និងទាក់ទងអ្នកអំពី Order'),
                [
                  TextFormField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    decoration: _decor(tr('ឈ្មោះ *'), Icons.person_outline),
                    validator: (v) =>
                        v!.trim().isEmpty ? tr('សូមបញ្ចូលឈ្មោះ') : null,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: _decor('Email *', Icons.email_outlined),
                    validator: (v) =>
                        RegExp(
                          r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                        ).hasMatch(v!.trim())
                        ? null
                        : tr('Email មិនត្រឹមត្រូវ'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: _decor(
                      tr('លេខទូរស័ព្ទ *'),
                      Icons.phone_outlined,
                    ),
                    validator: (v) => v!.trim().length < 8
                        ? tr('សូមបញ្ចូលលេខទូរស័ព្ទឱ្យត្រឹមត្រូវ')
                        : null,
                  ),
                ],
              ),
              _section(3, tr('ទីតាំងដឹកជញ្ជូន'), [
                if (_picked != null)
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 12, 4, 4),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.line),
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
                            const SizedBox(width: AppSpacing.xs),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _pickedLabel,
                                    style: TextStyle(
                                      color: AppColors.muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(_picked!),
                                ],
                              ),
                            ),
                          ],
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () => _pick(null),
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
                  // The other saved addresses, one tap each
                  for (final a in _extra)
                    Card(
                      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                      color: AppColors.surface,
                      child: ListTile(
                        leading: const Icon(Icons.bookmark_outline),
                        title: Text(a.$2),
                        subtitle: Text(
                          a.$3,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => _pick(a.$3, a.$2),
                        trailing: IconButton(
                          tooltip: trf(
                            'លុបអាសយដ្ឋាននេះ',
                            'Forget this address',
                          ),
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => _forget(a),
                        ),
                      ),
                    ),
                  if (_extra.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.xs,
                      ),
                      child: Text(
                        trf('ឬ អាសយដ្ឋានថ្មី:', 'Or a new address:'),
                        style: TextStyle(color: AppColors.muted),
                      ),
                    ),
                  AddressPicker(
                    onChanged: (address) {
                      _address = address;
                      _refreshQuote();
                    },
                  ),
                  // Keep it for next time, under a short name
                  if (ApiService.isLoggedIn) ...[
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _keepNew,
                      onChanged: (v) => setState(() => _keepNew = v ?? false),
                      title: Text(
                        trf('រក្សាទុកអាសយដ្ឋាននេះ', 'Save this address'),
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    if (_keepNew)
                      Wrap(
                        spacing: AppSpacing.xs,
                        children: [
                          for (final label in [
                            'ការងារ',
                            'ផ្ទះឪពុកម្តាយ',
                            'ផ្សេងៗ',
                          ])
                            ChoiceChip(
                              label: Text(label),
                              selected: _newLabel == label,
                              onSelected: (_) =>
                                  setState(() => _newLabel = label),
                            ),
                        ],
                      ),
                  ],
                  if (_savedAddress.isNotEmpty)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => _pick(
                          _savedAddress,
                          trf('អាសយដ្ឋានគណនី', 'Account address'),
                        ),
                        child: Text(tr('ប្រើទីតាំងដែលបានរក្សាទុក')),
                      ),
                    ),
                ],
              ]),
              _section(4, trf('កូដបញ្ចុះតម្លៃ និងសរុប', 'Code and total'), [
                _voucherBox(),
                const SizedBox(height: AppSpacing.sm),
                _summary(cart.total),
              ]),
            ]),
          ),
        ),
      ),
      // Stays on screen with the order button, so the choice can't be missed further down
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
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  tr('វិធីបង់ប្រាក់'),
                  style: TextStyle(fontWeight: FontWeight.w700, color: _navy),
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    _payOption('khqr', Icons.qr_code_2),
                    const SizedBox(width: AppSpacing.xs),
                    _payOption('cod', Icons.payments_outlined),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          tr('សរុប'),
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.muted,
                          ),
                        ),
                        Text(
                          money(_quote?.total ?? cart.total),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: _navy,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _isLoading
                          ? BusyBar(
                              label: trf(
                                'កំពុងបញ្ជាទិញ...',
                                'Placing order...',
                              ),
                            )
                          : FilledButton.icon(
                              onPressed: cart.isEmpty ? null : _placeOrder,
                              style: FilledButton.styleFrom(
                                backgroundColor: _orange,
                                minimumSize: const Size.fromHeight(50),
                                elevation: 2,
                                shadowColor: const Color(0x663D7BFF),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              icon: const Icon(Icons.shopping_bag_outlined),
                              label: Text(tr('បញ្ជាទិញ')),
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
