import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Add this enum at top
enum CheckoutRule { 
  doubleOut,    // Standard Double‐Out
  extendedOut,  // Extended Out
  exactOut,     // Exact 0 Only
  openFinish    // Open Finish
}

class OptionsScreen extends StatefulWidget {
  final bool isDarkMode;
  final ValueChanged<bool> onThemeChanged;

  const OptionsScreen({
    super.key,
    required this.isDarkMode,
    required this.onThemeChanged,
  });

  @override
  State<OptionsScreen> createState() => _OptionsScreenState();
}

class _OptionsScreenState extends State<OptionsScreen> {
  late bool _darkMode;
  // add this state var:
  late CheckoutRule _checkoutRule;

  @override
  void initState() {
    super.initState();
    _darkMode = widget.isDarkMode;
    // load saved checkout rule (default to doubleOut)
    SharedPreferences.getInstance().then((prefs) {
      setState(() {
        _checkoutRule = CheckoutRule
          .values[prefs.getInt('checkoutRule') ?? 0];
      });
    });
  }

  Future<void> _toggleDarkMode(bool value) async {
    setState(() {
      _darkMode = value;
    });
    widget.onThemeChanged(value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('darkMode', value);
  }

  // add this handler:
  Future<void> _updateCheckoutRule(CheckoutRule? value) async {
    if (value == null) return;
    setState(() => _checkoutRule = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('checkoutRule', value.index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Options')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                SwitchListTile(
                  title: const Text('Dark Mode'),
                  value: _darkMode,
                  onChanged: _toggleDarkMode,
                ),
                const Divider(),
                // start of new Traditional Game section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'Checkout Rule',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                RadioListTile<CheckoutRule>(
                  title: const Text('Standard Double‐Out'),
                  subtitle: const Text('Must finish on a double or bull.'),
                  value: CheckoutRule.doubleOut,
                  groupValue: _checkoutRule,
                  onChanged: _updateCheckoutRule,
                ),
                RadioListTile<CheckoutRule>(
                  title: const Text('Extended Out'),
                  subtitle: const Text('Allow finish on double, triple, inner/outer bull.'),
                  value: CheckoutRule.extendedOut,
                  groupValue: _checkoutRule,
                  onChanged: _updateCheckoutRule,
                ),
                RadioListTile<CheckoutRule>(
                  title: const Text('Exact 0 Only'),
                  subtitle: const Text('Any segment, but must land exactly on 0.'),
                  value: CheckoutRule.exactOut,
                  groupValue: _checkoutRule,
                  onChanged: _updateCheckoutRule,
                ),
                RadioListTile<CheckoutRule>(
                  title: const Text('Open Finish'),
                  subtitle: const Text('First to 0 or below wins—no bust required.'),
                  value: CheckoutRule.openFinish,
                  groupValue: _checkoutRule,
                  onChanged: _updateCheckoutRule,
                ),
                const Divider(),
                // ...other options...
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Center(
              child: GestureDetector(
                onTap: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Confirm Erase'),
                      content: const Text('Are you sure you want to erase all app data? This cannot be undone.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: const Text('Erase', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.clear();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('All data erased')),
                      );
                    }
                  }
                },
                child: const Text(
                  'Erase All Data',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.underline,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}