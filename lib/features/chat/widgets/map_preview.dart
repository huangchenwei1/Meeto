import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../models/date_order.dart';

/// Stylized route preview (origin -> venue) used inside order event cards.
///
/// Demo stand-in for a real map SDK; swap the painter for a static map tile
/// or an embedded map view in production.
class MapPreview extends StatelessWidget {
  const MapPreview({super.key, required this.order});

  final DateOrder order;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        height: 120,
        width: double.infinity,
        child: CustomPaint(
          painter: _MapPainter(),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  AppStrings.mapCaption(order.distanceLabel, order.etaMinutes),
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textHint,
                  ),
                ),
                const Spacer(),
                Row(
                  children: <Widget>[
                    Text(
                      AppStrings.meLabel,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      order.place,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint background = Paint()..color = const Color(0xFFF0F4F1);
    canvas.drawRect(Offset.zero & size, background);

    // Street grid.
    final Paint street = Paint()
      ..color = const Color(0xFFE2E9E3)
      ..strokeWidth = 8;
    canvas.drawLine(
      Offset(0, size.height * 0.35),
      Offset(size.width, size.height * 0.35),
      street,
    );
    canvas.drawLine(
      Offset(0, size.height * 0.75),
      Offset(size.width, size.height * 0.75),
      street,
    );
    canvas.drawLine(
      Offset(size.width * 0.25, 0),
      Offset(size.width * 0.25, size.height),
      street,
    );
    canvas.drawLine(
      Offset(size.width * 0.62, 0),
      Offset(size.width * 0.62, size.height),
      street,
    );

    // Dashed route from origin to destination.
    final Path route = Path()
      ..moveTo(size.width * 0.1, size.height * 0.78)
      ..cubicTo(
        size.width * 0.35,
        size.height * 0.66,
        size.width * 0.55,
        size.height * 0.4,
        size.width * 0.88,
        size.height * 0.3,
      );
    final Paint routePaint = Paint()
      ..color = AppColors.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    _drawDashedPath(canvas, route, routePaint, dash: 6, gap: 5);

    // Origin dot.
    canvas.drawCircle(
      Offset(size.width * 0.1, size.height * 0.78),
      6,
      Paint()..color = AppColors.accent,
    );
    canvas.drawCircle(
      Offset(size.width * 0.1, size.height * 0.78),
      6,
      Paint()
        ..color = AppColors.background
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    // Destination pin.
    final Offset pin = Offset(size.width * 0.88, size.height * 0.3);
    canvas.drawCircle(pin, 7, Paint()..color = AppColors.textPrimary);
    canvas.drawCircle(pin, 2.8, Paint()..color = AppColors.background);
  }

  void _drawDashedPath(
    Canvas canvas,
    Path path,
    Paint paint, {
    required double dash,
    required double gap,
  }) {
    for (final PathMetric metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final double end = (distance + dash).clamp(0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance = end + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
