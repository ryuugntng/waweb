import 'package:flutter/material.dart';

import 'app_settings.dart';
import 'file_saver.dart';
import 'translate_sheet.dart';

Future<void> showAbout(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  return showDialog(
    context: context,
    builder: (_) => AlertDialog(
      icon: Icon(Icons.chat_rounded, color: cs.primary, size: 36),
      title: const Text('waweb'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Versi: BETA'),
          const Text('Author: aether'),
          const SizedBox(height: 12),
          Text(
            'Aplikasi tidak resmi dan tidak berafiliasi dengan WhatsApp. '
            'Semua pesan diproses langsung oleh WhatsApp Web.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup')),
      ],
    ),
  );
}

class SettingsPage extends StatefulWidget {
  final AppSettings settings;
  final Future<void> Function() onClearCache;
  final Future<void> Function() onClearData;

  const SettingsPage({
    super.key,
    required this.settings,
    required this.onClearCache,
    required this.onClearData,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  AppSettings get settings => widget.settings;
  Future<void> Function() get onClearCache => widget.onClearCache;
  Future<void> Function() get onClearData => widget.onClearData;
  String _folder = '…';

  @override
  void initState() {
    super.initState();
    _loadFolder();
  }

  Future<void> _loadFolder() async {
    final f = await FileSaver.folderLabel();
    if (mounted) setState(() => _folder = f);
  }

  Future<void> _pickFolder() async {
    final f = await FileSaver.pickFolder();
    if (f != null && mounted) setState(() => _folder = f);
  }

  Future<void> _resetFolder() async {
    await FileSaver.resetFolder();
    await _loadFolder();
  }

  Widget _header(BuildContext c, String t) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
        child: Text(t,
            style: Theme.of(c)
                .textTheme
                .labelLarge
                ?.copyWith(color: Theme.of(c).colorScheme.primary)),
      );

  Future<void> _pickLang(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('Bahasa tujuan'),
        children: kLangs.entries
            .map((e) => SimpleDialogOption(
                  onPressed: () {
                    settings.setLang(e.key);
                    Navigator.pop(context);
                  },
                  child: Text(e.value),
                ))
            .toList(),
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus data aplikasi?'),
        content: const Text(
            'Kamu akan keluar dari WhatsApp Web dan harus scan QR lagi.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Hapus')),
        ],
      ),
    );
    if (ok == true) {
      await onClearData();
      if (context.mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: ListenableBuilder(
        listenable: settings,
        builder: (context, _) => ListView(
          children: [
            _header(context, 'Tampilan'),
            SwitchListTile(
              title: const Text('Pil di sisi kanan'),
              subtitle: const Text('Matikan untuk memindahkan ke kiri'),
              value: settings.pillRight,
              onChanged: settings.setPillRight,
            ),
            SwitchListTile(
              title: const Text('Layar penuh'),
              subtitle: const Text('Sembunyikan status bar dan navigasi'),
              value: settings.fullscreen,
              onChanged: settings.setFullscreen,
            ),
            SwitchListTile(
              title: const Text('Getaran halus'),
              subtitle: const Text('Saat menyentuh pil'),
              value: settings.haptic,
              onChanged: settings.setHaptic,
            ),
            SwitchListTile(
              title: const Text('Kunci zoom'),
              subtitle: const Text('Matikan agar bisa cubit zoom in / out'),
              value: settings.zoomLock,
              onChanged: settings.setZoomLock,
            ),
            ListTile(
              title: const Text('Zoom web'),
              subtitle: Slider(
                min: 0,
                max: (kZoomSteps.length - 1).toDouble(),
                divisions: kZoomSteps.length - 1,
                label: '${settings.zoom}%',
                value: kZoomSteps
                    .indexOf(kZoomSteps.reduce((x, y) =>
                        (x - settings.zoom).abs() <= (y - settings.zoom).abs()
                            ? x
                            : y))
                    .toDouble(),
                onChanged: (v) => settings.setZoom(kZoomSteps[v.round()]),
              ),
              trailing: TextButton(
                onPressed: () => settings.setZoom(100),
                child: Text('${settings.zoom}% · Reset'),
              ),
            ),
            _header(context, 'Terjemahan'),
            ListTile(
              leading: const Icon(Icons.translate_rounded),
              title: const Text('Bahasa tujuan'),
              subtitle: Text(kLangs[settings.lang] ?? settings.lang),
              onTap: () => _pickLang(context),
            ),
            _header(context, 'Data'),
            ListTile(
              leading: const Icon(Icons.folder_rounded),
              title: const Text('Folder simpan'),
              subtitle: Text(_folder),
              onTap: _pickFolder,
              trailing: IconButton(
                tooltip: 'Kembali ke default',
                icon: const Icon(Icons.restart_alt_rounded),
                onPressed: _resetFolder,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.folder_open_rounded),
              title: const Text('Buka folder unduhan'),
              onTap: FileSaver.openDownloads,
            ),
            ListTile(
              leading: const Icon(Icons.cleaning_services_rounded),
              title: const Text('Hapus cache'),
              onTap: () async {
                await onClearCache();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Cache dihapus')));
                }
              },
            ),
            ListTile(
              leading: Icon(Icons.logout_rounded,
                  color: Theme.of(context).colorScheme.error),
              title: const Text('Hapus data dan keluar akun'),
              onTap: () => _confirmClear(context),
            ),
            _header(context, 'Info'),
            ListTile(
              leading: const Icon(Icons.info_outline_rounded),
              title: const Text('Tentang waweb'),
              subtitle: const Text('BETA · aether'),
              onTap: () => showAbout(context),
            ),
          ],
        ),
      ),
    );
  }
}
