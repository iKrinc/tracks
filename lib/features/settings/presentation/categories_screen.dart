import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tracks/app/icons.dart';
import 'package:tracks/app/providers.dart';
import 'package:tracks/app/theme.dart';
import 'package:tracks/data/app_database.dart';

/// Fills offered for categories: the warm palette (dark ink on all).
const _swatches = [
  ('Sand', Palette.sand),
  ('Marigold', Palette.marigoldSoft),
  ('Butter', Palette.butter),
  ('Coral', Palette.coralSoft),
  ('Blush', Palette.blush),
  ('Clay', Palette.clay),
  ('Sage', Palette.sage),
  ('Jade', Palette.jadeSoft),
];

class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  CategoryKind _kind = CategoryKind.expense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final all =
        ref.watch(categoriesProvider(_kind)).value ?? const <Category>[];
    final tops = all.where((c) => c.parentId == null).toList();
    final db = ref.read(appDatabaseProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showCategorySheet(context, kind: _kind),
        icon: const Icon(Icons.add),
        label: const Text('Category'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: SegmentedButton<CategoryKind>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: CategoryKind.expense,
                  label: Text('Spending'),
                ),
                ButtonSegment(
                  value: CategoryKind.income,
                  label: Text('Income'),
                ),
              ],
              selected: {_kind},
              onSelectionChanged: (s) => setState(() => _kind = s.first),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Drag to reorder. Order here is the order on the Confirm Card.',
              style: theme.textTheme.bodySmall,
            ),
          ),
          Expanded(
            child: ReorderableListView(
              padding: const EdgeInsets.only(bottom: 96),
              // onReorderItem already adjusts `to` for the removed item.
              onReorderItem: (from, to) {
                final ids = [for (final c in tops) c.id];
                ids.insert(to, ids.removeAt(from));
                db.reorderCategories(ids);
              },
              children: [
                for (final top in tops)
                  _CategoryGroup(
                    key: ValueKey(top.id),
                    top: top,
                    subs: all.where((c) => c.parentId == top.id).toList(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryGroup extends StatelessWidget {
  const _CategoryGroup({super.key, required this.top, required this.subs});

  final Category top;
  final List<Category> subs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget tile(Category c, {bool sub = false}) => ListTile(
      contentPadding: EdgeInsets.only(left: sub ? 56 : 16, right: 8),
      leading: CircleAvatar(
        radius: sub ? 14 : 18,
        backgroundColor: Color(c.color),
        foregroundColor: Colors.black87,
        child: Icon(iconFor(c.icon), size: sub ? 14 : 18),
      ),
      title: Text(
        c.name,
        style: sub ? theme.textTheme.bodyMedium : theme.textTheme.titleMedium,
      ),
      trailing: sub ? null : const Icon(Icons.drag_handle),
      onTap: () => showCategorySheet(context, kind: c.kind, category: c),
    );
    return Column(
      children: [
        tile(top),
        for (final s in subs) tile(s, sub: true),
        TextButton.icon(
          onPressed: () =>
              showCategorySheet(context, kind: top.kind, parent: top),
          icon: const Icon(Icons.subdirectory_arrow_right, size: 18),
          label: Text('Add under ${top.name}'),
        ),
      ],
    );
  }
}

Future<void> showCategorySheet(
  BuildContext context, {
  required CategoryKind kind,
  Category? category,
  Category? parent,
}) => showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  useRootNavigator: true,
  showDragHandle: true,
  useSafeArea: true,
  builder: (_) =>
      _CategorySheet(kind: kind, category: category, parent: parent),
);

class _CategorySheet extends ConsumerStatefulWidget {
  const _CategorySheet({required this.kind, this.category, this.parent});

  final CategoryKind kind;
  final Category? category;
  final Category? parent;

  @override
  ConsumerState<_CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends ConsumerState<_CategorySheet> {
  late final _name = TextEditingController(text: widget.category?.name);
  late String _icon =
      widget.category?.icon ?? widget.parent?.icon ?? 'more_horiz';
  late int _color =
      widget.category?.color ?? widget.parent?.color ?? Palette.sand.toARGB32();
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save({bool archive = false}) async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Give it a name');
      return;
    }
    final c = widget.category;
    final db = ref.read(appDatabaseProvider);
    final messenger = ScaffoldMessenger.of(context);
    final companion = CategoriesCompanion(
      id: c == null ? const Value.absent() : Value(c.id),
      name: Value(name),
      kind: Value(widget.kind),
      parentId: Value(c?.parentId ?? widget.parent?.id),
      color: Value(_color),
      icon: Value(_icon),
      sortOrder: Value(c?.sortOrder ?? 999),
      archived: Value(archive),
    );
    await db.saveCategory(companion);
    if (!mounted) return;
    Navigator.pop(context);
    if (archive && c != null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '${c.name} hidden. Its past transactions keep the category.',
          ),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => db.saveCategory(
              companion.copyWith(archived: const Value(false)),
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final editing = widget.category != null;
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Color(_color),
                  foregroundColor: Colors.black87,
                  child: Icon(iconFor(_icon)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    editing
                        ? 'Edit category'
                        : widget.parent == null
                        ? 'New category'
                        : 'New in ${widget.parent!.name}',
                    style: theme.textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              autofocus: !editing,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'Name, e.g. Pets'),
            ),
            const SizedBox(height: 16),
            Text('Colour', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final (name, c) in _swatches)
                  Semantics(
                    button: true,
                    selected: c.toARGB32() == _color,
                    label: '$name colour',
                    excludeSemantics: true,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => setState(() => _color = c.toARGB32()),
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          // `outline` keeps pale swatches ≥ 3:1 on the sheet.
                          border: Border.all(
                            width: c.toARGB32() == _color ? 3 : 1,
                            color: c.toARGB32() == _color
                                ? theme.colorScheme.primary
                                : theme.colorScheme.outline,
                          ),
                        ),
                        child: c.toARGB32() == _color
                            ? const Icon(Icons.check, color: Colors.black87)
                            : null,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Icon', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final key in categoryIconKeys)
                  IconButton(
                    tooltip: key.replaceAll('_', ' '),
                    isSelected: key == _icon,
                    style: IconButton.styleFrom(
                      backgroundColor: key == _icon ? Color(_color) : null,
                      foregroundColor: key == _icon ? Colors.black87 : null,
                      side: key == _icon
                          ? BorderSide(
                              color: theme.colorScheme.primary,
                              width: 2,
                            )
                          : null,
                    ),
                    icon: Icon(iconFor(key)),
                    onPressed: () => setState(() => _icon = key),
                  ),
              ],
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check),
              label: const Text('Save'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
            ),
            if (editing)
              TextButton.icon(
                onPressed: () => _save(archive: true),
                icon: const Icon(Icons.visibility_off_outlined),
                label: const Text('Hide category'),
              ),
          ],
        ),
      ),
    );
  }
}
