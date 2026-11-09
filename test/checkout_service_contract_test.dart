import 'dart:io';

import 'package:cartxis_app/core/network/api_client.dart';
import 'package:cartxis_app/data/services/checkout_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordedPost {
  final String endpoint;
  final Map<String, dynamic>? body;

  const _RecordedPost(this.endpoint, this.body);
}

class _RecordedGet {
  final String endpoint;
  final Map<String, dynamic>? queryParameters;

  const _RecordedGet(this.endpoint, this.queryParameters);
}

class _RecordedMultipart {
  final String endpoint;
  final Map<String, String>? fields;
  final Map<String, File>? files;

  const _RecordedMultipart(this.endpoint, this.fields, this.files);
}

class _FakeApiClient extends ApiClient {
  final List<_RecordedGet> gets = [];
  final List<_RecordedPost> posts = [];
  final List<_RecordedMultipart> multipartPosts = [];

  @override
  Future<Map<String, dynamic>> get(
    String endpoint, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
  }) async {
    gets.add(_RecordedGet(endpoint, queryParameters));
    return {
      'success': true,
      'data': endpoint.endsWith('/shipping-methods')
          ? <dynamic>[]
          : <String, dynamic>{},
    };
  }

  @override
  Future<Map<String, dynamic>> post(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    posts.add(_RecordedPost(endpoint, body));
    return {'success': true, 'data': <String, dynamic>{}};
  }

  @override
  Future<Map<String, dynamic>> postMultipart(
    String endpoint, {
    Map<String, String>? headers,
    Map<String, String>? fields,
    Map<String, File>? files,
  }) async {
    multipartPosts.add(_RecordedMultipart(endpoint, fields, files));
    return {
      'success': true,
      'data': {'submission_status': 'pending_review'},
    };
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

    test('loads shipping methods for the selected address', () async {
      await service.getShippingMethods(shippingAddressId: 7);

      expect(
          apiClient.gets.single.endpoint, '/api/v1/checkout/shipping-methods');
      expect(apiClient.gets.single.queryParameters, {
        'shipping_address_id': 7,
      });
    });

    test('uses the selected shipping method in the checkout summary', () async {
      await service.getCheckoutSummary(
        shippingMethodCode: 'express',
        shippingAddressId: 7,
      );

      expect(apiClient.gets.single.endpoint, '/api/v1/checkout/summary');
      expect(apiClient.gets.single.queryParameters, {
        'shipping_method_code': 'express',
        'shipping_address_id': 7,
      });
    });

    test('forwards address and shipping choice when creating Stripe intent',
        () async {
      await service.setPaymentMethod(
        'stripe',
        shippingAddressId: 7,
        shippingMethodCode: 'express',
      );

      expect(
          apiClient.posts.single.endpoint, '/api/v1/checkout/payment-method');
      expect(apiClient.posts.single.body, {
        'payment_method_code': 'stripe',
        'shipping_address_id': 7,
        'shipping_method_code': 'express',
      });
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
        shippingMethodCode: 'express',
        paymentMethod: 'cod',
      );

      expect(apiClient.posts, hasLength(1));
      expect(apiClient.posts.single.endpoint, '/api/v1/checkout/place-order');
      expect(apiClient.posts.single.body, {
        'shipping_address_id': 7,
        'billing_address_id': 12,
        'shipping_method_code': 'express',
        'payment_method': 'cod',
      });
    });

    test(
        'uploads manual transfer proof with the selected account and reference',
        () async {
      final proof = File('/tmp/transfer-receipt.png');
      await service.submitManualPayment(
        orderId: 41,
        destinationId: 'wallet-1',
        transferReference: 'TX-8831',
        proof: proof,
      );

      expect(apiClient.multipartPosts, hasLength(1));
      expect(apiClient.multipartPosts.single.endpoint,
          '/api/v1/customer/orders/41/manual-payment');
      expect(apiClient.multipartPosts.single.fields, {
        'destination_id': 'wallet-1',
        'transfer_reference': 'TX-8831',
      });
      expect(apiClient.multipartPosts.single.files?['payment_proof'], proof);
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
