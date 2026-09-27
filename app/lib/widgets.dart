import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'models.dart';
import 'theme.dart';

/// The Kindred mark: two strokes meeting in a heart, with a spark above the gap.
class MarkPainter extends CustomPainter {
  final Color? color;
  final double progress; // 0..1 for the splash "draw" animation
  final double dot; // 0..1 spark scale
  MarkPainter({this.color, this.progress = 1, this.dot = 1});

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100;
    final left = Path()
      ..moveTo(43 * s, 27.5 * s)
      ..cubicTo(36 * s, 20.5 * s, 24.5 * s, 21.5 * s, 18 * s, 32 * s)
      ..cubicTo(10 * s, 46 * s, 20 * s, 64 * s, 50 * s, 84 * s);
    final right = Path()
      ..moveTo(57 * s, 27.5 * s)
      ..cubicTo(64 * s, 20.5 * s, 75.5 * s, 21.5 * s, 82 * s, 32 * s)
      ..cubicTo(90 * s, 46 * s, 80 * s, 64 * s, 50 * s, 84 * s);
    final rect = Offset.zero & size;
    Paint stroke(double opacity) {
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8 * s
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      if (color != null) {
        p.color = color!.withValues(alpha: opacity);
      } else {
        p.shader = LinearGradient(colors: [K.g1.withValues(alpha: opacity), K.g2.withValues(alpha: opacity)], begin: Alignment.topLeft, end: Alignment.bottomRight).createShader(rect);
      }
      return p;
    }

    void drawPartial(Path path, Paint paint) {
      for (final m in path.computeMetrics()) {
        canvas.drawPath(m.extractPath(0, m.length * progress), paint);
      }
    }

    drawPartial(left, stroke(1));
    drawPartial(right, stroke(.82));
    if (dot > 0) canvas.drawCircle(Offset(50 * s, 16 * s), 5 * s * dot, Paint()..color = color ?? K.g1);
  }

  @override
  bool shouldRepaint(MarkPainter old) => old.progress != progress || old.dot != dot || old.color != color;
}

class KMark extends StatelessWidget {
  final double size;
  final Color? color;
  const KMark({super.key, this.size = 40, this.color});
  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.square(size), painter: MarkPainter(color: color));
}

class Wordmark extends StatelessWidget {
  final double size;
  const Wordmark({super.key, this.size = 26});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        KMark(size: size * 1.3),
        const SizedBox(width: 6),
        Text('kindred', style: serif(size, color: Pal.of(context).text)),
      ]);
}

/// Silver metallic shimmer painted over whatever shapes are inside it.
class Silver extends StatefulWidget {
  final Widget child;
  const Silver({super.key, required this.child});
  @override
  State<Silver> createState() => _SilverState();
}

class _SilverState extends State<Silver> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) => ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (rect) => LinearGradient(
          colors: [p.sk1, p.sk1, p.sk2, p.sk3, p.sk2, p.sk1, p.sk1],
          stops: const [0, .3, .42, .5, .58, .7, 1],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          transform: _Slide(_c.value),
        ).createShader(rect),
        child: child,
      ),
    );
  }
}

class _Slide extends GradientTransform {
  final double t;
  const _Slide(this.t);
  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) => Matrix4.translationValues(bounds.width * (t * 2 - 1), 0, 0);
}

/// A plain shape for use inside [Silver].
class Bone extends StatelessWidget {
  final double? width, height;
  final double radius;
  const Bone({super.key, this.width, this.height = 14, this.radius = 10});
  @override
  Widget build(BuildContext context) =>
      Container(width: width, height: height, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(radius)));
}

/// Gradient art with the first initial, used when someone has no photo.
class ArtFill extends StatelessWidget {
  final String id, name;
  final double fontSize;
  final bool decorated;
  const ArtFill({super.key, required this.id, required this.name, this.fontSize = 110, this.decorated = true});
  @override
  Widget build(BuildContext context) {
    final c = K.paletteFor(id);
    return Container(
      decoration: BoxDecoration(gradient: LinearGradient(colors: c, begin: Alignment.topLeft, end: Alignment.bottomRight)),
      child: LayoutBuilder(builder: (context, box) {
        return Stack(fit: StackFit.expand, children: [
          if (decorated) ...[
            Positioned(top: -box.maxWidth * .12, right: -box.maxWidth * .18, child: _circle(box.maxWidth * .7, Colors.white.withValues(alpha: .16))),
            Positioned(bottom: -box.maxWidth * .1, left: -box.maxWidth * .15, child: _circle(box.maxWidth * .55, Colors.black.withValues(alpha: .08))),
          ],
          Center(child: Text(name.isEmpty ? '?' : name[0].toUpperCase(), style: serif(fontSize, color: Colors.white.withValues(alpha: .95)))),
        ]);
      }),
    );
  }

  Widget _circle(double d, Color c) => Container(width: d, height: d, decoration: BoxDecoration(shape: BoxShape.circle, color: c));
}

/// Network photo with silver loading shimmer and disk caching.
class NetPhoto extends StatelessWidget {
  final String url;
  final BoxFit fit;
  const NetPhoto(this.url, {super.key, this.fit = BoxFit.cover});
  @override
  Widget build(BuildContext context) => CachedNetworkImage(
        imageUrl: url,
        fit: fit,
        fadeInDuration: const Duration(milliseconds: 300),
        placeholder: (_, _) => const Silver(child: SizedBox.expand(child: ColoredBox(color: Colors.white))),
        errorWidget: (_, _, _) => ColoredBox(color: Pal.of(context).surface2, child: const Icon(Icons.broken_image_outlined)),
      );
}

class Avatar extends StatelessWidget {
  final Profile p;
  final double size;
  final double border;
  final Color? borderColor;
  const Avatar(this.p, {super.key, this.size = 56, this.border = 0, this.borderColor});
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, border: border > 0 ? Border.all(color: borderColor ?? Colors.white, width: border) : null),
        child: ClipOval(
          child: p.photos.isNotEmpty ? NetPhoto(p.photos.first) : ArtFill(id: p.id, name: p.name, fontSize: size * .42, decorated: false),
        ),
      );
}

class GradButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final IconData? icon;
  final double height;
  const GradButton(this.label, {super.key, this.onPressed, this.busy = false, this.icon, this.height = 56});
  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    return Opacity(
      opacity: enabled || busy ? 1 : .6,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          gradient: K.grad,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [BoxShadow(color: K.brand.withValues(alpha: .35), blurRadius: 20, offset: const Offset(0, 8), spreadRadius: -8)],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: enabled ? onPressed : null,
            child: Center(
              child: busy
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : Row(mainAxisSize: MainAxisSize.min, children: [
                      if (icon != null) ...[Icon(icon, color: Colors.white, size: 20), const SizedBox(width: 8)],
                      Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                    ]),
            ),
          ),
        ),
      ),
    );
  }
}

class GhostButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool filled;
  final Color? color;
  final bool busy;
  const GhostButton(this.label, {super.key, this.onPressed, this.icon, this.filled = false, this.color, this.busy = false});
  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return SizedBox(
      height: 54,
      width: double.infinity,
      child: OutlinedButton(
        onPressed: busy ? null : onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: filled ? p.surface2 : Colors.transparent,
          foregroundColor: color ?? p.text,
          side: BorderSide(color: filled ? Colors.transparent : p.line, width: 1.5),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        child: busy
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5))
            : Row(mainAxisSize: MainAxisSize.min, children: [
                if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
                Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
              ]),
      ),
    );
  }
}

class PickChip extends StatelessWidget {
  final String label;
  final bool on;
  final VoidCallback onTap;
  const PickChip(this.label, {super.key, required this.on, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: on ? K.brand.withValues(alpha: .1) : p.surface2,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: on ? K.brand : Colors.transparent, width: 1.5),
        ),
        child: Text(label, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: on ? K.brand : p.text)),
      ),
    );
  }
}

class InfoChip extends StatelessWidget {
  final String label;
  final bool glass;
  const InfoChip(this.label, {super.key, this.glass = false});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(color: glass ? Colors.white.withValues(alpha: .2) : Pal.of(context).surface2, borderRadius: BorderRadius.circular(999)),
        child: Text(label, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: glass ? Colors.white : Pal.of(context).text)),
      );
}

/// Segmented choice like the web app's pill control.
class Segmented extends StatelessWidget {
  final List<(String, String)> options;
  final String? value;
  final ValueChanged<String> onChanged;
  const Segmented({super.key, required this.options, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(color: p.surface2, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          for (final o in options)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(o.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: value == o.$1 ? p.surface : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: value == o.$1 ? [BoxShadow(color: Colors.black.withValues(alpha: .08), blurRadius: 8, offset: const Offset(0, 2))] : null,
                  ),
                  child: Text(o.$2, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700, color: value == o.$1 ? p.text : p.muted, fontSize: 14)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class FieldLabel extends StatelessWidget {
  final String text;
  final String? trailing;
  const FieldLabel(this.text, {super.key, this.trailing});
  @override
  Widget build(BuildContext context) {
    final st = TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Pal.of(context).muted, letterSpacing: .2);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
      child: Row(children: [Expanded(child: Text(text, style: st)), if (trailing != null) Text(trailing!, style: st)]),
    );
  }
}

void toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 3)));
}

String fmtWhen(DateTime? d) {
  if (d == null) return '';
  final now = DateTime.now();
  final days = DateTime(now.year, now.month, now.day).difference(DateTime(d.year, d.month, d.day)).inDays;
  if (days == 0) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    return '$h:${d.minute.toString().padLeft(2, '0')} ${d.hour < 12 ? 'am' : 'pm'}';
  }
  if (days == 1) return 'Yesterday';
  const wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  if (days < 7) return wd[d.weekday - 1];
  const mo = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day} ${mo[d.month - 1]}';
}

String fmtDay(DateTime d) {
  final now = DateTime.now();
  final days = DateTime(now.year, now.month, now.day).difference(DateTime(d.year, d.month, d.day)).inDays;
  if (days == 0) return 'Today';
  if (days == 1) return 'Yesterday';
  const wd = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  const mo = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
  return '${wd[d.weekday - 1]}, ${d.day} ${mo[d.month - 1]}';
}

String seenText(DateTime? d) {
  if (d == null) return '';
  final m = DateTime.now().difference(d).inMinutes;
  if (m < 15) return 'Active now';
  if (m < 180) return 'Active recently';
  if (m < 1440) return 'Active today';
  return 'Active ${fmtWhen(d).toLowerCase()}';
}
