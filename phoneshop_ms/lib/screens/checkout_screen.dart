import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/cart.dart';
import '../widgets/address_picker.dart';
import '../widgets/buying_steps.dart';
import '../widgets/common.dart';
import '../widgets/store_app_bar.dart';
import 'invoice_screen.dart';
import 'my_orders_screen.dart';
import 'payment_screen.dart';
import '../services/language.dart';

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
  late bool _useSavedAddress = _savedAddress.isNotEmpty;
  // Built by AddressPicker from province → village (+ house/street); null until complete
  String? _address;
  String _paymentMethod = 'khqr';
  bool _isLoading = false;

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
        address: _useSavedAddress ? _savedAddress : _address!,
      );
      Cart.instance.clear();
      if (!mounted) return;

      // KHQR goes straight to payment; COD is paid on delivery
      final next = order.paymentMethod == 'khqr'
          ? PaymentScreen(order: order)
          : const MyOrdersScreen();
      showMessage(
        context,
        trf(
          'បញ្ជាទិញជោគជ័យ! Order ${order.ref}',
          'Order placed! Order ${order.ref}',
        ),
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
    for (final c in [_name, _email, _phone]) {
      c.dispose();
    }
    super.dispose();
  }

  static const _navy = Color(0xFF0F2A5F);
  static const _orange = Color(0xFFF97316);

  // Soft filled fields with rounded corners
  InputDecoration _decor(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon),
    filled: true,
    fillColor: const Color(0xFFF8FAFC),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
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
              // The step number on the store's navy-to-teal
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_navy, Color(0xFF0E7490)],
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
              const SizedBox(width: 8),
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
            const SizedBox(height: 4),
            Text(
              hint,
              style: const TextStyle(color: Colors.black54, fontSize: 13),
            ),
          ],
          const SizedBox(height: 12),
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
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: const LinearGradient(
                colors: [Color(0xFFE0F2FE), Color(0xFFEDE9FE)],
              ),
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1F1D4ED8),
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
          const SizedBox(width: 8),
          Text(
            money(item.subtotal),
            style: const TextStyle(fontWeight: FontWeight.w800, color: _navy),
          ),
        ],
      ),
    );
  }

  // One of the two ways to pay, as a tile that lights up when picked
  Widget _payOption(String method, IconData icon) {
    final selected = _paymentMethod == method;
    final color = method == 'cod' ? const Color(0xFF16A34A) : _navy;
    return Expanded(
      child: Material(
        color: selected ? color.withValues(alpha: 0.08) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: selected ? color : const Color(0xFFE2E8F0),
            width: selected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => setState(() => _paymentMethod = method),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
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

  @override
  Widget build(BuildContext context) {
    final cart = Cart.instance;
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: storeAppBar(title: const Text('Checkout')),
      body: Form(
        key: _formKey,
        // Not a ListView: every field must stay built so validate() checks all of them
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const BuyingSteps(current: 1),
              const SizedBox(height: 12),
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
                  const SizedBox(height: 12),
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
                  const SizedBox(height: 12),
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
                if (_useSavedAddress)
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
                            Expanded(child: Text(_savedAddress)),
                          ],
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () => setState(() {
                              _useSavedAddress = false;
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
                  if (_savedAddress.isNotEmpty)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => setState(() {
                          _useSavedAddress = true;
                        }),
                        child: Text(tr('ប្រើទីតាំងដែលបានរក្សាទុក')),
                      ),
                    ),
                ],
              ]),
            ],
          ),
        ),
      ),
      // Stays on screen with the order button, so the choice can't be missed further down
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
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  tr('វិធីបង់ប្រាក់'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _navy,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _payOption('khqr', Icons.qr_code_2),
                    const SizedBox(width: 8),
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
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                        Text(
                          money(cart.total),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: _navy,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _isLoading
                          ? const SizedBox(
                              height: 50,
                              child: Center(child: CircularProgressIndicator()),
                            )
                          : FilledButton.icon(
                              onPressed: cart.isEmpty ? null : _placeOrder,
                              style: FilledButton.styleFrom(
                                backgroundColor: _orange,
                                minimumSize: const Size.fromHeight(50),
                                elevation: 2,
                                shadowColor: const Color(0x66F97316),
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
