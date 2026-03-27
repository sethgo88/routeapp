import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:maplibre_gl/maplibre_gl.dart';

class _SearchResult {
  final String displayName;
  final String subline;
  final double lat;
  final double lon;

  const _SearchResult({
    required this.displayName,
    required this.subline,
    required this.lat,
    required this.lon,
  });
}

/// Full-screen fade-in search modal backed by Nominatim geocoding.
/// On result tap, dismisses and calls [onLocationSelected] with [lon, lat].
class SearchModal extends StatefulWidget {
  /// Called with [lon, lat] when the user taps a result.
  final void Function(LatLng coord) onLocationSelected;

  const SearchModal({super.key, required this.onLocationSelected});

  @override
  State<SearchModal> createState() => _SearchModalState();
}

class _SearchModalState extends State<SearchModal>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _opacity;

  final TextEditingController _searchCtrl = TextEditingController();
  List<_SearchResult> _results = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _opacity = CurvedAnimation(parent: _animCtrl, curve: Curves.easeIn);
    _animCtrl.forward();
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final q = _searchCtrl.text.trim();
    if (q.length < 2) {
      setState(() {
        _results = [];
        _error = null;
      });
      return;
    }
    _search(q);
  }

  Future<void> _search(String query) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?format=json&q=${Uri.encodeComponent(query)}&limit=10&addressdetails=1',
      );
      final response = await http.get(
        uri,
        headers: {'User-Agent': 'routeapp/1.0'},
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _results = data.map((item) {
            final parts =
                (item['display_name'] as String).split(', ');
            final name = parts.first;
            final subline = parts.skip(1).join(', ');
            return _SearchResult(
              displayName: name,
              subline: subline,
              lat: double.parse(item['lat'] as String),
              lon: double.parse(item['lon'] as String),
            );
          }).toList();
          _loading = false;
        });
      } else {
        setState(() {
          _error = 'Search failed (${response.statusCode})';
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Search unavailable';
          _loading = false;
        });
      }
    }
  }

  void _selectResult(_SearchResult result) {
    Navigator.of(context).pop();
    widget.onLocationSelected(LatLng(result.lat, result.lon));
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Padding(
          padding: const EdgeInsets.all(12),
          child: SafeArea(
            child: Column(
              children: [
                // Close button row
                Align(
                  alignment: Alignment.topRight,
                  child: Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    elevation: 2,
                    child: InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      borderRadius: BorderRadius.circular(8),
                      child: const Padding(
                        padding: EdgeInsets.all(10),
                        child: Icon(Icons.close, size: 22),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Search input
                Material(
                  borderRadius: BorderRadius.circular(10),
                  elevation: 3,
                  child: TextField(
                    controller: _searchCtrl,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Search places…',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _results = []);
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Results
                Expanded(
                  child: Material(
                    borderRadius: BorderRadius.circular(10),
                    color: Colors.white,
                    elevation: 2,
                    child: _buildResults(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResults() {
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, style: const TextStyle(color: Colors.red)),
        ),
      );
    }
    if (_searchCtrl.text.length < 2) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Type to search…',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }
    if (_results.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No results found',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: _results.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, indent: 16, endIndent: 16),
      itemBuilder: (context, i) {
        final r = _results[i];
        return ListTile(
          leading: const Icon(Icons.place_outlined, size: 20),
          title: Text(r.displayName,
              style: const TextStyle(fontWeight: FontWeight.w500)),
          subtitle: Text(
            r.subline,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12),
          ),
          onTap: () => _selectResult(r),
          dense: true,
        );
      },
    );
  }
}
