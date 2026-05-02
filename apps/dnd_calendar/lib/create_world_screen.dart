import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_providers.dart';
import 'world_providers.dart';

class CreateWorldScreen extends ConsumerStatefulWidget {
  const CreateWorldScreen({super.key});

  @override
  ConsumerState<CreateWorldScreen> createState() => _CreateWorldScreenState();
}

class _CreateWorldScreenState extends ConsumerState<CreateWorldScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtl = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _nameCtl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final user = ref.read(authStateChangesProvider).valueOrNull;
    if (user == null) {
      setState(() => _error = 'Not signed in.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(worldRepositoryProvider)
          .createWorld(uid: user.uid, name: _nameCtl.text);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New world')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameCtl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'World name',
                  hintText: 'e.g. The Sword Coast',
                ),
                textCapitalization: TextCapitalization.words,
                validator: (v) {
                  final t = v?.trim() ?? '';
                  if (t.isEmpty) return 'Required';
                  if (t.length > 60) return 'Too long (max 60)';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              const Text(
                'Seeded with a default Earth-like calendar (7-day week, '
                '12 months × 30 days, one moon). You can customise it later.',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _busy ? null : _submit,
                icon: const Icon(Icons.add),
                label: Text(_busy ? 'Creating…' : 'Create world'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
