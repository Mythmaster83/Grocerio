import 'dart:async';
import 'package:flutter/material.dart';

/// Search field that reports its value only after typing pauses.
///
/// The debounce exists because each query re-runs a catalog scan plus a price
/// lookup per result; firing that per keystroke makes the list flicker through
/// half-typed matches on the way to the real one.
class PriceSearchBar extends StatefulWidget {
  final ValueChanged<String> onChanged;
  final String hintText;
  final Duration debounce;

  const PriceSearchBar({
    super.key,
    required this.onChanged,
    this.hintText = 'Search products',
    this.debounce = const Duration(milliseconds: 300),
  });

  @override
  State<PriceSearchBar> createState() => _PriceSearchBarState();
}

class _PriceSearchBarState extends State<PriceSearchBar> {
  final _controller = TextEditingController();
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _timer?.cancel();
    _timer = Timer(widget.debounce, () => widget.onChanged(value));
    setState(() {}); // toggles the clear button
  }

  void _clear() {
    _timer?.cancel();
    _controller.clear();
    widget.onChanged('');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: _onChanged,
      textInputAction: TextInputAction.search,
      // Submitting should not wait out the debounce.
      onSubmitted: (value) {
        _timer?.cancel();
        widget.onChanged(value);
      },
      decoration: InputDecoration(
        hintText: widget.hintText,
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _controller.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close),
                onPressed: _clear,
                tooltip: 'Clear',
              ),
      ),
    );
  }
}
