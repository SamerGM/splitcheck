// lib/features/flow/people_sheet.dart
//
// "Add people" sheet: number of people, one row per person (name, pick from
// contacts, remove), "Include me", saved groups, and "Save as a group".
// Empty names become "Person 1", "Person 2"… in the chat.
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/person.dart';
import '../../core/services/contacts_service.dart';
import '../../core/services/settings_provider.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/apple_widgets.dart';

typedef PeopleSheetResult = ({List<String> names, String? groupName});

Future<PeopleSheetResult?> showPeopleSheet(BuildContext context, {List<String> initial = const []}) {
  return showAppleSheet<PeopleSheetResult>(
    context: context,
    builder: (_) => _PeopleSheet(initial: initial),
  );
}

class _PeopleSheet extends ConsumerStatefulWidget {
  final List<String> initial;
  const _PeopleSheet({required this.initial});
  @override ConsumerState<_PeopleSheet> createState() => _PeopleSheetState();
}

class _PeopleSheetState extends ConsumerState<_PeopleSheet> {
  final List<TextEditingController> _rows = [];
  final _me = TextEditingController();
  final _groupName = TextEditingController();
  bool _includeMe = false;
  bool _saveGroup = false;

  @override
  void initState() {
    super.initState();
    final myName = ref.read(myNameProvider);
    _me.text = myName;
    final initial = [...widget.initial];
    if (myName.isNotEmpty) {
      // On by default when you've set your name; on editing, on if you're in the list.
      final idx = initial.indexWhere((n) => n.toLowerCase() == myName.toLowerCase());
      _includeMe = initial.isEmpty || idx >= 0;
      if (idx >= 0) initial.removeAt(idx);
    }
    if (initial.isEmpty) initial.addAll(['', '']);
    for (final n in initial) { _rows.add(TextEditingController(text: n)); }
  }

  @override
  void dispose() {
    for (final c in _rows) { c.dispose(); }
    _me.dispose();
    _groupName.dispose();
    super.dispose();
  }

  int get _count => _rows.length + (_includeMe ? 1 : 0);

  void _setCount(int n) {
    HapticFeedback.selectionClick();
    final target = (n - (_includeMe ? 1 : 0)).clamp(0, 30);
    setState(() {
      while (_rows.length < target) { _rows.add(TextEditingController()); }
      while (_rows.length > target && _rows.length > (_includeMe ? 0 : 1)) { _rows.removeLast().dispose(); }
    });
  }

  void _useGroup(FriendGroup g) {
    HapticFeedback.selectionClick();
    final me = _me.text.trim().toLowerCase();
    setState(() {
      for (final c in _rows) { c.dispose(); }
      _rows.clear();
      _includeMe = me.isNotEmpty && g.members.any((m) => m.toLowerCase() == me);
      for (final m in g.members) {
        if (_includeMe && m.toLowerCase() == me) continue;
        _rows.add(TextEditingController(text: m));
      }
      _saveGroup = false;
    });
  }

  Future<void> _pickContact(TextEditingController c) async {
    final name = await ContactsService.pickName();
    if (name != null && mounted) setState(() => c.text = name);
  }

  void _done() {
    HapticFeedback.lightImpact();
    final me = _me.text.trim();
    if (_includeMe && me.isNotEmpty && me != ref.read(myNameProvider)) {
      ref.read(myNameProvider.notifier).set(me); // remember your name
    }
    final names = [
      if (_includeMe) me,
      for (final c in _rows) c.text.trim(),
    ];
    Navigator.pop<PeopleSheetResult>(context, (
      names: names,
      groupName: _saveGroup && _groupName.text.trim().isNotEmpty ? _groupName.text.trim() : null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final s = ref.watch(stringsProvider);
    final groups = ref.watch(groupsProvider);
    final cardColor = p.isDark ? p.elevated : p.surface;

    Widget card({required Widget child, EdgeInsets padding = const EdgeInsets.all(14)}) => Container(
      padding: padding,
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(14)),
      child: child,
    );

    Widget field(TextEditingController c, String placeholder) => CupertinoTextField(
      controller: c,
      placeholder: placeholder,
      placeholderStyle: TextStyle(fontSize: 17, color: p.tertiary),
      style: TextStyle(fontSize: 17, color: p.label),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: p.fill, borderRadius: BorderRadius.circular(10)),
      textInputAction: TextInputAction.next,
      textCapitalization: TextCapitalization.words,
    );

    final total = _count;
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.82,
      child: Column(children: [
        Text(s.peopleTitle, style: TextStyle(
          fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.4, color: p.label)),
        const SizedBox(height: 12),
        Expanded(
          child: ListView(padding: EdgeInsets.zero, children: [
            // ── Saved groups ─────────────────────────────────────────────
            if (groups.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 4, bottom: 8),
                child: Text(s.yourGroups.toUpperCase(), style: TextStyle(fontSize: 13, color: p.secondary)),
              ),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final g in groups)
                  PressableScale(
                    onTap: () => _useGroup(g),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: p.accent.withValues(alpha: p.isDark ? 0.22 : 0.12),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text('👥 ${g.name}', style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600, color: p.accent)),
                    ),
                  ),
              ]),
              const SizedBox(height: 16),
            ],

            // ── Number of people ─────────────────────────────────────────
            card(child: Row(children: [
              Expanded(child: Text(s.numberOfPeople, style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.4, color: p.label))),
              _StepBtn(icon: CupertinoIcons.minus, enabled: total > 1, onTap: () => _setCount(total - 1)),
              SizedBox(
                width: 44,
                child: Text(s.n(total), textAlign: TextAlign.center, style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w700, color: p.label)),
              ),
              _StepBtn(icon: CupertinoIcons.plus, enabled: total < 30, onTap: () => _setCount(total + 1)),
            ])),
            const SizedBox(height: 10),

            // ── Include me ───────────────────────────────────────────────
            card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(s.includeMe, style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.4, color: p.label))),
                CupertinoSwitch(
                  value: _includeMe,
                  activeTrackColor: p.green,
                  onChanged: (v) { HapticFeedback.selectionClick(); setState(() => _includeMe = v); },
                ),
              ]),
              if (_includeMe) ...[
                const SizedBox(height: 8),
                field(_me, s.yourName),
              ],
            ])),
            const SizedBox(height: 10),

            // ── One row per person ───────────────────────────────────────
            for (var i = 0; i < _rows.length; i++) ...[
              card(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(children: [
                  Avatar(
                    person: Person(
                      id: '$i',
                      name: _rows[i].text.trim().isEmpty ? s.n(i + 1 + (_includeMe ? 1 : 0)) : _rows[i].text,
                      color: kPersonColors[(i + (_includeMe ? 1 : 0)) % kPersonColors.length],
                    ),
                    size: 38,
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: field(_rows[i], s.personN(i + 1 + (_includeMe ? 1 : 0)))),
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(36, 36),
                    onPressed: () => _pickContact(_rows[i]),
                    child: Icon(CupertinoIcons.person_crop_rectangle, color: p.accent, size: 24),
                  ),
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    minimumSize: const Size(32, 36),
                    onPressed: _count <= 1 ? null : () {
                      HapticFeedback.selectionClick();
                      setState(() => _rows.removeAt(i).dispose());
                    },
                    child: Icon(CupertinoIcons.xmark_circle, color: _count <= 1 ? p.tertiary : p.red, size: 24),
                  ),
                ]),
              ),
              const SizedBox(height: 8),
            ],

            // ── Add person ───────────────────────────────────────────────
            PressableScale(
              onTap: () => _setCount(total + 1),
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: p.separator, width: 1.2),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(CupertinoIcons.plus, color: p.accent, size: 20),
                  const SizedBox(width: 6),
                  Text(s.addPerson, style: TextStyle(fontSize: 17, color: p.accent, fontWeight: FontWeight.w500)),
                ]),
              ),
            ),
            const SizedBox(height: 10),

            // ── Save as a group ──────────────────────────────────────────
            card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(CupertinoIcons.person_3_fill, color: p.accent, size: 22),
                const SizedBox(width: 10),
                Expanded(child: Text(s.saveAsGroup, style: TextStyle(fontSize: 17, color: p.label))),
                CupertinoSwitch(
                  value: _saveGroup,
                  activeTrackColor: p.green,
                  onChanged: (v) { HapticFeedback.selectionClick(); setState(() => _saveGroup = v); },
                ),
              ]),
              if (_saveGroup) ...[
                const SizedBox(height: 8),
                field(_groupName, s.groupNameHint),
              ],
            ])),
            const SizedBox(height: 12),
          ]),
        ),
        AppleButton(label: s.confirm, icon: CupertinoIcons.checkmark_alt, onTap: _done),
      ]),
    );
  }
}

class _StepBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  const _StepBtn({required this.icon, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return PressableScale(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(color: p.fill, borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, size: 18, color: enabled ? p.accent : p.tertiary),
      ),
    );
  }
}
