import 'package:flutter/material.dart';

class header extends StatelessWidget {
  final Widget child;
  const header({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      body: Container(
        width: size.width,
        height: size.height,
        padding: EdgeInsets.symmetric(horizontal: size.width * 0.03),
        margin: EdgeInsets.only(
          top: size.height * 0.05,
        ),
        child: child,
      ),
    );
  }
}
