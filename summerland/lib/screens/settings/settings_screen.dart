import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';

import '../../services/pinned_modules_service.dart';
import '../../services/shop_profile_service.dart';
import '../../services/theme_service.dart';
import '../../ui/app_shell.dart';
import '../../ui/app_widgets.dart';
import '../../ui/home_modules.dart';
import '../../ui/shop_logo.dart';

/// App-wide preferences and information.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final PinnedModulesService _pinnedService = PinnedModulesService();

  int _pinnedCount = 0;
  int _maxPinned = PinnedModulesService.defaultMaxPinned;
  bool _loading = true;
  ThemeMode _themeMode = ThemeService.instance.mode.value;

  @override
  void initState() {
    super.initState();
    _loadPinned();
  }

  int get _moduleCount => homeModules.length;

  Future<void> _setThemeMode(ThemeMode value) async {
    setState(() {
      _themeMode = value;
    });

    await ThemeService.instance.setMode(value);
  }

  Future<void> _loadPinned() async {
    final pinned = await _pinnedService.load();
    final maxPinned = await _pinnedService.loadMaxPinned();

    if (!mounted) return;

    setState(() {
      _pinnedCount = pinned.length;
      _maxPinned = maxPinned > _moduleCount ? _moduleCount : maxPinned;
      _loading = false;
    });
  }

  Future<void> _resetPins() async {
    await _pinnedService.save(const <String>[]);

    if (!mounted) return;

    setState(() {
      _pinnedCount = 0;
    });

    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Home shortcuts cleared.')));
  }

  Future<void> _editShopName() async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _ShopNameDialog(
        initial: ShopProfileService.instance.profile.value.name,
      ),
    );

    if (result == null || !mounted) return;

    await ShopProfileService.instance.setName(result);

    if (!mounted) return;

    setState(() {});

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Shop name set to '
          '"${ShopProfileService.instance.profile.value.name}".',
        ),
      ),
    );
  }

  Future<void> _chooseLogo() async {
    try {
      final XFile? file = await openFile(
        acceptedTypeGroups: <XTypeGroup>[
          const XTypeGroup(
            label: 'Images',
            extensions: <String>['png', 'jpg', 'jpeg', 'webp', 'heic', 'heif'],
            mimeTypes: <String>[
              'image/png',
              'image/jpeg',
              'image/webp',
              'image/heic',
              'image/heif',
            ],
          ),
        ],
        confirmButtonText: 'Select',
      );

      if (file == null) return;

      final bytes = await file.readAsBytes();

      if (!mounted) return;

      await ShopProfileService.instance.setLogo(bytes);

      if (!mounted) return;

      setState(() {});

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Logo updated.')));
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load that image: $error')),
      );
    }
  }

  Future<void> _removeLogo() async {
    await ShopProfileService.instance.setLogo(null);

    if (!mounted) return;

    setState(() {});

    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Logo removed.')));
  }

  Future<void> _editMaxPinned() async {
    final value = await showDialog<int>(
      context: context,
      builder: (_) => _MaxPinnedDialog(initial: _maxPinned, max: _moduleCount),
    );

    if (value == null || !mounted) return;

    await _pinnedService.saveMaxPinned(value);

    if (!mounted) return;

    setState(() {
      _maxPinned = value;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('You can now pin up to $value modules.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Settings',
      destinationId: 'settings',
      body: _loading
          ? const LoadingState()
          : WideContent(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const SectionHeader(
                    title: 'Shop',
                    subtitle: 'Name and logo shown around the app',
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: ShopLogo(size: 48, radius: 10),
                          title: Text(
                            ShopProfileService.instance.profile.value.name,
                          ),
                          subtitle: const Text('Shop name'),
                          trailing: TextButton(
                            onPressed: _editShopName,
                            child: const Text('Rename'),
                          ),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.image_outlined),
                          title: const Text('Logo'),
                          subtitle: Text(
                            ShopProfileService.instance.profile.value.hasLogo
                                ? 'Custom logo'
                                : 'Using the default icon',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (ShopProfileService
                                  .instance
                                  .profile
                                  .value
                                  .hasLogo)
                                TextButton(
                                  onPressed: _removeLogo,
                                  child: const Text('Remove'),
                                ),
                              TextButton(
                                onPressed: _chooseLogo,
                                child: const Text('Choose'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const SectionHeader(
                    title: 'Appearance',
                    subtitle: 'Choose how the app looks',
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: SegmentedButton<ThemeMode>(
                        segments: const [
                          ButtonSegment(
                            value: ThemeMode.light,
                            label: Text('Light'),
                            icon: Icon(Icons.light_mode_outlined),
                          ),
                          ButtonSegment(
                            value: ThemeMode.dark,
                            label: Text('Dark'),
                            icon: Icon(Icons.dark_mode_outlined),
                          ),
                          ButtonSegment(
                            value: ThemeMode.system,
                            label: Text('System'),
                            icon: Icon(Icons.brightness_auto_outlined),
                          ),
                        ],
                        selected: {_themeMode},
                        onSelectionChanged: (selection) =>
                            _setThemeMode(selection.first),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const SectionHeader(
                    title: 'Home',
                    subtitle: 'Your pinned shortcuts',
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.push_pin_outlined),
                          title: const Text('Pinned modules'),
                          subtitle: Text(
                            _pinnedCount == 0
                                ? 'No modules pinned'
                                : '$_pinnedCount of $_maxPinned pinned',
                          ),
                          trailing: TextButton(
                            onPressed: _pinnedCount == 0 ? null : _resetPins,
                            child: const Text('Reset'),
                          ),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.star_outline_rounded),
                          title: const Text('Maximum pinned modules'),
                          subtitle: Text(
                            'Currently $_maxPinned of $_moduleCount',
                          ),
                          trailing: TextButton(
                            onPressed: _editMaxPinned,
                            child: const Text('Edit'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const SectionHeader(
                    title: 'About',
                    subtitle: 'Application information',
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: ShopLogo(size: 48, radius: 10),
                          title: Text(
                            ShopProfileService.instance.profile.value.name,
                          ),
                          subtitle: const Text('Inventory & POS'),
                        ),
                        const Divider(height: 1),
                        const ListTile(
                          leading: Icon(Icons.info_outline),
                          title: Text('Version'),
                          subtitle: Text('1.0.0'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

/// Prompts for the shop's display name.
class _ShopNameDialog extends StatefulWidget {
  const _ShopNameDialog({required this.initial});

  final String initial;

  @override
  State<_ShopNameDialog> createState() => _ShopNameDialogState();
}

class _ShopNameDialogState extends State<_ShopNameDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_controller.text);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Shop name'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textInputAction: TextInputAction.done,
        decoration: const InputDecoration(
          labelText: 'Name',
          hintText: 'e.g. Summerland',
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}

/// Prompts for the maximum number of modules that may be pinned on Home.
class _MaxPinnedDialog extends StatefulWidget {
  const _MaxPinnedDialog({required this.initial, required this.max});

  final int initial;

  /// Hard ceiling - there are only this many modules to pin.
  final int max;

  @override
  State<_MaxPinnedDialog> createState() => _MaxPinnedDialogState();
}

class _MaxPinnedDialogState extends State<_MaxPinnedDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: '${widget.initial}',
  );
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = int.tryParse(_controller.text.trim());

    if (value == null || value < PinnedModulesService.minPinned) {
      setState(() {
        _error =
            'Enter a whole number, '
            '${PinnedModulesService.minPinned} or more.';
      });
      return;
    }

    if (value > widget.max) {
      setState(() {
        _error = 'Home has only ${widget.max} modules.';
      });
      return;
    }

    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Maximum pinned modules'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
          labelText: 'Maximum',
          helperText:
              'Between ${PinnedModulesService.minPinned} and ${widget.max}',
          errorText: _error,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}
