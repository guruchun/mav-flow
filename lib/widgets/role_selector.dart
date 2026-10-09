import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/mavlink_state.dart';
import '../theme/app_theme.dart';

/// Role Selector Widget
class RoleSelector extends StatefulWidget {
  const RoleSelector({super.key});

  @override
  State<RoleSelector> createState() => _RoleSelectorState();
}

class _RoleSelectorState extends State<RoleSelector> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    
    return Consumer<MavlinkState>(
      builder: (context, state, child) {
        final roleConfigs = state.roleConfigs;
        final roleOrder = state.availableRoleIds;

        if (roleConfigs.isEmpty) {
          return const Text('No roles');
        }

        final selectedValue =
            state.isRoleSelected ? state.currentRoleId : null;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Role: ', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Focus(
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
                child: DropdownButton<String>(
                  value: selectedValue,
                  hint: Text(
                    'Select Role',
                    style: TextStyle(color: theme.secondaryTextColor),
                  ),
                  dropdownColor: isDark ? AppTheme.darkDropdownColor : null,
                  focusColor: Colors.transparent,
                  items: roleOrder.map((roleId) {
                    final config = roleConfigs[roleId];
                    if (config == null) return null;
                    return DropdownMenuItem<String>(
                      value: roleId,
                      child: Text(config.name),
                    );
                  }).whereType<DropdownMenuItem<String>>().toList(),
                  onChanged: (roleId) {
                    if (roleId != null) {
                      state.setRole(roleId);
                    }
                  },
                  underline: const SizedBox.shrink(),
                  icon: Icon(
                    Icons.arrow_drop_down,
                    color: isDark ? Colors.grey[400] : null,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Compact Role Selector Widget
class RoleSelectorCompact extends StatelessWidget {
  const RoleSelectorCompact({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Consumer<MavlinkState>(
      builder: (context, state, child) {
        final roleConfigs = state.roleConfigs;
        final roleOrder = state.availableRoleIds;

        if (roleConfigs.isEmpty) {
          return const Text('-');
        }

        final selectedValue =
            state.isRoleSelected ? state.currentRoleId : null;

        return DropdownButton<String>(
          value: selectedValue,
          hint: const Text('-'),
          isDense: true,
          dropdownColor: isDark ? AppTheme.darkDropdownColor : null,
          items: roleOrder.map((roleId) {
            final config = roleConfigs[roleId];
            if (config == null) return null;
            return DropdownMenuItem<String>(
              value: roleId,
              child: Text(config.name),
            );
          }).whereType<DropdownMenuItem<String>>().toList(),
          onChanged: (roleId) {
            if (roleId != null) {
              state.setRole(roleId);
            }
          },
        );
      },
    );
  }
}
