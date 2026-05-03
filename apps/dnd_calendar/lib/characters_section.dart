import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_providers.dart';
import 'character_providers.dart';
import 'models/character.dart';

class CharactersSection extends ConsumerWidget {
  const CharactersSection({super.key, required this.worldId});

  final String worldId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(authStateChangesProvider).valueOrNull;
    final charsAsync = ref.watch(charactersProvider(worldId));

    return Scaffold(
      body: charsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (chars) {
          if (chars.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No characters yet. Tap + to add yours.',
                  style: TextStyle(fontSize: 14),
                ),
              ),
            );
          }
          // Group: yours first, then everyone else's.
          final mine = <Character>[];
          final others = <Character>[];
          for (final c in chars) {
            (c.uid == me?.uid ? mine : others).add(c);
          }
          return ListView(
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              if (mine.isNotEmpty) ...[
                const _Header('Yours'),
                for (final c in mine)
                  _CharacterTile(character: c, mine: true),
              ],
              if (others.isNotEmpty) ...[
                const _Header('Others'),
                for (final c in others)
                  _CharacterTile(character: c, mine: false),
              ],
            ],
          );
        },
      ),
      floatingActionButton: me == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _openEdit(context),
              icon: const Icon(Icons.add),
              label: const Text('New character'),
            ),
    );
  }

  void _openEdit(BuildContext context, [Character? existing]) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            CharacterEditScreen(worldId: worldId, existing: existing),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          letterSpacing: 1,
          color: Theme.of(context).hintColor,
        ),
      ),
    );
  }
}

class _CharacterTile extends ConsumerWidget {
  const _CharacterTile({required this.character, required this.mine});

  final Character character;
  final bool mine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subtitle = [
      if (character.characterClass.isNotEmpty) character.characterClass,
      'Level ${character.level}',
      if (!mine && character.ownerDisplayName.isNotEmpty)
        'by ${character.ownerDisplayName}',
    ].join(' · ');

    return ListTile(
      leading: const Icon(Icons.person),
      title: Text(character.name),
      subtitle: Text(subtitle),
      trailing: mine
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CharacterEditScreen(
                        worldId: character.worldId,
                        existing: character,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _confirmDelete(context, ref),
                ),
              ],
            )
          : null,
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete ${character.name}?'),
        content: const Text('Existing registrations stay; new sign-ups are blocked.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref
        .read(characterRepositoryProvider)
        .deleteCharacter(character.worldId, character.id);
  }
}

// ─── Edit screen ────────────────────────────────────────────────────────────

class CharacterEditScreen extends ConsumerStatefulWidget {
  const CharacterEditScreen({
    super.key,
    required this.worldId,
    this.existing,
  });

  final String worldId;
  final Character? existing;

  @override
  ConsumerState<CharacterEditScreen> createState() =>
      _CharacterEditScreenState();
}

class _CharacterEditScreenState extends ConsumerState<CharacterEditScreen> {
  final _nameCtl = TextEditingController();
  final _classCtl = TextEditingController();
  final _levelCtl = TextEditingController(text: '1');
  bool _busy = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final c = widget.existing;
    if (c != null) {
      _nameCtl.text = c.name;
      _classCtl.text = c.characterClass;
      _levelCtl.text = c.level.toString();
    }
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _classCtl.dispose();
    _levelCtl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Name is required');
      return;
    }
    final level = int.tryParse(_levelCtl.text.trim());
    if (level == null || level < 1) {
      setState(() => _error = 'Level must be a positive number');
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
      final repo = ref.read(characterRepositoryProvider);
      final character = (widget.existing ??
              Character(
                id: '',
                worldId: widget.worldId,
                uid: user.uid,
                ownerDisplayName: user.displayName ?? user.email ?? '',
                name: name,
              ))
          .copyWith(
        name: name,
        characterClass: _classCtl.text.trim(),
        level: level,
        ownerDisplayName: user.displayName ?? user.email ?? '',
      );
      if (_isEdit) {
        await repo.updateCharacter(character);
      } else {
        await repo.createCharacter(character);
      }
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
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit character' : 'New character'),
        actions: [
          if (_busy)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _save,
              child: const Text('Save'),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          TextField(
            controller: _nameCtl,
            decoration: const InputDecoration(labelText: 'Name'),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _classCtl,
            decoration: const InputDecoration(
              labelText: 'Class',
              hintText: 'e.g. Wizard, Rogue, Fighter',
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _levelCtl,
            decoration: const InputDecoration(labelText: 'Level'),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
        ],
      ),
    );
  }
}
