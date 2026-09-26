// The API refuses a booking it won't take (payment method switched off, an
// unpaid balance) with a 400 whose problem+json `title` is written for the
// customer. The confirm screen shows `RideFlowState.error`, which is
// `friendlyError` of whatever `requestTrip` threw — so that wording has to
// survive the trip through Dio and ApiException intact, not be flattened into
// a generic "Invalid request.".

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapcars_mobile/src/core/network/api_client.dart';
import 'package:mapcars_mobile/src/core/network/friendly_error.dart';

DioException _refusal(String title) {
  final options = RequestOptions(path: '/api/v1/trips', method: 'POST');
  return DioException.badResponse(
    statusCode: 400,
    requestOptions: options,
    response: Response(
      requestOptions: options,
      statusCode: 400,
      // ExceptionHandlingMiddleware's shape for a DomainException.
      data: {'title': title, 'status': 400, 'errors': null},
    ),
  );
}

void main() {
  const card = "Card payments aren't available yet. Please choose cash.";
  const debt = 'You have an unpaid balance of £12.40 from an earlier trip. '
      'Please settle it before booking again.';

  test('a refused booking shows the API\'s own sentence', () async {
    for (final message in [card, debt]) {
      // Exactly the path DioRideRepository.requestTrip takes.
      Object? thrown;
      try {
        await apiCall<void>(() => throw _refusal(message));
      } catch (e) {
        thrown = e;
      }
      expect(friendlyError(thrown!), message);
    }
  });

  test('a raw DioException with a body also keeps the API wording', () {
    expect(friendlyError(_refusal(card)), card);
  });
}
