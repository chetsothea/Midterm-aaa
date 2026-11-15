import 'package:flutter/material.dart';
import '../models/location.dart';
import '../services/api_service.dart';
import '../services/language.dart';

typedef LocationLoader = Future<List<Location>> Function(String parentCode);

// Delivery address for Cambodia: country (fixed), then province → district →
// commune → village, each list loaded once the level above is picked,
// plus a free-text house / street line.
//
// [onChanged] gets the full address ("ផ្ទះ 12, ផ្លូវ 271, ភូមិ ១, សង្កាត់…, ខណ្ឌ…, រាជធានីភ្នំពេញ, កម្ពុជា"),
// or null while a level is still missing. Must sit inside a Form: every level validates.
class AddressPicker extends StatefulWidget {
  final ValueChanged<String?> onChanged;
  final LocationLoader loadLocations;
  // Corner roundness of the fields: 22 on the sign-up page (pill fields), 12 elsewhere
  final double radius;

  const AddressPicker({
    super.key,
    required this.onChanged,
    this.radius = 12,
    this.loadLocations = ApiService.fetchLocations,
  });

  // Saved in the address in Khmer, whatever the app's language
  static const country = 'កម្ពុជា';

  @override
  State<AddressPicker> createState() => _AddressPickerState();
}

class _AddressPickerState extends State<AddressPicker> {
  // A getter, so the labels follow the chosen language
  static List<(String, IconData)> get _levels => [
    (tr('ខេត្ត / រាជធានី'), Icons.map_outlined),
    (tr('ស្រុក / ក្រុង / ខណ្ឌ'), Icons.location_city),
    (tr('ឃុំ / សង្កាត់'), Icons.holiday_village_outlined),
    (tr('ភូមិ'), Icons.home_work_outlined),
  ];

  // Choices and pick for each level; null choices = not loaded yet
  final List<List<Location>?> _options = List.filled(4, null);
  final List<Location?> _picked = List.filled(4, null);
  final List<bool> _loading = List.filled(4, false);
  String? _error;
  final _street = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load(0, '');
    _street.addListener(_report);
  }

  @override
  void dispose() {
    _street.dispose();
    super.dispose();
  }

  Future<void> _load(int level, String parent) async {
    setState(() {
      _loading[level] = true;
      _error = null;
    });
    try {
      final list = await widget.loadLocations(parent);
      if (!mounted) return;
      setState(() => _options[level] = list);
    } catch (e) {
      if (mounted)
        setState(
          () => _error = trf(
            'មិនអាចទាញបញ្ជីទីតាំងបានទេ: $e',
            'Could not load the places: $e',
          ),
        );
    } finally {
      if (mounted) setState(() => _loading[level] = false);
    }
  }

  void _pick(int level, Location? location) {
    setState(() {
      _picked[level] = location;
      // Everything below depends on this choice, so start those levels again
      for (var i = level + 1; i < 4; i++) {
        _picked[i] = null;
        _options[i] = null;
      }
    });
    if (location != null && level < 3) _load(level + 1, location.code);
    _report();
  }

  void _report() {
    if (_picked.any((p) => p == null)) {
      widget.onChanged(null);
      return;
    }
    final street = _street.text.trim();
    // Smallest to largest, the way addresses are written in Cambodia
    widget.onChanged(
      [
        if (street.isNotEmpty) street,
        for (final p in _picked.reversed) p!.km,
        AddressPicker.country,
      ].join(', '),
    );
  }

  // Soft filled fields with light borders, like the rest of the app's forms
  OutlineInputBorder _border(Color color, [double width = 1.2]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(widget.radius),
        borderSide: BorderSide(color: color, width: width),
      );

  InputDecoration _decor(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, color: const Color(0xFF475569)),
    filled: true,
    fillColor: const Color(0xFFF8FAFC),
    border: _border(const Color(0xFFCBD5E1)),
    enabledBorder: _border(const Color(0xFFCBD5E1)),
    disabledBorder: _border(const Color(0xFFE2E8F0)),
    focusedBorder: _border(const Color(0xFF0E7490), 1.8),
    errorBorder: _border(Colors.red),
    focusedErrorBorder: _border(Colors.red, 1.8),
  );

  Widget _levelDropdown(int level) {
    final (label, icon) = _levels[level];
    final options = _options[level];
    final waitingForParent = level > 0 && _picked[level - 1] == null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<Location>(
        // New key when the parent changes, so the old pick is cleared
        key: ValueKey('$level-${level == 0 ? '' : _picked[level - 1]?.code}'),
        initialValue: _picked[level],
        isExpanded: true,
        menuMaxHeight: 400,
        decoration: _decor(label, icon).copyWith(
          suffixIcon: _loading[level]
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : null,
        ),
        hint: Text(
          waitingForParent
              ? trf(
                  'សូមជ្រើស${_levels[level - 1].$1.split(' ').first}សិន',
                  'Choose the ${_levels[level - 1].$1.split(' /').first.toLowerCase()} first',
                )
              : tr('ជ្រើសរើស'),
        ),
        items: [
          for (final location in options ?? const <Location>[])
            DropdownMenuItem(
              value: location,
              child: Text(location.km, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: options == null
            ? null
            : (location) => _pick(level, location),
        validator: (value) => value == null
            ? trf(
                'សូមជ្រើស${label.split(' ').first}',
                'Please choose a ${label.split(' /').first.toLowerCase()}',
              )
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: InputDecorator(
            decoration: _decor(
              tr('ប្រទេស'),
              Icons.public,
            ).copyWith(enabled: false),
            child: Text(tr(AddressPicker.country)),
          ),
        ),
        for (var level = 0; level < 4; level++) _levelDropdown(level),
        TextFormField(
          controller: _street,
          decoration: _decor(
            tr('ផ្ទះលេខ / ផ្លូវ (មិនបង្ខំ)'),
            Icons.signpost_outlined,
          ).copyWith(hintText: tr('ឧ. ផ្ទះ 12, ផ្លូវ 271')),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_error!, style: const TextStyle(color: Colors.red)),
          ),
      ],
    );
  }
}
