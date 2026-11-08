// lib/features/groups/group_widgets.dart
//
// Saved groups, shared by "How many people?", "Who's splitting?" and Settings:
// the long-press action sheet, the delete confirmation, the "Add saved group"
// picker and the full-screen group editor.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/person.dart';
import '../../core/services/contacts_service.dart';
import '../../core/services/settings_provider.dart';
import '../../core/utils/strings.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/apple_widgets.dart';
import '../../shared/widgets/voice_field.dart';
import '../wizard/wizard_controller.dart' show personColor;

enum GroupAction { use, edit, delete }

/// Press-and-hold menu: Use this group / Edit group / Delete group / Cancel.
Future<GroupAction?> showGroupActions(BuildContext context, S s, FriendGroup g) {
  HapticFeedback.mediumImpact();
  return showCupertinoModalPopup<GroupAction>(
    context: context,
    builder: (ctx) => CupertinoActionSheet(
      title: Text(g.name),
      message: Text(g.members.join(s.isAr ? '، ' : ', ')),
      actions: [
        CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx, GroupAction.use), child: Text(s.useThisGroup)),
        CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx, GroupAction.edit), child: Text(s.editGroup)),
        CupertinoActionSheetAction(isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, GroupAction.delete), child: Text(s.deleteGroup)),
      ],
      cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx), child: Text(s.cancel)),
    ),
  );
}

/// "Delete “Family”?" — true when confirmed.
Future<bool> confirmDeleteGroup(BuildContext context, S s, String name) async {
  final ok = await showCupertinoDialog<bool>(
    context: context,
    builder: (ctx) => CupertinoAlertDialog(
      title: Text(s.deleteGroupQ(name)),
      content: Text(s.deleteGroupNote),
      actions: [
        CupertinoDialogAction(onPressed: () => Navigator.pop(ctx, false), child: Text(s.cancel)),
        CupertinoDialogAction(isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true), child: Text(s.delete)),
      ],
    ),
  );
  return ok ?? false;
}

/// Confirms, then deletes. Returns true when the group was removed.
Future<bool> deleteGroupFlow(BuildContext context, WidgetRef ref, FriendGroup g) async {
  final s = ref.read(stringsProvider);
  if (!await confirmDeleteGroup(context, s, g.name)) return false;
  HapticFeedback.mediumImpact();
  await ref.read(groupsProvider.notifier).remove(g.name);
  return true;
}

/// Opens the editor; [group] null = new group.
Future<void> openGroupEditor(BuildContext context, [FriendGroup? group]) =>
    Navigator.of(context).push(CupertinoPageRoute(builder: (_) => GroupEditorPage(group: group)));

/// Sheet for "Add saved group": each group with its members and "+N".
Future<FriendGroup?> pickSavedGroup(BuildContext context, WidgetRef ref) {
  final s = ref.read(stringsProvider);
  final groups = ref.read(groupsProvider);
  return showAppleSheet<FriendGroup>(
    context: context,
    title: s.addSavedGroup,
    builder: (ctx) {
      final p = Palette.of(ctx);
      return Column(mainAxisSize: MainAxisSize.min, children: [
        if (groups.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(s.noGroupsYet, style: TextStyle(fontSize: 15, color: p.secondary)),
          )
        else
          Flexible(child: InsetGroup(inSheet: true, scrollable: true, separatorInset: 16, children: [
            for (final g in groups)
              Semantics(button: true, label: g.name, excludeSemantics: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () { HapticFeedback.selectionClick(); Navigator.pop(ctx, g); },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    child: Row(children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(g.name, style: TextStyle(fontSize: 17, color: p.label)),
                        Text(g.members.join(s.isAr ? '، ' : ', '), maxLines: 2, overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 13, color: p.secondary)),
                      ])),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: p.accent.withValues(alpha: p.isDark ? .22 : .12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text('+${s.n(g.members.length)}', style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700, color: p.accent)),
                      ),
                    ]),
                  ),
                )),
          ])),
        const SizedBox(height: 6),
        SecondaryButton(s.cancel, onTap: () => Navigator.pop(ctx)),
      ]);
    },
  );
}

/// "Who's here today?" — every member ticked; untick who isn't at this bill.
/// Returns the ticked names (for this bill only; the saved group is unchanged).
/// Names in [hide] (e.g. your own name) aren't listed but are kept in the result.
Future<List<String>?> pickGroupMembers(BuildContext context, WidgetRef ref, FriendGroup g,
    {Set<String> hide = const {}}) {
  final s = ref.read(stringsProvider);
  final hidden = hide.map((e) => e.trim().toLowerCase()).toSet();
  final shown = [for (final m in g.members) if (!hidden.contains(m.trim().toLowerCase())) m];
  final kept = [for (final m in g.members) if (hidden.contains(m.trim().toLowerCase())) m];
  final on = <String>{...shown};
  return showAppleSheet<List<String>>(
    context: context,
    title: s.whosHereToday,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) {
      final p = Palette.of(ctx);
      final n = on.length;
      return Column(mainAxisSize: MainAxisSize.min, children: [
        Text(s.untickHint(g.name), textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: p.secondary)),
        const SizedBox(height: 12),
        Flexible(child: InsetGroup(inSheet: true, scrollable: true, separatorInset: 58, children: [
          for (var i = 0; i < shown.length; i++)
            Semantics(button: true, selected: on.contains(shown[i]), label: shown[i], excludeSemantics: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () { HapticFeedback.selectionClick(); setSt(() => on.contains(shown[i]) ? on.remove(shown[i]) : on.add(shown[i])); },
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 150),
                  opacity: on.contains(shown[i]) ? 1 : .5,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    child: Row(children: [
                      Avatar(person: Person(id: '$i', name: shown[i], color: personColor(i)), size: 34),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(shown[i], style: TextStyle(fontSize: 17, color: p.label,
                            decoration: on.contains(shown[i]) ? null : TextDecoration.lineThrough)),
                        if (!on.contains(shown[i]))
                          Text(s.notToday, style: TextStyle(fontSize: 13, color: p.secondary)),
                      ])),
                      Icon(on.contains(shown[i]) ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.circle,
                          color: on.contains(shown[i]) ? p.green : p.tertiary, size: 26),
                    ]),
                  ),
                ),
              )),
        ])),
        const SizedBox(height: 14),
        AppleButton(label: s.addNPeople(n), onTap: n == 0 && kept.isEmpty ? null
            : () => Navigator.pop(ctx, [...kept, for (final m in shown) if (on.contains(m)) m])),
        SecondaryButton(s.cancel, onTap: () => Navigator.pop(ctx)),
      ]);
    }),
  );
}

/// Full-width grey button (kept local so this file doesn't depend on the wizard).
class SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const SecondaryButton(this.label, {super.key, required this.onTap});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: AppleButton(label: label, filled: false, onTap: () { HapticFeedback.selectionClick(); onTap(); }),
  );
}

/// Edit a group's name and members (or create a new one).
class GroupEditorPage extends ConsumerStatefulWidget {
  final FriendGroup? group;
  const GroupEditorPage({super.key, this.group});
  @override ConsumerState<GroupEditorPage> createState() => _GroupEditorPageState();
}

class _GroupEditorPageState extends ConsumerState<GroupEditorPage> {
  late final _name = TextEditingController(text: widget.group?.name ?? '');
  late final List<TextEditingController> _members = [
    for (final m in widget.group?.members ?? const ['', '']) TextEditingController(text: m),
  ];

  @override
  void dispose() {
    _name.dispose();
    for (final c in _members) { c.dispose(); }
    super.dispose();
  }

  List<String> get _clean => [for (final c in _members) if (c.text.trim().isNotEmpty) c.text.trim()];
  bool get _valid => _name.text.trim().isNotEmpty && _clean.isNotEmpty;

  Future<void> _save() async {
    if (!_valid) return;
    HapticFeedback.lightImpact();
    final n = ref.read(groupsProvider.notifier);
    final g = widget.group;
    if (g == null) {
      await n.add(_name.text.trim(), _clean);
    } else {
      await n.replace(g.name, _name.text.trim(), _clean);
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _pickContact(TextEditingController c) async {
    final name = await ContactsService.pickName();
    if (name != null && mounted) setState(() => c.text = name);
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final s = ref.watch(stringsProvider);
    final g = widget.group;

    Widget label(String t) => Padding(
      padding: const EdgeInsetsDirectional.only(start: 4, bottom: 8, top: 22),
      child: Text(t.toUpperCase(), style: TextStyle(fontSize: 13, color: p.secondary)),
    );

    return Scaffold(
      backgroundColor: p.bg,
      body: CustomScrollView(slivers: [
        CupertinoSliverNavigationBar(
          largeTitle: Text(g == null ? s.newGroup : s.editGroup, style: TextStyle(color: p.label)),
          backgroundColor: p.barBg,
          border: Border(bottom: BorderSide(color: p.separator, width: .33)),
          previousPageTitle: s.back,
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            if (g != null)
              Semantics(button: true, label: s.delete, excludeSemantics: true,
                child: CupertinoButton(
                  padding: const EdgeInsetsDirectional.only(end: 16),
                  onPressed: () async {
                    if (await deleteGroupFlow(context, ref, g) && context.mounted) Navigator.pop(context);
                  },
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(CupertinoIcons.trash, color: p.red, size: 19),
                    const SizedBox(width: 4),
                    Text(s.delete, style: TextStyle(color: p.red)),
                  ]),
                )),
            Semantics(button: true, label: s.saveBtn, excludeSemantics: true,
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _valid ? _save : null,
                child: Text(s.saveBtn, style: TextStyle(fontWeight: FontWeight.w600,
                    color: _valid ? p.accent : p.tertiary)),
              )),
          ]),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 40 + MediaQuery.of(context).padding.bottom),
          sliver: SliverList.list(children: [
            label(s.groupName),
            VoiceField(controller: _name, placeholder: s.groupNameHint, onChanged: (_) => setState(() {})),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final sug in s.groupSuggestions)
                _SoftPill(label: sug, on: _name.text == sug, onTap: () => setState(() => _name.text = sug)),
            ]),
            label('${s.members} · ${s.n(_clean.length)}'),
            for (var i = 0; i < _members.length; i++) ...[
              Row(children: [
                Avatar(
                  person: Person(id: '$i',
                      name: _members[i].text.trim().isEmpty ? s.n(i + 1) : _members[i].text.trim(),
                      color: personColor(i)),
                  size: 38,
                ),
                const SizedBox(width: 10),
                Expanded(child: VoiceField(
                  controller: _members[i],
                  placeholder: s.memberHint,
                  onChanged: (_) => setState(() {}),
                  trailing: CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    minimumSize: const Size(32, 36),
                    onPressed: () => _pickContact(_members[i]),
                    child: Icon(CupertinoIcons.person_crop_rectangle, color: p.accent, size: 22),
                  ),
                )),
                CupertinoButton(
                  padding: const EdgeInsetsDirectional.only(start: 8),
                  minimumSize: const Size(32, 36),
                  onPressed: _members.length <= 1 ? null : () {
                    HapticFeedback.selectionClick();
                    setState(() => _members.removeAt(i).dispose());
                  },
                  child: Icon(CupertinoIcons.minus_circle,
                      color: _members.length <= 1 ? p.tertiary : p.red, size: 24),
                ),
              ]),
              const SizedBox(height: 10),
            ],
            PressableScale(
              onTap: () { HapticFeedback.selectionClick(); setState(() => _members.add(TextEditingController())); },
              child: Container(
                height: 50,
                decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(12)),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(CupertinoIcons.plus_circle_fill, color: p.accent, size: 22),
                  const SizedBox(width: 8),
                  Text(s.addMember, style: TextStyle(fontSize: 17, color: p.accent, fontWeight: FontWeight.w500)),
                ]),
              ),
            ),
            const SizedBox(height: 18),
            AppleButton(label: s.saveBtn, onTap: _valid ? _save : null),
            if (g != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: AppleButton(label: s.deleteGroup, filled: false, color: p.red, onTap: () async {
                  if (await deleteGroupFlow(context, ref, g) && context.mounted) Navigator.pop(context);
                }),
              ),
          ]),
        ),
      ]),
    );
  }
}

class _SoftPill extends StatelessWidget {
  final String label;
  final bool on;
  final VoidCallback onTap;
  const _SoftPill({required this.label, required this.on, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return PressableScale(
      onTap: () { HapticFeedback.selectionClick(); onTap(); },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(color: on ? p.accent : p.surface, borderRadius: BorderRadius.circular(18)),
        child: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500,
            color: on ? Colors.white : p.label)),
      ),
    );
  }
}
