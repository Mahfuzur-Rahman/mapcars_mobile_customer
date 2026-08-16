import 'package:flutter/material.dart';

import '../../../../core/widgets/mc.dart';
import '../../models/driver_info.dart';

/// The assigned driver, exactly as the API describes them.
///
/// A trip has no driver until one accepts, and the API only sends the details
/// to that trip's own two parties — so [driver] really can be null, and the
/// card says so. It used to invent "James K. · 4.9 · Silver Toyota Prius ·
/// LB12 KXR" in that gap, which a rider had no way to tell from the real thing.
///
/// Shared by the tracking and in-progress screens, which showed two separately
/// maintained copies of the same card.
class DriverCard extends StatelessWidget {
  const DriverCard({super.key, this.driver, this.actions});

  final DriverInfo? driver;

  /// Call / Message / Safety row, on the screens that have one.
  final Widget? actions;

  @override
  Widget build(BuildContext context) {
    final driver = this.driver;

    return McCard(
      padding: 14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (driver == null)
            Row(
              children: [
                const McAvatar(size: 52, color: Brand.fillDeep),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Assigning your driver',
                          style: tw(FontWeight.w900, 16)),
                      Text("You'll see their car and plate here",
                          style: tw(FontWeight.w600, 12.5, Brand.sub)),
                    ],
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                const McAvatar(size: 52, color: Brand.blue),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(driver.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: tw(FontWeight.w900, 16)),
                          ),
                          // A rating of 0 means "no ratings yet", not a
                          // zero-star driver — leave it off entirely.
                          if (driver.rating > 0) ...[
                            const SizedBox(width: 6),
                            const Ico('starF', size: 14, color: Brand.star),
                            const SizedBox(width: 3),
                            Text(driver.rating.toStringAsFixed(1),
                                style: tw(FontWeight.w800, 13)),
                          ],
                        ],
                      ),
                      if (driver.vehicle.isNotEmpty)
                        Text(driver.vehicle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: tw(FontWeight.w600, 12.5, Brand.sub)),
                    ],
                  ),
                ),
                if (driver.plate.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                        color: Brand.fill,
                        borderRadius: BorderRadius.circular(7)),
                    child: Text(driver.plate,
                        style: tw(FontWeight.w900, 14, Brand.ink, 0.5)),
                  ),
                ],
              ],
            ),
          if (actions != null) ...[
            const SizedBox(height: 14),
            actions!,
          ],
        ],
      ),
    );
  }
}
