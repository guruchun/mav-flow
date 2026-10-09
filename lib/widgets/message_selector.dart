import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Message Selector Widget
class MessageSelector extends StatefulWidget {
  /// Message list
  final List<String> messages;

  /// Currently selected message
  final String? selectedMessage;

  /// Message change callback
  final ValueChanged<String?> onChanged;

  /// Show "All" option
  final bool showAllOption;

  /// Hint text
  final String hint;

  const MessageSelector({
    super.key,
    required this.messages,
    required this.selectedMessage,
    required this.onChanged,
    this.showAllOption = true,
    this.hint = 'Select message',
  });

  @override
  State<MessageSelector> createState() => _MessageSelectorState();
}

class _MessageSelectorState extends State<MessageSelector> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    final items = <DropdownMenuItem<String?>>[];

    if (widget.showAllOption) {
      items.add(const DropdownMenuItem<String?>(
        value: null,
        child: Text('All'),
      ));
    }

    for (final message in widget.messages) {
      items.add(DropdownMenuItem<String?>(
        value: message,
        child: Text(message),
      ));
    }

    // Wrap with container for better visibility in dark theme
    return Focus(
      onFocusChange: (focused) => setState(() => _isFocused = focused),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkDropdownFill : Colors.white,
          border: Border.all(
            color: _isFocused
                ? (isDark ? AppTheme.darkDropdownFocusedBorder : Colors.blue)
                : (isDark ? AppTheme.darkDropdownBorder : Colors.grey[400]!),
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: DropdownButton<String?>(
          value: widget.selectedMessage,
          hint: Text(widget.hint, style: TextStyle(color: theme.secondaryTextColor)),
          items: items,
          onChanged: widget.onChanged,
          isExpanded: true,
          dropdownColor: isDark ? AppTheme.darkDropdownColor : null,
          focusColor: Colors.transparent,
          underline: const SizedBox.shrink(),
          icon: Icon(
            Icons.arrow_drop_down,
            color: isDark ? Colors.grey[400] : null,
          ),
        ),
      ),
    );
  }
}

/// Message Filter Chips Widget
class MessageFilterChips extends StatelessWidget {
  /// Message list
  final List<String> messages;

  /// Currently selected message
  final String? selectedMessage;

  /// Message change callback
  final ValueChanged<String?> onChanged;

  const MessageFilterChips({
    super.key,
    required this.messages,
    required this.selectedMessage,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        ChoiceChip(
          label: const Text('All'),
          selected: selectedMessage == null,
          onSelected: (selected) {
            if (selected) onChanged(null);
          },
        ),
        ...messages.map((message) {
          return ChoiceChip(
            label: Text(message),
            selected: selectedMessage == message,
            onSelected: (selected) {
              if (selected) onChanged(message);
            },
          );
        }),
      ],
    );
  }
}
