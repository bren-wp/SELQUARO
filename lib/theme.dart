import 'package:flutter/material.dart';

class Sq {
  static const bg = Color(0xFF04121E);
  static const surface = Color(0xFF0C2233);
  static const elevated = Color(0xFF112A3D);
  static const outline = Color(0xFF254358);
  static const cyan = Color(0xFF31DFE7);
  static const green = Color(0xFF5CE4BD);
  static const gold = Color(0xFFFFC967);
  static const red = Color(0xFFFF757C);
  static const muted = Color(0xFFABBFD0);
  static const white = Color(0xFFF4F9FC);

  static ThemeData theme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: bg,
    colorScheme: const ColorScheme.dark(
      primary: cyan, secondary: green, surface: surface,
      error: red, onSurface: white,
    ),
    fontFamily: 'Roboto',
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: outline)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cyan, width: 1.5)),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
    ),
    appBarTheme: const AppBarTheme(backgroundColor: bg, foregroundColor: white, centerTitle: false),
    cardTheme: CardThemeData(color: surface, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: outline, width: .7))),
  );
}

class SqCard extends StatelessWidget {
  const SqCard({super.key, required this.child, this.padding = const EdgeInsets.all(18), this.onTap});
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: Sq.surface,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Sq.outline, width: .7)),
    clipBehavior: Clip.antiAlias,
    child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
  );
}

class SqButton extends StatelessWidget {
  const SqButton({super.key, required this.text, required this.icon, required this.onPressed});
  final String text;
  final IconData icon;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      gradient: const LinearGradient(colors: [Color(0xFF087F92), Color(0xFF06B8C8)]),
      border: Border.all(color: Sq.cyan, width: .9),
      boxShadow: [BoxShadow(color: Sq.cyan.withValues(alpha: .13), blurRadius: 18)],
    ),
    child: Material(color: Colors.transparent, child: InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onPressed,
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 17), child: Row(children: [
        Icon(icon, color: Sq.white), const SizedBox(width: 14),
        Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17))),
        const Icon(Icons.arrow_forward_ios_rounded, size: 18),
      ])),
    )),
  );
}

class BrandHeader extends StatelessWidget {
  const BrandHeader({super.key, required this.title, required this.subtitle});
  final String title, subtitle;
  @override
  Widget build(BuildContext context) => Stack(children: [
    Positioned.fill(child: CustomPaint(painter: _MountainPainter())),
    Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        RichText(text: const TextSpan(style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600, letterSpacing: 3, color: Sq.white), children: [
          TextSpan(text: 'SEL'), TextSpan(text: 'Q', style: TextStyle(color: Sq.cyan)), TextSpan(text: 'UARO'),
        ])),
        const SizedBox(height: 3),
        Text('Purchases & Warranties', style: TextStyle(color: Sq.muted.withValues(alpha: .9), fontSize: 13)),
        const SizedBox(height: 30),
        Text(title, style: const TextStyle(fontSize: 29, fontWeight: FontWeight.w800, color: Sq.white)),
        const SizedBox(height: 8),
        Text(subtitle, style: const TextStyle(color: Sq.muted, fontSize: 14)),
      ]),
    ),
  ]);
}

class _MountainPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..shader = const LinearGradient(
      begin: Alignment.topLeft, end: Alignment.bottomRight,
      colors: [Sq.bg, Color(0xFF12374C), Sq.bg],
    ).createShader(rect));
    final far = Path()..moveTo(size.width * .25, size.height * .83)
      ..lineTo(size.width * .57, size.height * .30)
      ..lineTo(size.width * .74, size.height * .68)
      ..lineTo(size.width * .88, size.height * .43)
      ..lineTo(size.width, size.height * .72)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)..close();
    canvas.drawPath(far, Paint()..color = const Color(0xFF0B2638));
    final near = Path()..moveTo(size.width * .28, size.height)
      ..lineTo(size.width * .70, size.height * .59)
      ..lineTo(size.width * .84, size.height * .78)
      ..lineTo(size.width, size.height * .52)
      ..lineTo(size.width, size.height)..close();
    canvas.drawPath(near, Paint()..color = const Color(0xFF081926));
    canvas.drawLine(Offset(size.width * .57, size.height * .30), Offset(size.width * .64, size.height * .45),
      Paint()..color = const Color(0xFF55819A)..strokeWidth = 1.3);
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class EmptyView extends StatelessWidget {
  const EmptyView({super.key, required this.title, required this.message, required this.icon});
  final String title, message;
  final IconData icon;
  @override
  Widget build(BuildContext context) => SqCard(child: Padding(
    padding: const EdgeInsets.symmetric(vertical: 32),
    child: Column(children: [
      Icon(icon, color: Sq.cyan, size: 42),
      const SizedBox(height: 15),
      Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Sq.muted)),
    ]),
  ));
}
