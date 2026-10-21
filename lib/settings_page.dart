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

class SettingsPage extends StatelessWidget {
  final AppSettings settings;
  final Future<void> Function() onClearCache;
  final Future<void> Function() onClearData;

  const SettingsPage({
    super.key,
    required this.settings,
    required this.onClearCache,
    required this.onClearData,
  });

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
            ListTile(
              title: const Text('Ukuran teks'),
              subtitle: Slider(
                min: 70,
                max: 160,
                divisions: 9,
                label: '${settings.zoom}%',
                value: settings.zoom.toDouble(),
                onChanged: (v) => settings.setZoom(v.round()),
              ),
              trailing: Text('${settings.zoom}%'),
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
              leading: const Icon(Icons.folder_open_rounded),
              title: const Text('Folder unduhan'),
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
