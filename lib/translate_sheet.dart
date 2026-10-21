import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const Map<String, String> kLangs = {
  'id': 'Indonesia',
  'en': 'Inggris',
  'ms': 'Melayu',
  'jv': 'Jawa',
  'su': 'Sunda',
  'ar': 'Arab',
  'es': 'Spanyol',
  'fr': 'Prancis',
  'de': 'Jerman',
  'pt': 'Portugis',
  'ru': 'Rusia',
  'ja': 'Jepang',
  'ko': 'Korea',
  'zh-CN': 'Mandarin',
  'hi': 'Hindi',
  'tr': 'Turki',
  'th': 'Thai',
  'vi': 'Vietnam',
  'it': 'Italia',
  'nl': 'Belanda',
};

Future<({String text, String from})> translateText(String q, String to) async {
  final uri = Uri.https('translate.googleapis.com', '/translate_a/single', {
    'client': 'gtx',
    'sl': 'auto',
    'tl': to,
    'dt': 't',
    'q': q,
  });
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
  try {
    final req = await client.getUrl(uri);
    final res = await req.close().timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) {
      throw HttpException('HTTP ${res.statusCode}');
    }
    final body = await res.transform(utf8.decoder).join();
    final j = jsonDecode(body) as List;
    final text = (j[0] as List).map((e) => (e[0] as String?) ?? '').join();
    final from = j.length > 2 ? (j[2] as String? ?? '') : '';
    return (text: text, from: from);
  } finally {
    client.close();
  }
}

class TranslateSheet extends StatefulWidget {
  final String initial;
  final String lang;
  final ValueChanged<String> onLang;

  const TranslateSheet({
    super.key,
    required this.initial,
    required this.lang,
    required this.onLang,
  });

  @override
  State<TranslateSheet> createState() => _TranslateSheetState();
}

class _TranslateSheetState extends State<TranslateSheet> {
  late final TextEditingController _ctl;
  late String _lang;
  String _result = '';
  String _from = '';
  String _error = '';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _ctl = TextEditingController(text: widget.initial);
    _lang = widget.lang;
    if (widget.initial.trim().isNotEmpty) _run();
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final q = _ctl.text.trim();
    if (q.isEmpty) return;
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      final r = await translateText(
          q.length > 4000 ? q.substring(0, 4000) : q, _lang);
      if (!mounted) return;
      setState(() {
        _result = r.text;
        _from = r.from;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Gagal menerjemahkan. Periksa koneksi internet.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Terjemahkan', style: tt.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Blok teks pesan di WA Web, lalu buka menu ini. Atau ketik manual.',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _ctl,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Teks yang ingin diterjemahkan',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownMenu<String>(
                    initialSelection: _lang,
                    expandedInsets: EdgeInsets.zero,
                    label: const Text('Ke bahasa'),
                    dropdownMenuEntries: kLangs.entries
                        .map((e) =>
                            DropdownMenuEntry(value: e.key, label: e.value))
                        .toList(),
                    onSelected: (v) {
                      if (v == null) return;
                      setState(() => _lang = v);
                      widget.onLang(v);
                      _run();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: _busy ? null : _run,
                  child: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Terjemahkan'),
                ),
              ],
            ),
            if (_error.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(_error, style: tt.bodyMedium?.copyWith(color: cs.error)),
            ],
            if (_result.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_from.isNotEmpty)
                      Text('Dari: ${kLangs[_from] ?? _from}',
                          style: tt.labelMedium
                              ?.copyWith(color: cs.onSurfaceVariant)),
                    const SizedBox(height: 6),
                    SelectableText(_result, style: tt.bodyLarge),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _result));
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Tersalin')));
                        },
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        label: const Text('Salin'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
