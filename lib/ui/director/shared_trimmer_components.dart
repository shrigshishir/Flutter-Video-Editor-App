import 'package:flutter/material.dart';

/// Shared trimmer handle widget with unified styling
class TrimmerHandle extends StatelessWidget {
  final bool isActive;
  final double height;

  const TrimmerHandle({Key? key, required this.isActive, required this.height})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    Color handleColor = isActive ? Colors.deepOrange : Colors.orange;

    return Container(
      height: height,
      width: 16,
      decoration: BoxDecoration(
        color: handleColor,
        borderRadius: BorderRadius.circular(2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 4,
            offset: Offset(1, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Three grip lines (unified design)
          Container(
            width: 8,
            height: 2,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          SizedBox(height: 2),
          Container(
            width: 8,
            height: 2,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          SizedBox(height: 2),
          Container(
            width: 8,
            height: 2,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shared overlay border widget
class TrimmerOverlayBorder extends StatelessWidget {
  final double width;
  final double height;
  final Widget child;

  const TrimmerOverlayBorder({
    Key? key,
    required this.width,
    required this.height,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.orange.withOpacity(0.8), width: 2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(2),
        ),
        child: child,
      ),
    );
  }
}
