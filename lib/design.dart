import 'dart:math' as math;
import 'package:flutter/material.dart';

abstract final class NoonColors {
  static const background = Color(0xff121313);
  static const surface = Color(0xff1b1c1c);
  static const raised = Color(0xff252626);
  static const field = Color(0xff303131);
  static const line = Color(0xff3b3c3b);
  static const text = Color(0xfff1f0e9);
  static const muted = Color(0xffb3b5ad);
  static const amber = Color(0xffe9c587);
  static const selected = Color(0xff393329);
  static const mint = Color(0xffb7c9b5);
  static const lavender = Color(0xffc4b9df);
  static const blue = Color(0xffaac3cf);
  static const tracks = [
    amber,
    lavender,
    mint,
    blue,
    Color(0xffdbaaa0),
    Color(0xffb9b8e3),
    Color(0xffd1c9a0),
    Color(0xffa7ccc6),
  ];
}

ThemeData noonTheme() => ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  fontFamily: 'Lato',
  scaffoldBackgroundColor: NoonColors.background,
  colorScheme: const ColorScheme.dark(
    primary: NoonColors.amber,
    onPrimary: Color(0xff332917),
    secondary: NoonColors.mint,
    surface: NoonColors.surface,
    onSurface: NoonColors.text,
    onSurfaceVariant: NoonColors.muted,
    outline: NoonColors.line,
    error: Color(0xffffb4ab),
  ),
  dividerColor: NoonColors.line,
  iconButtonTheme: IconButtonThemeData(
    style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: NoonColors.background,
    surfaceTintColor: Colors.transparent,
  ),
  tooltipTheme: const TooltipThemeData(
    waitDuration: Duration(milliseconds: 350),
  ),
  sliderTheme: const SliderThemeData(
    trackHeight: 3,
    thumbShape: RoundSliderThumbShape(enabledThumbRadius: 7),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: NoonColors.raised,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: NoonColors.amber),
    ),
    contentPadding: const EdgeInsets.all(14),
  ),
  navigationBarTheme: const NavigationBarThemeData(
    backgroundColor: NoonColors.surface,
    indicatorColor: NoonColors.selected,
    labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
  ),
  bottomSheetTheme: const BottomSheetThemeData(
    backgroundColor: NoonColors.surface,
    showDragHandle: true,
    surfaceTintColor: Colors.transparent,
  ),
);

class NoonMark extends StatelessWidget {
  final double size;
  const NoonMark({super.key, this.size = 32});
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Noon',
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _MarkPainter()),
    ),
  );
}

class _MarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 32, size.height / 32);
    final pen = Paint()
      ..color = NoonColors.amber
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawArc(
      const Rect.fromLTWH(6, 7, 20, 20),
      math.pi,
      math.pi,
      false,
      pen,
    );
    canvas.drawLine(const Offset(4, 20), const Offset(28, 20), pen);
    for (var i = 0; i < 5; i++) {
      final h = [2.0, 5.0, 8.0, 5.0, 2.0][i];
      canvas.drawLine(
        Offset(8 + i * 4, 24),
        Offset(8 + i * 4, 24 + h / 2),
        pen..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(_MarkPainter oldDelegate) => false;
}

class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.color,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: color ?? NoonColors.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: NoonColors.line.withValues(alpha: .65)),
    ),
    child: child,
  );
}

class Parameter extends StatefulWidget {
  final String label, unit;
  final double value, min, max;
  final int? divisions;
  final ValueChanged<double>? onChanged;
  const Parameter({
    super.key,
    required this.label,
    required this.value,
    this.min = 0,
    this.max = 1,
    this.unit = '%',
    this.divisions,
    this.onChanged,
  });
  @override
  State<Parameter> createState() => _ParameterState();
}

class _ParameterState extends State<Parameter> {
  late double value = widget.value;
  @override
  void didUpdateWidget(Parameter oldWidget) {
    super.didUpdateWidget(oldWidget);
    value = widget.value;
  }

  @override
  Widget build(BuildContext context) {
    final shown = widget.unit == '%'
        ? '${(value * 100).round()}%'
        : widget.unit == 'ms'
        ? '${(value * 1000).round()} ms'
        : widget.unit == 'Hz'
        ? '${value.round()} Hz'
        : '${value.round()}${widget.unit}';
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(widget.label, style: const TextStyle(fontSize: 13)),
              ),
              Text(
                shown,
                style: const TextStyle(
                  fontSize: 12,
                  color: NoonColors.muted,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          Slider(
            value: value.clamp(widget.min, widget.max),
            min: widget.min,
            max: widget.max,
            divisions: widget.divisions,
            semanticFormatterCallback: (_) => '${widget.label}, $shown',
            onChanged: widget.onChanged == null
                ? null
                : (v) => setState(() => value = v),
            onChangeEnd: widget.onChanged,
          ),
        ],
      ),
    );
  }
}
