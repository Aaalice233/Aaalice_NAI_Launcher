import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// specialized controller for syntax highlighting
class SyntaxHighlightingTextEditingController extends TextEditingController {
  SyntaxHighlightingTextEditingController({super.text});

  // Compiled Regex for performance
  // Matches:
  // 1. Pipe |
  // 2. Braces {}
  // 3. Brackets []
  // 4. Any other character
  static final RegExp _tokenizer = RegExp(r'(\|)|([{}])|([\[\]])');

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    // If no style is provided, use default
    final baseStyle = style ?? const TextStyle();
    final children = <InlineSpan>[];

    // Split text using the regex
    text.splitMapJoin(
      _tokenizer,
      onMatch: (Match match) {
        final String matchText = match[0]!;
        TextStyle? spanStyle;

        if (matchText == '|') {
          spanStyle = baseStyle.copyWith(
            color: const Color(0xFFF59E0B), // Pipe Highlight
            fontWeight: FontWeight.bold,
          );
        } else if (matchText == '{' || matchText == '}') {
          spanStyle = baseStyle.copyWith(
            color: const Color(0xFF64748B), // Braces
          );
        } else if (matchText == '[' || matchText == ']') {
          spanStyle = baseStyle.copyWith(
            color: const Color(0xFF818CF8), // Brackets
          );
        }

        children.add(TextSpan(text: matchText, style: spanStyle));
        return '';
      },
      onNonMatch: (String nonMatch) {
        if (nonMatch.isNotEmpty) {
          children.add(
            TextSpan(
              text: nonMatch,
              style: baseStyle.copyWith(
                color: const Color(0xFFE2E8F0), // Normal Text
              ),
            ),
          );
        }
        return '';
      },
    );

    return TextSpan(style: baseStyle, children: children);
  }
}

class SyntaxHighlightingEditor extends StatefulWidget {
  /// Ideally should be an instance of [SyntaxHighlightingTextEditingController]
  /// for highlighting to work, but accepts standard controller for compatibility.
  final TextEditingController controller;
  final String? hintText;
  final int maxLines;
  final ValueChanged<String>? onChanged;

  const SyntaxHighlightingEditor({
    super.key,
    required this.controller,
    this.hintText,
    this.maxLines = 5,
    this.onChanged,
  });

  @override
  State<SyntaxHighlightingEditor> createState() =>
      _SyntaxHighlightingEditorState();
}

class _SyntaxHighlightingEditorState extends State<SyntaxHighlightingEditor> {
  Timer? _debounceTimer;
  bool _isSyntaxValid = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Initial check
    _validateSyntax(widget.controller.text);

    // Listen to changes for validation
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(SyntaxHighlightingEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onTextChanged);
      widget.controller.addListener(_onTextChanged);
      _validateSyntax(widget.controller.text);
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();

    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        _validateSyntax(widget.controller.text);
      }
    });
  }

  void _validateSyntax(String text) {
    final result = _checkBrackets(text);
    if (mounted) {
      setState(() {
        _isSyntaxValid = result == null;
        _errorMessage = result;
      });
    }
  }

  /// Checks for matching brackets. Returns error message or null if valid.
  String? _checkBrackets(String text) {
    final stack = <String>[];

    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      if (char == '{' || char == '[') {
        stack.add(char);
      } else if (char == '}' || char == ']') {
        if (stack.isEmpty) {
          return 'Unexpected closing bracket "$char" at position $i';
        }

        final last = stack.removeLast();
        if ((char == '}' && last != '{') || (char == ']' && last != '[')) {
          return 'Mismatched bracket "$char" at position $i. Expected closing for "$last"';
        }
      }
    }

    if (stack.isNotEmpty) {
      return 'Unclosed bracket "${stack.last}"';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A), // Background
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _isSyntaxValid
                  ? Colors.transparent
                  : Colors.red.withOpacity(0.5),
              width: 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: TextField(
              controller: widget.controller,
              maxLines: widget.maxLines,
              onChanged: widget.onChanged,
              style: GoogleFonts.robotoMono(
                fontSize: 14,
                color: const Color(0xFFE2E8F0), // Fallback/Base color
                height: 1.5,
              ),
              cursorColor: const Color(0xFF818CF8),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.all(16),
                border: InputBorder.none,
                hintText: widget.hintText,
                hintStyle: GoogleFonts.robotoMono(
                  color: const Color(0xFF64748B).withOpacity(0.5),
                ),
                filled: true,
                fillColor: const Color(0xFF0F172A),
              ),
            ),
          ),
        ),
        if (!_isSyntaxValid && _errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Text(
              _errorMessage!,
              style: const TextStyle(
                color: Colors.redAccent,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }
}
