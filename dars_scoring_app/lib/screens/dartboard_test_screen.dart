import 'package:flutter/material.dart';
import '../widgets/interactive_dartboard.dart';

class DartboardTestScreen extends StatefulWidget {
  const DartboardTestScreen({super.key});

  @override
  State<DartboardTestScreen> createState() => _DartboardTestScreenState();
}

class _DartboardTestScreenState extends State<DartboardTestScreen> {
  final TextEditingController _highlightController = TextEditingController();
  Set<String> _highlightedAreas = {};
  String? _lastTappedArea;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dartboard Test'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Dartboard
            Card(
              elevation: 8,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: InteractiveDartboard(
                  size: 350,
                  highlightedAreas: _highlightedAreas,
                  onAreaTapped: (area) {
                    setState(() {
                      _lastTappedArea = area;
                    });
                  },
                  highlightColor: Colors.orange,
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Input controls
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Highlight Controls',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _highlightController,
                            decoration: const InputDecoration(
                              labelText: 'Areas to highlight',
                              hintText: 'e.g., 20, T15, D5, BULL',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _applyHighlights,
                          child: const Text('Apply'),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 12),
                    
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed: _clearHighlights,
                          child: const Text('Clear All'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _showPresetExamples,
                          child: const Text('Examples'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Information display
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Information',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    
                    if (_lastTappedArea != null)
                      Text('Last tapped: $_lastTappedArea'),
                    
                    const SizedBox(height: 8),
                    
                    Text('Currently highlighted: ${_highlightedAreas.isEmpty ? 'None' : _highlightedAreas.join(', ')}'),
                    
                    const SizedBox(height: 16),
                    
                    const Text(
                      'Highlight Format Examples:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    
                    _buildFormatExample('20', 'Entire 20 section (all multipliers)'),
                    _buildFormatExample('S20', 'Single 20 only (non-multiplier areas)'),
                    _buildFormatExample('T15', 'Triple 15'),
                    _buildFormatExample('D5', 'Double 5'),
                    _buildFormatExample('20I', 'Inner part of 20 (from 25 ring to triple ring)'),
                    _buildFormatExample('20O', 'Outer part of 20 (from triple ring to double ring)'),
                    _buildFormatExample('BULL', 'Bull (50 points)'),
                    _buildFormatExample('25', 'Outer bull (25 points)'),
                    _buildFormatExample('20, T15, D5', 'Multiple areas (comma-separated)'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormatExample(String format, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              format,
              style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold),
            ),
          ),
          const Text(' - '),
          Expanded(child: Text(description)),
        ],
      ),
    );
  }

  void _applyHighlights() {
    final input = _highlightController.text.trim();
    if (input.isEmpty) {
      _clearHighlights();
      return;
    }

    setState(() {
      _highlightedAreas = _parseHighlightInput(input);
    });
  }

  void _clearHighlights() {
    setState(() {
      _highlightedAreas.clear();
      _highlightController.clear();
    });
  }

  void _showPresetExamples() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Preset Examples',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            _buildPresetButton('20', 'Highlight entire 20 (all multipliers)'),
            _buildPresetButton('S20', 'Highlight single 20 only'),
            _buildPresetButton('T15', 'Highlight triple 15'),
            _buildPresetButton('20, BULL, 25, 3', 'Bowtie pattern'),
            _buildPresetButton('20, D5, T15, 18', 'Mixed highlights'),
            _buildPresetButton('20I', 'Inner 20 only'),
            _buildPresetButton('20O', 'Outer 20 only'),
            _buildPresetButton('T20, T19, T18, T17, T16, T15', 'All high triples'),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetButton(String preset, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ElevatedButton(
        onPressed: () {
          Navigator.pop(context);
          setState(() {
            _highlightController.text = preset;
            _highlightedAreas = _parseHighlightInput(preset);
          });
        },
        child: SizedBox(
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(preset, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(description, style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  Set<String> _parseHighlightInput(String input) {
    final areas = <String>{};
    final parts = input.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty);

    for (final part in parts) {
      final cleanPart = part.toUpperCase();
      
      // Handle different formats
      if (cleanPart == 'BULL' || cleanPart == '50') {
        areas.add('BULL');
      } else if (cleanPart == '25') {
        areas.add('25');
      } else if (cleanPart.startsWith('S')) {
        // Single areas only (non-multiplier)
        final numberStr = cleanPart.substring(1);
        if (_isValidNumber(numberStr)) {
          areas.add('S$numberStr');
        }
      } else if (cleanPart.startsWith('T')) {
        // Triple
        final numberStr = cleanPart.substring(1);
        if (_isValidNumber(numberStr)) {
          areas.add('T$numberStr');
        }
      } else if (cleanPart.startsWith('D')) {
        // Double
        final numberStr = cleanPart.substring(1);
        if (_isValidNumber(numberStr)) {
          areas.add('D$numberStr');
        }
      } else if (cleanPart.endsWith('I')) {
        // Inner single
        final numberStr = cleanPart.substring(0, cleanPart.length - 1);
        if (_isValidNumber(numberStr)) {
          areas.add('${numberStr}I');
        }
      } else if (cleanPart.endsWith('O')) {
        // Outer single
        final numberStr = cleanPart.substring(0, cleanPart.length - 1);
        if (_isValidNumber(numberStr)) {
          areas.add('${numberStr}O');
        }
      } else if (_isValidNumber(cleanPart)) {
        // Entire number section (all multipliers)
        areas.add(cleanPart);
      }
    }

    return areas;
  }

  bool _isValidNumber(String numberStr) {
    final number = int.tryParse(numberStr);
    return number != null && number >= 1 && number <= 20;
  }

  @override
  void dispose() {
    _highlightController.dispose();
    super.dispose();
  }
}
