import 'package:flutter/material.dart';
import '../../../core/utils/localization_extension.dart';

class DlssPassCountField extends StatefulWidget {
  const DlssPassCountField({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final int value;
  final ValueChanged<int>? onChanged;
  @override
  State<DlssPassCountField> createState() => _DlssPassCountFieldState();
}

class _DlssPassCountFieldState extends State<DlssPassCountField> {
  late final _text = TextEditingController(text: '${widget.value}');
  final _focus = FocusNode();
  bool _invalid = false;
  @override
  void initState() {
    super.initState();
    _focus.addListener(_blur);
  }

  void _blur() {
    if (!_focus.hasFocus) _commit();
  }

  void _commit() {
    if (!mounted || widget.onChanged == null) return;
    final parsed = int.tryParse(_text.text.trim());
    setState(() => _invalid = parsed == null || parsed < 1);
    if (!_invalid && parsed != widget.value) widget.onChanged!(parsed!);
  }

  @override
  void didUpdateWidget(covariant DlssPassCountField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _text.text = '${widget.value}';
      _invalid = false;
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_blur);
    _focus.dispose();
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TextField(
        key: const Key('dlss-passes'),
        controller: _text,
        focusNode: _focus,
        enabled: widget.onChanged != null,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: context.l10n.dlss_passes,
          errorText: _invalid ? context.l10n.dlss_invalidPasses : null,
          errorMaxLines: 3,
        ),
        onSubmitted: (_) => _commit(),
        onTapOutside: (_) => _focus.unfocus(),
      ),
      const SizedBox(height: 6),
      Text(
        context.l10n.dlss_passesHint,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ],
  );
}
