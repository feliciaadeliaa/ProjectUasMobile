import 'package:flutter/material.dart';

class SafeContext {
  final BuildContext _context;
  bool _mounted = true;

  SafeContext(this._context);

  BuildContext? get context => _mounted ? _context : null;
  bool get mounted => _mounted;

  void dispose() {
    _mounted = false;
  }

  void showSnackBar(String message, Color backgroundColor) {
    if (!_mounted) return;
    
    try {
      ScaffoldMessenger.of(_context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: backgroundColor,
        ),
      );
    } catch (e) {
      // Silently ignore if context is not available
      debugPrint('Could not show snackbar: $e');
    }
  }

  void hideCurrentSnackBar() {
    if (!_mounted) return;
    
    try {
      ScaffoldMessenger.of(_context).hideCurrentSnackBar();
    } catch (e) {
      debugPrint('Could not hide snackbar: $e');
    }
  }
}
