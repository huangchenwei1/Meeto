import 'dart:async';

import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../../core/env/app_env.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';

/// One suggestion from the server's place-search proxy.
class PlaceSuggestion {
  const PlaceSuggestion({required this.name, required this.address});

  factory PlaceSuggestion.fromJson(Map<String, dynamic> json) {
    return PlaceSuggestion(
      name: json['name'] as String? ?? '',
      address: json['address'] as String? ?? '',
    );
  }

  final String name;
  final String address;
}

/// A place input with search-as-you-type suggestions from the server's
/// place proxy (POI data; Amap-backed for the China market). The field
/// stays free-text — suggestions are an accelerator, not a constraint —
/// and quietly degrades to a plain input in mock mode or when the
/// provider is not configured.
class PlaceSearchField extends StatefulWidget {
  const PlaceSearchField({
    super.key,
    required this.controller,
    required this.fieldKey,
    required this.hintText,
    this.maxLength,
  });

  final TextEditingController controller;

  /// Key applied to the inner [TextField] so existing widget tests keep
  /// addressing the same node.
  final Key fieldKey;
  final String hintText;
  final int? maxLength;

  @override
  State<PlaceSearchField> createState() => _PlaceSearchFieldState();
}

class _PlaceSearchFieldState extends State<PlaceSearchField> {
  static const Duration _debounce = Duration(milliseconds: 350);
  static const int _minQueryLength = 2;
  static const int _maxShown = 5;

  Timer? _debounceTimer;
  int _requestSeq = 0;
  List<PlaceSuggestion> _suggestions = <PlaceSuggestion>[];

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onChanged(String text) {
    if (!AppEnv.useRemoteApi) {
      return;
    }
    _debounceTimer?.cancel();
    final String query = text.trim();
    if (query.length < _minQueryLength) {
      if (_suggestions.isNotEmpty) {
        setState(() => _suggestions = <PlaceSuggestion>[]);
      }
      return;
    }
    _debounceTimer = Timer(_debounce, () => _search(query));
  }

  Future<void> _search(String query) async {
    final int seq = ++_requestSeq;
    final List<PlaceSuggestion> results;
    try {
      final ApiClient client = ApiClient(baseUrl: AppEnv.apiBaseUrl);
      final dynamic body = await client.get(
        '/places/search',
        query: <String, String>{'q': query},
      );
      results = (body as List<dynamic>)
          .map((dynamic e) => PlaceSuggestion.fromJson(e as Map<String, dynamic>))
          .where((PlaceSuggestion s) => s.name.isNotEmpty)
          .take(_maxShown)
          .toList(growable: false);
    } on Exception {
      // Suggestions are best-effort; typing stays the source of truth.
      return;
    }
    // Drop stale responses: only the latest query may render.
    if (!mounted || seq != _requestSeq) {
      return;
    }
    setState(() => _suggestions = results);
  }

  void _pick(PlaceSuggestion suggestion) {
    widget.controller.text = suggestion.name;
    widget.controller.selection = TextSelection.collapsed(
      offset: suggestion.name.length,
    );
    setState(() => _suggestions = <PlaceSuggestion>[]);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        TextField(
          key: widget.fieldKey,
          controller: widget.controller,
          maxLength: widget.maxLength,
          onChanged: _onChanged,
          decoration: InputDecoration(
            hintText: widget.hintText,
            prefixIcon: const Icon(Iconsax.location, size: 18),
          ),
        ),
        if (_suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: <Widget>[
                for (int i = 0; i < _suggestions.length; i++) ...<Widget>[
                  if (i > 0)
                    const Divider(height: 1, color: AppColors.divider),
                  InkWell(
                    key: ValueKey<String>('placeSuggestion$i'),
                    onTap: () => _pick(_suggestions[i]),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: Row(
                        children: <Widget>[
                          const Icon(
                            Iconsax.location5,
                            size: 14,
                            color: AppColors.textHint,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  _suggestions[i].name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                if (_suggestions[i].address.isNotEmpty)
                                  Text(
                                    _suggestions[i].address,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      color: AppColors.textHint,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}
