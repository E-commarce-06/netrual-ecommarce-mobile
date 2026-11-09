import 'package:cartxis_app/core/network/api_client.dart';
import 'package:cartxis_app/data/services/checkout_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordedPost {
  final String endpoint;
  final Map<String, dynamic>? body;

  const _RecordedPost(this.endpoint, this.body);
}

class _FakeApiClient extends ApiClient {
  final List<_RecordedPost> posts = [];

  @override
  Future<Map<String, dynamic>> post(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    posts.add(_RecordedPost(endpoint, body));
    return {'success': true, 'data': <String, dynamic>{}};
  }
}

void main() {
  group('CheckoutService API contract', () {
    late _FakeApiClient apiClient;
    late CheckoutService service;

    setUp(() {
      apiClient = _FakeApiClient();
      service = CheckoutService(apiClient: apiClient);
    });

    test('uses the backend same_as_shipping billing flag', () async {
      await service.setBillingAddress(
        addressId: 7,
        useShippingAddress: true,
      );

      expect(apiClient.posts, hasLength(1));
      expect(
          apiClient.posts.single.endpoint, '/api/v1/checkout/billing-address');
      expect(apiClient.posts.single.body, {
        'address_id': 7,
        'same_as_shipping': true,
      });
    });

    test('includes the selected billing address in the order request',
        () async {
      await service.placeOrder(
        shippingAddressId: 7,
        billingAddressId: 12,
        paymentMethod: 'cod',
      );

      expect(apiClient.posts, hasLength(1));
      expect(apiClient.posts.single.endpoint, '/api/v1/checkout/place-order');
      expect(apiClient.posts.single.body, {
        'shipping_address_id': 7,
        'billing_address_id': 12,
        'payment_method': 'cod',
      });
    });

    test('omits billing_address_id when shipping is also the billing address',
        () async {
      await service.placeOrder(
        shippingAddressId: 7,
        paymentMethod: 'cod',
      );

      expect(apiClient.posts.single.body, {
        'shipping_address_id': 7,
        'payment_method': 'cod',
      });
    });
  });
}
