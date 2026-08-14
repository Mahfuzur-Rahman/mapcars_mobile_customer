import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/date_format.dart';
import '../../../core/widgets/mc.dart';
import '../../ride/models/trip.dart';
import '../../ride/models/trip_status.dart';
import '../../ride/services/ride_service.dart';

/// The rider's real trip history (`GET /trips` via [tripHistoryProvider]).
/// Tapping a completed trip opens its receipt.
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trips = ref.watch(tripHistoryProvider);

    return Scaffold(
      backgroundColor: Brand.bg,
      bottomNavigationBar: const _CustomerTabBar(active: 'activity'),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: McNavHeader(title: 'Your trips', fallback: '/home'),
            ),
            Expanded(
              child: trips.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => _Message(
                  icon: 'alert',
                  title: "Couldn't load your trips",
                  sub: 'Pull to refresh or try again in a moment.',
                  onRetry: () => ref.invalidate(tripHistoryProvider),
                ),
                data: (list) {
                  if (list.isEmpty) {
                    return const _Message(
                      icon: 'car',
                      title: 'No trips yet',
                      sub: 'Your completed rides will show up here.',
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () async => ref.invalidate(tripHistoryProvider),
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, i) => _TripRow(trip: list[i]),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TripRow extends StatelessWidget {
  const _TripRow({required this.trip});
  final Trip trip;

  @override
  Widget build(BuildContext context) {
    final completed = trip.status == TripStatus.completed;
    final when =
        trip.createdAt != null ? formatRelativeDateTime(trip.createdAt!) : '';
    final sub = [when, trip.tierLabel].where((s) => s.isNotEmpty).join(' · ');

    final (statusText, statusColor) = switch (trip.status) {
      TripStatus.completed => (trip.paymentMethodLabel, Brand.sub),
      TripStatus.cancelledByRider ||
      TripStatus.cancelledByDriver =>
        ('Cancelled', Brand.sub),
      _ => ('In progress', Brand.blue),
    };

    return GestureDetector(
      onTap: completed ? () => context.push('/receipt', extra: trip) : null,
      child: McCard(
        padding: 14,
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Brand.fill,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(child: Ico('car', size: 24, color: Brand.sub)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          trip.dropoff.label.isNotEmpty
                              ? trip.dropoff.label
                              : 'Trip',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tw(FontWeight.w900, 15),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        completed ? (trip.formattedTotal ?? '—') : '',
                        style: tw(FontWeight.w900, 15),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Expanded(
                        child: Text(sub,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: tw(FontWeight.w600, 12.5, Brand.sub)),
                      ),
                      const SizedBox(width: 8),
                      Text(statusText, style: tw(FontWeight.w800, 12, statusColor)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.sub,
    this.onRetry,
  });
  final String icon;
  final String title;
  final String sub;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Ico(icon, size: 40, color: Brand.faint),
            const SizedBox(height: 12),
            Text(title, style: tw(FontWeight.w900, 17)),
            const SizedBox(height: 6),
            Text(sub,
                textAlign: TextAlign.center,
                style: tw(FontWeight.w600, 13, Brand.sub)),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              McGhostButton('Try again', icon: 'nav', height: 44, onTap: onRetry),
            ],
          ],
        ),
      ),
    );
  }
}

class _CustomerTabBar extends StatelessWidget {
  const _CustomerTabBar({required this.active});
  final String active;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('home', 'Home', () => context.go('/home')),
      ('receipt', 'Activity', () => context.go('/activity')),
      ('user', 'Account', () => context.go('/account')),
    ];
    return Container(
      height: 84,
      decoration: const BoxDecoration(
        color: Brand.paper,
        border: Border(top: BorderSide(color: Brand.fill)),
      ),
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        children: [
          for (final (icon, label, onTap) in items)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onTap,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Ico(icon, size: 24, color: active == label.toLowerCase() ? Brand.blue : Brand.faint),
                    const SizedBox(height: 3),
                    Text(label,
                        style: tw(FontWeight.w800, 11,
                            active == label.toLowerCase() ? Brand.blue : Brand.faint)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
