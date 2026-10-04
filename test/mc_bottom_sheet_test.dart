// Modal bottom sheets — help, safety, socials, photo picker, the saved-place
// form — must keep their last action tappable above the system nav bar and,
// for the form, above the keyboard.
//
// Every one of them padded its bottom with a fixed 28dp, was not
// scroll-controlled (so capped at 9/16 of the screen, with no scrolling), and
// the form read the keyboard height from the page underneath instead of from
// the sheet.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapcars_mobile/src/core/network/network_diagnosis.dart';
import 'package:mapcars_mobile/src/core/theme/app_theme.dart';
import 'package:mapcars_mobile/src/core/widgets/mc.dart';
import 'package:mapcars_mobile/src/core/widgets/support_sheets.dart';
import 'package:mapcars_mobile/src/features/account/models/saved_place.dart';
import 'package:mapcars_mobile/src/features/account/presentation/saved_places_screen.dart';
import 'package:mapcars_mobile/src/features/account/providers/saved_places_provider.dart';
import 'package:mapcars_mobile/src/features/account/services/saved_places_service.dart';

import 'support/reachability.dart';

/// A page with one button that opens whatever sheet [open] shows.
Widget _opener(void Function(BuildContext context) open) => Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: TextButton(
              onPressed: () => open(context), child: const Text('open')),
        ),
      ),
    );

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

/// The nearest tappable box around [text] — the whole tile, not just its label.
Finder _tile(String text) => find
    .ancestor(of: find.text(text), matching: find.byType(GestureDetector))
    .first;

/// Far more rows than fit on a small phone.
Widget _tallBody({bool withField = false}) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (withField) const McField(placeholder: 'Note', editable: true),
        for (var i = 0; i < 30; i++)
          SizedBox(height: 44, child: Text('Row $i')),
      ],
    );

void main() {
  group('showMcBottomSheet', () {
    for (final scale in [1.0, 1.3]) {
      testWidgets('a footer is reachable however tall the body (text x$scale)',
          (tester) async {
        await pumpOnSmallPhone(
          tester,
          _opener((context) => showMcBottomSheet<void>(
                context,
                builder: (ctx) => McSheet(
                  footer: McButton('Done', onTap: () => Navigator.pop(ctx)),
                  child: _tallBody(),
                ),
              )),
          textScale: scale,
        );
        await _open(tester);
        expectReachableWithoutScrolling(tester, find.byType(McButton));
      });
    }

    testWidgets('a body-only sheet scrolls its last row clear of the nav bar',
        (tester) async {
      await pumpOnSmallPhone(
        tester,
        _opener((context) => showMcBottomSheet<void>(
              context,
              builder: (_) => McSheet(child: _tallBody()),
            )),
      );
      await _open(tester);

      // With no footer the only way to the end is through the body — which
      // must stop with its last row above the bar, not under it.
      await tester.drag(find.text('Row 3'), const Offset(0, -3000));
      await tester.pumpAndSettle();
      expectReachableWithoutScrolling(
          tester,
          find
              .ancestor(
                  of: find.text('Row 29'), matching: find.byType(SizedBox))
              .first);
    });

    testWidgets('the footer rises with the keyboard', (tester) async {
      await pumpOnSmallPhone(
        tester,
        _opener((context) => showMcBottomSheet<void>(
              context,
              builder: (ctx) => McSheet(
                footer: McButton('Send', onTap: () => Navigator.pop(ctx)),
                child: _tallBody(withField: true),
              ),
            )),
      );
      await _open(tester);

      await tester.showKeyboard(find.byType(TextField));
      setKeyboard(tester, open: true);
      await tester.pumpAndSettle();
      expectReachableWithoutScrolling(tester, find.byType(McButton));
    });

    testWidgets('returns the value the sheet pops with', (tester) async {
      String? picked;
      await pumpOnSmallPhone(
        tester,
        _opener((context) async {
          picked = await showMcBottomSheet<String>(
            context,
            builder: (ctx) => McSheet(
              child: McButton('Pick', onTap: () => Navigator.pop(ctx, 'yes')),
            ),
          );
        }),
      );
      await _open(tester);
      await tester.tap(find.text('Pick'));
      await tester.pumpAndSettle();
      expect(picked, 'yes');
    });
  });

  group('existing sheets', () {
    for (final scale in [1.0, 1.3]) {
      testWidgets(
          'Help & Support: the last contact clears the nav bar (text x$scale)',
          (tester) async {
        await pumpOnSmallPhone(tester, _opener(showHelpSupportSheet),
            textScale: scale);
        await _open(tester);
        expectReachableWithoutScrolling(tester, _tile('Email Support'));
      });

      testWidgets(
          'photo picker: "Choose from gallery" clears the nav bar (text x$scale)',
          (tester) async {
        await pumpOnSmallPhone(tester, _opener(showPictureSourcePicker),
            textScale: scale);
        await _open(tester);
        expectReachableWithoutScrolling(tester, _tile('Choose from gallery'));
      });
    }
  });

  for (final scale in [1.0, 1.3]) {
    testWidgets(
        'saved-place form: Save stays above the keyboard (text x$scale)',
        (tester) async {
      await loadAppFonts();
      configureSmallPhone(tester, textScale: scale);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          savedPlacesProvider.overrideWith((ref) async => const <SavedPlace>[]),
        ],
        child:
            MaterialApp(theme: AppTheme.light, home: const SavedPlacesScreen()),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add a place'));
      await tester.pumpAndSettle();

      // The sheet is already up when the customer taps a field and the keyboard
      // arrives — the order that matters, because the old form measured the
      // keyboard from the page beneath the sheet.
      await tester.showKeyboard(find.byType(TextField).first);
      setKeyboard(tester, open: true);
      await tester.pumpAndSettle();

      expectReachableWithoutScrolling(
          tester, find.widgetWithText(McButton, 'Save place'));
    });
  }

  // A failed save can answer with the long "can't reach Mapcars" message and its
  // "Ref:" diagnosis line. That rode in the footer as raw red text with no cap:
  // with the keyboard up at 1.3 it left 8dp of form, and at 2.0 it overflowed and
  // pushed Save off the screen.
  group('saved-place form, failed save with the long unreachable message', () {
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('keyboard up, text x$scale', (tester) async {
        await loadAppFonts();
        configureSmallPhone(tester, textScale: scale);
        await tester.pumpWidget(ProviderScope(
          overrides: [
            // A list, not the empty state: with the keyboard up that page
            // behind the sheet overflows at x2.0 on its own, which this test is
            // not about.
            savedPlacesProvider.overrideWith((ref) async => const [
                  SavedPlace(
                      id: '1', label: 'Home', address: '1 High St', lat: 51.5, lng: -0.1),
                ]),
            savedPlacesServiceProvider.overrideWithValue(_Unreachable()),
          ],
          child: MaterialApp(
              theme: AppTheme.light, home: const SavedPlacesScreen()),
        ));
        await tester.pumpAndSettle();

        await tester.tap(
            find.byWidgetPredicate((w) => w is Ico && w.name == 'plus'));
        await tester.pumpAndSettle();
        final fields = find.byType(TextField);
        await tester.enterText(fields.at(0), 'Home');
        await tester.enterText(fields.at(1), '1 High St');
        await tester.enterText(fields.at(2), '51.5');
        await tester.enterText(fields.at(3), '-0.1');
        await tester.showKeyboard(fields.first);
        setKeyboard(tester, open: true);
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(McButton, 'Save place'));
        await tester.pumpAndSettle();

        // The real message, "Ref:" line and all.
        expect(find.textContaining('Ref: api.example.test'), findsOneWidget);
        expect(find.byType(McErrorBanner), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'no RenderFlex overflow');
        expectReachableWithoutScrolling(
            tester, find.widgetWithText(McButton, 'Save place'));

        if (scale <= 1.3) {
          final form = tester.getRect(find.descendant(
              of: find.byType(McSheet),
              matching: find.byType(SingleChildScrollView)));
          expect(form.height, greaterThanOrEqualTo(52),
              reason: 'the form is squeezed to ${form.height}dp above the footer');
        }
      });
    }
  });
}

/// A saved-places service whose save fails because the API was never reached,
/// with the diagnosis the API client's interceptor attaches.
class _Unreachable extends SavedPlacesService {
  _Unreachable() : super(Dio());

  @override
  Future<SavedPlace> create({
    required String label,
    required String address,
    required double lat,
    required double lng,
  }) {
    final options = RequestOptions(path: '/api/v1/saved-places');
    options.extra[networkDiagnosisKey] = const NetworkDiagnosis(
      host: 'api.example.test',
      dns: 'fail',
      tcp: 'skipped',
      internet: 'ok',
      network: 'wifi',
    );
    throw DioException.connectionError(
        requestOptions: options, reason: 'unreachable');
  }
}
