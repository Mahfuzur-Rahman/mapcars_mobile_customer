import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/utils/date_format.dart';
import '../../ride/models/trip.dart';

class ReceiptPdfBuilder {
  static Future<Uint8List> buildPdf(Trip trip) async {
    final pdf = pw.Document(title: 'MapCars Receipt - ${trip.id}');

    final receiptNumber = 'MC-${trip.id.length >= 8 ? trip.id.substring(0, 8).toUpperCase() : trip.id.toUpperCase()}';
    final dateStr = trip.createdAt != null
        ? '${formatLongDate(trip.createdAt!)} · ${formatClockTime(trip.createdAt!)}'
        : DateFormat('dd MMM yyyy, HH:mm').format(DateTime.now());

    final primaryColor = PdfColor.fromHex('#16202E');
    final accentBlue = PdfColor.fromHex('#0B7DC0');
    final accentGreen = PdfColor.fromHex('#31A424');
    final subtleBg = PdfColor.fromHex('#F4F6F8');
    final textMuted = PdfColor.fromHex('#64748B');
    final borderCol = PdfColor.fromHex('#E2E8F0');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'MAP CARS',
                        style: pw.TextStyle(
                          fontSize: 26,
                          fontWeight: pw.FontWeight.bold,
                          color: accentBlue,
                          letterSpacing: 2,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'RIDE SHARING MADE EASY',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: textMuted,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: pw.BoxDecoration(
                          color: subtleBg,
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                          border: pw.Border.all(color: borderCol),
                        ),
                        child: pw.Text(
                          'TRIP RECEIPT',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                      ),
                      pw.SizedBox(height: 6),
                      pw.Text(
                        receiptNumber,
                        style: pw.TextStyle(
                          fontSize: 13,
                          fontWeight: pw.FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                      pw.Text(
                        dateStr,
                        style: pw.TextStyle(fontSize: 9, color: textMuted),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 24),
              pw.Divider(color: borderCol, thickness: 1),
              pw.SizedBox(height: 16),

              // Trip Route Box
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: subtleBg,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
                  border: pw.Border.all(color: borderCol),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Container(
                          width: 10,
                          height: 10,
                          margin: const pw.EdgeInsets.only(top: 3),
                          decoration: pw.BoxDecoration(
                            color: accentGreen,
                            shape: pw.BoxShape.circle,
                          ),
                        ),
                        pw.SizedBox(width: 12),
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                'PICKUP',
                                style: pw.TextStyle(
                                  fontSize: 8,
                                  fontWeight: pw.FontWeight.bold,
                                  color: textMuted,
                                ),
                              ),
                              pw.Text(
                                trip.pickup.address.isNotEmpty
                                    ? trip.pickup.address
                                    : trip.pickup.label,
                                style: pw.TextStyle(
                                  fontSize: 11,
                                  fontWeight: pw.FontWeight.bold,
                                  color: primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    pw.Container(
                      margin: const pw.EdgeInsets.only(left: 4),
                      height: 16,
                      width: 2,
                      color: borderCol,
                    ),
                    pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Container(
                          width: 10,
                          height: 10,
                          margin: const pw.EdgeInsets.only(top: 3),
                          decoration: pw.BoxDecoration(
                            color: accentBlue,
                            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
                          ),
                        ),
                        pw.SizedBox(width: 12),
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                'DROPOFF',
                                style: pw.TextStyle(
                                  fontSize: 8,
                                  fontWeight: pw.FontWeight.bold,
                                  color: textMuted,
                                ),
                              ),
                              pw.Text(
                                trip.dropoff.address.isNotEmpty
                                    ? trip.dropoff.address
                                    : trip.dropoff.label,
                                style: pw.TextStyle(
                                  fontSize: 11,
                                  fontWeight: pw.FontWeight.bold,
                                  color: primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),

              // Metrics & Driver Grid
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: borderCol),
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'TRIP DETAILS',
                            style: pw.TextStyle(
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                              color: textMuted,
                            ),
                          ),
                          pw.SizedBox(height: 8),
                          _buildDetailRow('Service Tier', trip.tierLabel.isNotEmpty ? trip.tierLabel : 'Standard'),
                          if (trip.distanceMiles != null)
                            _buildDetailRow('Distance', '${trip.distanceMiles!.toStringAsFixed(1)} miles'),
                          if (trip.durationMinutes != null)
                            _buildDetailRow('Duration', '${trip.durationMinutes!.round()} min'),
                          _buildDetailRow('Status', trip.status.name.toUpperCase()),
                        ],
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 12),
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: borderCol),
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'DRIVER & VEHICLE',
                            style: pw.TextStyle(
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                              color: textMuted,
                            ),
                          ),
                          pw.SizedBox(height: 8),
                          _buildDetailRow('Driver', trip.driver?.name ?? 'Assigned Driver'),
                          if (trip.driver?.vehicle.isNotEmpty ?? false)
                            _buildDetailRow('Vehicle', trip.driver!.vehicle),
                          if (trip.driver?.plate.isNotEmpty ?? false)
                            _buildDetailRow('Plate', trip.driver!.plate),
                          _buildDetailRow('Payment', trip.paymentMethodLabel),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 20),

              // Payment & Fare Breakdown
              pw.Text(
                'PAYMENT BREAKDOWN',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: borderCol),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Column(
                  children: [
                    _buildPaymentLine('Trip Fare (${trip.tierLabel.isNotEmpty ? trip.tierLabel : 'Standard'})', trip.formattedFare ?? '—'),
                    if (trip.formattedTip != null)
                      _buildPaymentLine('Driver Tip', trip.formattedTip!),
                    pw.Divider(color: borderCol, thickness: 1, height: 1),
                    pw.Container(
                      color: subtleBg,
                      padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'Total Paid',
                            style: pw.TextStyle(
                              fontSize: 13,
                              fontWeight: pw.FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                          pw.Text(
                            trip.formattedTotal ?? '—',
                            style: pw.TextStyle(
                              fontSize: 15,
                              fontWeight: pw.FontWeight.bold,
                              color: accentBlue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Payment Method: ${trip.paymentMethodLabel}',
                    style: pw.TextStyle(fontSize: 9, color: textMuted),
                  ),
                  pw.Text(
                    trip.isPaid ? 'Payment Status: COMPLETED' : 'Payment Status: ${trip.paymentStatus.toUpperCase()}',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: trip.isPaid ? accentGreen : textMuted,
                    ),
                  ),
                ],
              ),

              pw.Spacer(),

              // Footer
              pw.Divider(color: borderCol, thickness: 1),
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'MapCars UK Ltd · Dorset, United Kingdom',
                        style: pw.TextStyle(fontSize: 8, color: textMuted),
                      ),
                      pw.Text(
                        'Support & Inquiries: support@mapcars.uk',
                        style: pw.TextStyle(fontSize: 8, color: textMuted),
                      ),
                    ],
                  ),
                  pw.Text(
                    'Thank you for riding with MapCars',
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildDetailRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 9, color: PdfColor.fromHex('#64748B'))),
          pw.Text(value, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#16202E'))),
        ],
      ),
    );
  }

  static pw.Widget _buildPaymentLine(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#475569'))),
          pw.Text(value, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#16202E'))),
        ],
      ),
    );
  }
}
