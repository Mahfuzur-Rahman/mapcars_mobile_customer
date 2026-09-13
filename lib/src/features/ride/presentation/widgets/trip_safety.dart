import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/brand.dart';
import '../../../../core/widgets/support_sheets.dart';
import '../../../auth/providers/auth_notifier.dart';
import '../../models/driver_location.dart';
import '../../models/trip.dart';

/// The in-ride safety layer.
///
/// Distinct from the Settings "Safety & Privacy" sheet, which is policy text and
/// a 999 shortcut: this one knows about the *current trip*, so it can hand the
/// customer's emergency contact the details of the car they are actually sitting in.
///
/// The emergency contact is captured during profile setup and, until this
/// existed, was never read anywhere — the sheet below is what makes collecting
/// it worth doing.

/// Opens the safety sheet for [trip]. [driverPosition] is the car's last known
/// fix, used for the location line in a shared message.
Future<void> showTripSafetySheet(
  BuildContext context,
  WidgetRef ref,
  Trip trip, {
  DriverLocation? driverPosition,
}) {
  final auth = ref.read(authNotifierProvider);
  final contactName = auth.emergencyContactName;
  final contactPhone = auth.emergencyContactPhone;
  final hasContact = contactPhone != null && contactPhone.trim().isNotEmpty;

  return showSupportSheet(
    context,
    title: 'Safety',
    blurb: 'Your trip details are ready to send. Emergency services first.',
    tiles: (ctx) => [
      LinkTile(
        title: 'Emergency 999 Services',
        subtitle: 'One-tap emergency call',
        icon: 'shield',
        color: Colors.red,
        onTap: () {
          Navigator.pop(ctx);
          openExternalUrl(context, 'tel:999');
        },
      ),
      const SizedBox(height: 10),
      // Either call the contact the customer already gave us, or send them to add
      // one — never show a dead row.
      if (hasContact)
        LinkTile(
          title: 'Call ${contactName?.trim().isNotEmpty == true ? contactName!.trim() : 'emergency contact'}',
          subtitle: contactPhone.trim(),
          icon: 'nav',
          color: Brand.blue,
          onTap: () {
            Navigator.pop(ctx);
            openExternalUrl(context, 'tel:${_dialable(contactPhone)}');
          },
        )
      else
        LinkTile(
          title: 'Add an emergency contact',
          subtitle: 'So one tap reaches someone who knows you',
          icon: 'user',
          color: Brand.blue,
          onTap: () {
            Navigator.pop(ctx);
            context.push('/account/edit');
          },
        ),
      const SizedBox(height: 10),
      LinkTile(
        title: 'Share trip details',
        subtitle: 'Driver, vehicle, registration and destination',
        icon: 'nav',
        color: Brand.green,
        onTap: () {
          Navigator.pop(ctx);
          shareTrip(trip, driverPosition: driverPosition);
        },
      ),
      const SizedBox(height: 10),
      LinkTile(
        title: 'Call Mapcars support',
        subtitle: '01243 252255 · Chichester Dispatch',
        icon: 'msg',
        color: Brand.ink,
        onTap: () {
          Navigator.pop(ctx);
          openExternalUrl(context, 'tel:01243252255');
        },
      ),
    ],
  );
}

/// Hands the ride's identifying details to whatever the customer picks — Messages,
/// WhatsApp, email.
Future<void> shareTrip(Trip trip, {DriverLocation? driverPosition}) {
  return Share.share(
    buildTripShareMessage(trip, driverPosition: driverPosition),
    subject: 'My Mapcars ride',
  );
}

/// The text [shareTrip] sends. Split out from the platform call so it can be
/// tested — this is a safety message, and it going out malformed or missing the
/// registration is the failure that matters.
///
/// This is a **snapshot**, not a live link, and the wording says so. A link that
/// keeps updating needs a public tracking page on the web plus a share token in
/// the API; neither exists yet, and a stale link that *looks* live is worse than
/// an honest snapshot on a safety feature.
String buildTripShareMessage(Trip trip, {DriverLocation? driverPosition}) {
  final b = StringBuffer("I'm on a Mapcars ride.");

  final driver = trip.driver;
  if (driver != null) {
    if (driver.name.isNotEmpty) b.write('\n\nDriver: ${driver.name}');
    if (driver.vehicle.isNotEmpty) b.write('\nVehicle: ${driver.vehicle}');
    if (driver.plate.isNotEmpty) b.write('\nRegistration: ${driver.plate}');
  }

  b.write('\n\nFrom: ${_placeLine(trip.pickup.label, trip.pickup.address)}');
  b.write('\nTo: ${_placeLine(trip.dropoff.label, trip.dropoff.address)}');

  if (driverPosition != null) {
    final lat = driverPosition.lat.toStringAsFixed(5);
    final lng = driverPosition.lng.toStringAsFixed(5);
    b.write('\n\nWhere we were when I sent this: '
        'https://www.google.com/maps/search/?api=1&query=$lat,$lng');
  }

  b.write('\n\nSent from the Mapcars app.');

  return b.toString();
}

/// "Tower Bridge — London SE1 2UP", skipping either half when it is missing or
/// duplicated, so a share never reads "London SE1 2UP — London SE1 2UP".
String _placeLine(String label, String address) {
  final l = label.trim();
  final a = address.trim();
  if (l.isEmpty) return a;
  if (a.isEmpty || a == l) return l;
  return '$l — $a';
}

/// Strips spaces and punctuation a dialer would choke on, keeping a leading `+`.
String _dialable(String phone) {
  final trimmed = phone.trim();
  final plus = trimmed.startsWith('+') ? '+' : '';
  return plus + trimmed.replaceAll(RegExp(r'[^0-9]'), '');
}
