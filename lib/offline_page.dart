import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

Future<bool> hasInternet() async {
  try {
    final r = await InternetAddress.lookup('web.whatsapp.com')
        .timeout(const Duration(seconds: 4));
    return r.isNotEmpty && r.first.rawAddress.isNotEmpty;
  } catch (_) {
    return false;
  }
}

class OfflinePage extends StatefulWidget {
  final Future<void> Function() onRetry;
  const OfflinePage({super.key, required this.onRetry});

  @override
  State<OfflinePage> createState() => _OfflinePageState();
}

class _OfflinePageState extends State<OfflinePage> {
  bool _busy = false;

  Future<void> _retry() async {
    setState(() => _busy = true);
    await widget.onRetry();
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: ColoredBox(
        color: cs.surface,
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.cloud_off_rounded,
                        size: 44, color: cs.primary),
                  ),
                  const SizedBox(height: 24),
                  Text('404',
                      style: tt.displayLarge?.copyWith(
                          fontWeight: FontWeight.w700, color: cs.primary)),
                  const SizedBox(height: 4),
                  Text('Halaman tidak dapat diakses',
                      textAlign: TextAlign.center, style: tt.titleLarge),
                  const SizedBox(height: 8),
                  Text(
                    'Kamu sedang offline. Periksa koneksi internet lalu coba lagi.',
                    textAlign: TextAlign.center,
                    style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 28),
                  FilledButton.icon(
                    onPressed: _busy ? null : _retry,
                    icon: _busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.refresh_rounded),
                    label: const Text('Coba lagi'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
