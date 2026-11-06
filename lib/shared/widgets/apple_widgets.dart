// lib/shared/widgets/apple_widgets.dart
//
// Small set of Apple-style building blocks shared across screens.
import 'package:flutter/material.dart';

import '../../core/models/person.dart';
import '../theme/app_theme.dart';

/// Shrinks slightly while pressed — the iOS "button press" feel.
class PressableScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  const PressableScale({super.key, required this.child, this.onTap, this.scale = 0.95});
  @override State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _down = false;
  void _set(bool v) { if (widget.onTap != null && _down != v) setState(() => _down = v); }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          opacity: _down ? 0.75 : 1,
          duration: const Duration(milliseconds: 120),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Large rounded iOS button. `filled: false` gives the gray "secondary" style.
class AppleButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool filled;
  final Color? color;
  const AppleButton({super.key, required this.label, this.icon, this.onTap, this.filled = true, this.color});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final c = color ?? p.accent;
    final enabled = onTap != null;
    final fg = filled ? Colors.white : c;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: enabled ? 1 : 0.4,
      child: PressableScale(
        onTap: onTap,
        scale: 0.97,
        child: Container(
          height: 50,
          width: double.infinity,
          decoration: BoxDecoration(
            color: filled ? c : p.fill,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (icon != null) ...[Icon(icon, size: 18, color: fg), const SizedBox(width: 6)],
            Text(label, style: TextStyle(
              fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.4, color: fg)),
          ]),
        ),
      ),
    );
  }
}

/// Round gray icon button (e.g. camera next to the message field).
class CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  const CircleIconButton({super.key, required this.icon, required this.onTap, this.size = 36});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return PressableScale(
      onTap: onTap,
      child: Container(
        width: size, height: size,
        decoration: BoxDecoration(color: p.fill, shape: BoxShape.circle),
        child: Icon(icon, size: size * 0.52, color: p.secondary),
      ),
    );
  }
}

/// iOS "inset grouped" list section: rounded card with hairline separators.
class InsetGroup extends StatelessWidget {
  final List<Widget> children;
  final String? header;
  final bool scrollable;
  /// Set inside bottom sheets so cells stand out from the sheet in dark mode.
  final bool inSheet;
  final double separatorInset;
  const InsetGroup({super.key, required this.children, this.header, this.scrollable = false,
      this.inSheet = false, this.separatorInset = 60});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      rows.add(children[i]);
      if (i < children.length - 1) {
        rows.add(Padding(
          padding: EdgeInsetsDirectional.only(start: separatorInset),
          child: Container(height: 0.5, color: p.separator),
        ));
      }
    }
    final card = ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        color: inSheet && p.isDark ? p.elevated : p.surface,
        child: scrollable
            ? SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: rows))
            : Column(mainAxisSize: MainAxisSize.min, children: rows),
      ),
    );
    if (header == null) return card;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Padding(
        padding: const EdgeInsetsDirectional.only(start: 16, bottom: 6),
        child: Text(header!.toUpperCase(), style: TextStyle(
          fontSize: 13, letterSpacing: -0.08, color: p.secondary)),
      ),
      Flexible(child: card),
    ]);
  }
}

/// Coloured circle with the person's initial — like Contacts.
class Avatar extends StatelessWidget {
  final Person person;
  final double size;
  const Avatar({super.key, required this.person, this.size = 32});

  @override
  Widget build(BuildContext context) {
    final c = person.color;
    final initial = person.name.isEmpty ? '?' : person.name.characters.first.toUpperCase();
    return Container(
      width: size, height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Color.lerp(c, Colors.white, 0.18)!, c],
        ),
      ),
      child: Text(initial, style: TextStyle(
        fontSize: size * 0.44, fontWeight: FontWeight.w600, color: Colors.white)),
    );
  }
}

/// The app mark — the launcher icon itself, so the two always match.
class AppGlyph extends StatelessWidget {
  final double size;
  const AppGlyph({super.key, this.size = 28});

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.2237), // iOS icon corner ratio
        child: Image.asset(
          'assets/icon/icon.png',
          width: size, height: size,
          filterQuality: FilterQuality.medium,
        ),
      );
}

/// iOS-style bottom sheet: grabber, title, rounded top corners, grouped bg.
Future<T?> showAppleSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  String? title,
  bool isDismissible = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    isDismissible: isDismissible,
    enableDrag: isDismissible,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (ctx) {
      final p = Palette.of(ctx);
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: BoxDecoration(
            color: p.isDark ? p.surface : p.bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
          ),
          padding: EdgeInsets.fromLTRB(16, 6, 16, 16 + MediaQuery.of(ctx).padding.bottom),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 36, height: 5,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(color: p.tertiary, borderRadius: BorderRadius.circular(3)),
            ),
            if (title != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Text(title, style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.4, color: p.label)),
              ),
            Flexible(child: builder(ctx)),
          ]),
        ),
      );
    },
  );
}
