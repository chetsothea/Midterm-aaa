import 'package:flutter/material.dart';
import '../../models/customer.dart';
import '../../services/api_service.dart';
import '../../widgets/common.dart';
import 'customer_form_screen.dart';

// Everyone who has registered: opened from the "អតិថិជន" tile on the dashboard
class AdminCustomersScreen extends StatefulWidget {
  const AdminCustomersScreen({super.key});

  @override
  State<AdminCustomersScreen> createState() => _AdminCustomersScreenState();
}

class _AdminCustomersScreenState extends State<AdminCustomersScreen> {
  late Future<List<Customer>> _customers = ApiService.fetchCustomers();

  Future<void> _refresh() async {
    setState(() {
      _customers = ApiService.fetchCustomers();
    });
    await _customers;
  }

  static String _date(DateTime d) => '${d.day}/${d.month}/${d.year}';

  // Search box and the all / active / blocked chips: both work on the loaded list
  String _search = '';
  String _filter = 'all';

  static const _navy = Color(0xFF0F2A5F);

  // A steady colour per customer for their initial, so the list isn't all one colour
  static const _avatarColors = [
    Color(0xFF2563EB),
    Color(0xFF0E7490),
    Color(0xFF7C3AED),
    Color(0xFFEA580C),
    Color(0xFF16A34A),
    Color(0xFFDB2777),
  ];

  Widget _detail(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF0E7490)),
        const SizedBox(width: 8),
        Expanded(
          child: SelectableText(text, style: const TextStyle(fontSize: 13)),
        ),
      ],
    ),
  );

  Widget _card(Customer customer) {
    final color = _avatarColors[customer.id % _avatarColors.length];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
        // Red down the side for a blocked account
        border: Border(
          left: BorderSide(
            color: customer.blocked ? Colors.red : color,
            width: 5,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: color.withValues(alpha: 0.12),
                  child: Text(
                    customer.name.isEmpty
                        ? '?'
                        : customer.name[0].toUpperCase(),
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customer.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: _navy,
                        ),
                      ),
                      Text(
                        'ចុះឈ្មោះ ${_date(customer.joined)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black45,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF97316).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${customer.orders} Order',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFEA580C),
                    ),
                  ),
                ),
              ],
            ),
            if (customer.blocked) ...[
              const SizedBox(height: 8),
              const StatusBadge(status: 'cancelled', label: 'គណនីបានបិទ'),
            ],
            const SizedBox(height: 4),
            _detail(Icons.mail_outline, customer.email),
            if (customer.phone.isNotEmpty)
              _detail(Icons.phone_outlined, customer.phone),
            if (customer.address.isNotEmpty)
              _detail(Icons.location_on_outlined, customer.address),
            const Divider(height: 22),
            // Wrap: the buttons drop to a second line on a narrow phone
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 4,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _edit(customer),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('កែ'),
                ),
                customer.blocked
                    ? OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF16A34A),
                        ),
                        onPressed: () => _setBlocked(customer, false),
                        icon: const Icon(Icons.lock_open, size: 18),
                        label: const Text('បើកវិញ'),
                      )
                    : OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFEA580C),
                        ),
                        onPressed: () => _setBlocked(customer, true),
                        icon: const Icon(Icons.block, size: 18),
                        label: const Text('បិទគណនី'),
                      ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  onPressed: () => _delete(customer),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('លុប'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Customer> _shown(List<Customer> all) {
    final query = _search.trim().toLowerCase();
    return all.where((c) {
      if (_filter == 'active' && c.blocked) return false;
      if (_filter == 'blocked' && !c.blocked) return false;
      return query.isEmpty ||
          c.name.toLowerCase().contains(query) ||
          c.email.toLowerCase().contains(query) ||
          c.phone.replaceAll(' ', '').contains(query.replaceAll(' ', ''));
    }).toList();
  }

  Widget _chip(String value, String label, int count, Color color) {
    final selected = _filter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        showCheckmark: false,
        visualDensity: VisualDensity.compact,
        selected: selected,
        selectedColor: color,
        backgroundColor: Colors.white,
        side: BorderSide(color: selected ? color : Colors.black12),
        label: Text(
          '$label  $count',
          style: TextStyle(
            color: selected ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        onSelected: (_) => setState(() => _filter = value),
      ),
    );
  }

  // Search box, then all / active / blocked with how many in each
  Widget _toolbar(List<Customer> all) {
    final blocked = all.where((c) => c.blocked).length;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Column(
        children: [
          TextField(
            onChanged: (value) => setState(() => _search = value),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'ស្វែងរក ឈ្មោះ Email ឬលេខទូរស័ព្ទ',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: const Color(0xFFF1F5F9),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _chip('all', 'ទាំងអស់', all.length, _navy),
                _chip(
                  'active',
                  'សកម្ម',
                  all.length - blocked,
                  const Color(0xFF16A34A),
                ),
                _chip('blocked', 'បានបិទ', blocked, Colors.red),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _edit(Customer customer) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => CustomerFormScreen(customer: customer)),
    );
    if (saved == true) _refresh();
  }

  void _setBlocked(Customer customer, bool blocked) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          blocked
              ? 'បិទគណនី ${customer.name}?'
              : 'បើកគណនី ${customer.name} វិញ?',
        ),
        content: Text(
          blocked
              ? 'អតិថិជននេះនឹងត្រូវបានចាកចេញភ្លាម ហើយមិនអាច Login បានទេ។ Order ចាស់ៗនៅដដែល។ អ្នកអាចបើកវិញបានគ្រប់ពេល។'
              : 'អតិថិជននេះនឹងអាច Login បានវិញ។',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ទេ'),
          ),
          FilledButton(
            style: blocked
                ? FilledButton.styleFrom(backgroundColor: Colors.red)
                : null,
            onPressed: () => Navigator.pop(context, true),
            child: Text(blocked ? 'បិទគណនី' : 'បើកវិញ'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await ApiService.setCustomerBlocked(customer.id, blocked);
      if (mounted) {
        showMessage(
          context,
          blocked
              ? 'បានបិទគណនី ${customer.name}'
              : 'បានបើកគណនី ${customer.name} វិញ',
        );
      }
      _refresh();
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    }
  }

  void _delete(Customer customer) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('លុបគណនី ${customer.name}?'),
        content: Text(
          'លុបហើយមិនអាចយកមកវិញបានទេ។ អតិថិជននេះនឹងមិនអាច Login បានទៀត។'
          '${customer.orders > 0 ? ' Order ${customer.orders} របស់គាត់នៅតែមានសម្រាប់ហាង ប៉ុន្តែគាត់នឹងមិនអាចមើលវាបានទេ។' : ''}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ទេ'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('លុប'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await ApiService.deleteCustomer(customer.id);
      if (mounted) showMessage(context, 'បានលុបគណនី ${customer.name}');
      _refresh();
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(title: const Text('អតិថិជន')),
      body: FutureBuilder<List<Customer>>(
        future: _customers,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final customers = snapshot.data!;
          if (customers.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refresh,
              // A ListView, so an empty list can still be pulled to refresh
              child: ListView(
                children: const [
                  SizedBox(height: 120),
                  Icon(Icons.people_outline, size: 56, color: Colors.black26),
                  SizedBox(height: 8),
                  Center(child: Text('មិនទាន់មានអតិថិជនចុះឈ្មោះទេ')),
                ],
              ),
            );
          }
          final shown = _shown(customers);
          return Column(
            children: [
              _toolbar(customers),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
                        child: Text(
                          'សរុប ${customers.length} នាក់',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                      if (shown.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(40),
                          child: Center(child: Text('រកមិនឃើញអតិថិជន')),
                        ),
                      for (final customer in shown) _card(customer),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
