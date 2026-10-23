import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';

import '../../localization/app_strings.dart';
import '../../services/cache_store.dart';
import '../../services/language_service.dart';
import '../../services/pinned_modules_service.dart';
import '../../services/prefetch_service.dart';
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
  AppLanguage _language = LanguageService.instance.language.value;

  @override
  void initState() {
    super.initState();
    _loadPinned();
  }

  int get _moduleCount => homeModules.length;

  String _cacheSizeLabel() {
    try {
      return CacheStore.instance.formattedSize;
    } catch (_) {
      return '0 B';
    }
  }

  Future<void> _clearCache() async {
    final confirm = await showAppConfirmDialog(
      context,
      title: context.tr('Clear cache'),
      message: context.tr(
        'This will remove all cached data. You will need an internet '
        'connection to reload data. Do you want to continue?',
      ),
      confirmLabel: context.tr('Clear'),
    );

    if (confirm != true) return;

    try {
      await CacheStore.instance.clearAll();
    } catch (_) {
      // Ignore cache clear errors.
    }

    if (!mounted) return;

    setState(() {});

    try {
      await PrefetchService.instance.forceWarmUp();
    } catch (_) {}

    if (!mounted) return;
    setState(() {});

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(context.tr('Cache cleared.'))));
  }

  Future<void> _setThemeMode(ThemeMode value) async {
    setState(() {
      _themeMode = value;
    });

    await ThemeService.instance.setMode(value);
  }

  Future<void> _setLanguage(AppLanguage value) async {
    setState(() {
      _language = value;
    });

    await LanguageService.instance.setLanguage(value);
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

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.tr('Home shortcuts cleared.'))),
    );
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
          context.tr('Shop name set to "{0}".', [
            ShopProfileService.instance.profile.value.name,
          ]),
        ),
      ),
    );
  }

  Future<void> _chooseLogo() async {
    try {
      final XFile? file = await openFile(
        acceptedTypeGroups: <XTypeGroup>[
          XTypeGroup(
            label: context.tr('Images'),
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
        confirmButtonText: context.tr('Select'),
      );

      if (file == null) return;

      final bytes = await file.readAsBytes();

      if (!mounted) return;

      await ShopProfileService.instance.setLogo(bytes);

      if (!mounted) return;

      setState(() {});

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.tr('Logo updated.'))));
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('Could not load that image: {0}', [error])),
        ),
      );
    }
  }

  Future<void> _removeLogo() async {
    await ShopProfileService.instance.setLogo(null);

    if (!mounted) return;

    setState(() {});

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(context.tr('Logo removed.'))));
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
      SnackBar(
        content: Text(
          context.tr('You can now pin up to {0} modules.', [value]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: context.tr('Settings'),
      destinationId: 'settings',
      body: _loading
          ? const LoadingState()
          : WideContent(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  SectionHeader(
                    title: context.tr('Shop'),
                    subtitle: context.tr('Name and logo shown around the app'),
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
                          subtitle: Text(context.tr('Shop name')),
                          trailing: TextButton(
                            onPressed: _editShopName,
                            child: Text(context.tr('Rename')),
                          ),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.image_outlined),
                          title: Text(context.tr('Logo')),
                          subtitle: Text(
                            ShopProfileService.instance.profile.value.hasLogo
                                ? context.tr('Custom logo')
                                : context.tr('Using the default icon'),
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
                                  child: Text(context.tr('Remove')),
                                ),
                              TextButton(
                                onPressed: _chooseLogo,
                                child: Text(context.tr('Choose')),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SectionHeader(
                    title: context.tr('Appearance'),
                    subtitle: context.tr('Choose how the app looks'),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: SegmentedButton<ThemeMode>(
                            segments: [
                              ButtonSegment(
                                value: ThemeMode.light,
                                label: Text(context.tr('Light')),
                                icon: const Icon(Icons.light_mode_outlined),
                              ),
                              ButtonSegment(
                                value: ThemeMode.dark,
                                label: Text(context.tr('Dark')),
                                icon: const Icon(Icons.dark_mode_outlined),
                              ),
                              ButtonSegment(
                                value: ThemeMode.system,
                                label: Text(context.tr('System')),
                                icon: const Icon(
                                  Icons.brightness_auto_outlined,
                                ),
                              ),
                            ],
                            selected: {_themeMode},
                            onSelectionChanged: (selection) =>
                                _setThemeMode(selection.first),
                          ),
                        ),
                        const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: SegmentedButton<AppLanguage>(
                            segments: [
                              for (final language in LanguageService.languages)
                                ButtonSegment(
                                  value: language,
                                  label: Text(language.nativeName),
                                  icon: const Icon(Icons.language_outlined),
                                ),
                            ],
                            selected: {_language},
                            onSelectionChanged: (selection) =>
                                _setLanguage(selection.first),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SectionHeader(
                    title: context.tr('Home'),
                    subtitle: context.tr('Your pinned shortcuts'),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.push_pin_outlined),
                          title: Text(context.tr('Pinned modules')),
                          subtitle: Text(
                            _pinnedCount == 0
                                ? context.tr('No modules pinned')
                                : context.tr('{0} of {1} pinned', [
                                    _pinnedCount,
                                    _maxPinned,
                                  ]),
                          ),
                          trailing: TextButton(
                            onPressed: _pinnedCount == 0 ? null : _resetPins,
                            child: Text(context.tr('Reset')),
                          ),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.star_outline_rounded),
                          title: Text(context.tr('Maximum pinned modules')),
                          subtitle: Text(
                            context.tr('Currently {0} of {1}', [
                              _maxPinned,
                              _moduleCount,
                            ]),
                          ),
                          trailing: TextButton(
                            onPressed: _editMaxPinned,
                            child: Text(context.tr('Edit')),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SectionHeader(
                    title: context.tr('Offline Data'),
                    subtitle: context.tr('Cached data for offline browsing'),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.cached_outlined),
                          title: Text(context.tr('Cache size')),
                          subtitle: Text(_cacheSizeLabel()),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.delete_outline),
                          title: Text(context.tr('Clear cache')),
                          subtitle: Text(context.tr('Remove all cached data')),
                          onTap: _clearCache,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SectionHeader(
                    title: context.tr('About'),
                    subtitle: context.tr('Application information'),
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
                          subtitle: Text(context.tr('Inventory & POS')),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.info_outline),
                          title: Text(context.tr('Version')),
                          subtitle: Text(context.tr('1.0.0')),
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
      title: Text(context.tr('Shop name')),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
          labelText: context.tr('Name'),
          hintText: context.tr('e.g. Summerland'),
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.tr('Cancel')),
        ),
        FilledButton(onPressed: _submit, child: Text(context.tr('Save'))),
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
        _error = context.tr('Enter a whole number, {0} or more.', [
          PinnedModulesService.minPinned,
        ]);
      });
      return;
    }

    if (value > widget.max) {
      setState(() {
        _error = context.tr('Home has only {0} modules.', [widget.max]);
      });
      return;
    }

    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.tr('Maximum pinned modules')),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
          labelText: context.tr('Maximum'),
          helperText: context.tr('Between {0} and {1}', [
            PinnedModulesService.minPinned,
            widget.max,
          ]),
          errorText: _error,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.tr('Cancel')),
        ),
        FilledButton(onPressed: _submit, child: Text(context.tr('Save'))),
      ],
    );
  }
}
