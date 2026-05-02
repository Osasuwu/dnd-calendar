import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_providers.dart';
import 'world_detail_screen.dart';
import 'world_providers.dart';

class JoinWorldScreen extends ConsumerStatefulWidget {
  const JoinWorldScreen({super.key});

  @override
  ConsumerState<JoinWorldScreen> createState() => _JoinWorldScreenState();
}

class _JoinWorldScreenState extends ConsumerState<JoinWorldScreen> {
  final _codeCtl = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _codeCtl.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final code = _codeCtl.text.trim().toUpperCase();
    if (code.length != 6) {
      setState(() => _error = 'Join code is 6 characters');
      return;
    }
    final user = ref.read(authStateChangesProvider).valueOrNull;
    if (user == null) {
      setState(() => _error = 'Not signed in');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repo = ref.read(worldRepositoryProvider);
      final worldId = await repo.resolveJoinCode(code);
      if (worldId == null) {
        setState(() => _error = 'No world matches that code');
        return;
      }
      // Idempotent — owner re-joining or already-member re-joining is fine.
      await repo.joinWorld(worldId: worldId, uid: user.uid);
      if (mounted) _replaceWith(worldId);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _replaceWith(String worldId) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => WorldDetailScreen(worldId: worldId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Join a world')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _codeCtl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Join code',
                hintText: '6 letters / digits',
                counterText: '',
              ),
              maxLength: 6,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                _UpperCaseFormatter(),
              ],
              style: const TextStyle(
                fontSize: 24,
                fontFamily: 'monospace',
                letterSpacing: 6,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _busy ? null : _join,
              icon: const Icon(Icons.login),
              label: Text(_busy ? 'Joining…' : 'Join world'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 24),
            Text(
              'Ask the DM for the world code. After joining, the world '
              'shows up in your list.',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).hintColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
