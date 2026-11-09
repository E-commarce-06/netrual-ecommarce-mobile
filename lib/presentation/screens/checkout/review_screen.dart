import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:cartxis_app/core/config/mobile_app_settings_controller.dart';
import 'package:cartxis_app/core/constants/app_colors.dart';
import 'package:cartxis_app/data/services/checkout_service.dart';
import 'package:cartxis_app/data/services/cart_service.dart';
import 'package:cartxis_app/payments/gateways/paypal_service.dart';
import 'package:cartxis_app/payments/gateways/phonepe_service.dart';
import 'package:cartxis_app/payments/gateways/razorpay_service.dart';
import 'package:cartxis_app/payments/gateways/stripe_service.dart';
import 'package:cartxis_app/presentation/widgets/price_text.dart';

class ReviewScreen extends StatefulWidget {
  final Map<String, dynamic> checkoutSummary;
  final Map<String, dynamic> selectedAddress;
  final Map<String, dynamic> selectedShippingMethod;
  final Map<String, dynamic> selectedPaymentMethod;
  final int? billingAddressId;
  final Map<String, dynamic>? billingAddress;

  const ReviewScreen({
    super.key,
    required this.checkoutSummary,
    required this.selectedAddress,
    required this.selectedShippingMethod,
    required this.selectedPaymentMethod,
    this.billingAddressId,
    this.billingAddress,
  });

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  final CheckoutService _checkoutService = CheckoutService();
  final CartService _cartService = CartService();
  final PayPalService _paypalService = PayPalService();
  final PhonePeService _phonePeService = PhonePeService();
  final RazorpayService _razorpayService = RazorpayService();
  final StripeService _stripeService = StripeService();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _transferReferenceController =
      TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  File? _manualPaymentProof;
  String? _selectedManualDestinationId;
  Map<String, dynamic>? _createdManualOrder;
  List<Map<String, dynamic>> _cartItems = [];
  bool _isLoading = true;
  bool _isPlacingOrder = false;

  @override
  void initState() {
    super.initState();
    final destinations = _manualDestinations;
    if (destinations.isNotEmpty) {
      _selectedManualDestinationId = destinations.first['id']?.toString();
    }
    _loadCartItems();
  }

  Future<void> _loadCartItems() async {
    try {
      final cartModel = await _cartService.getCart();
      setState(() {
        _cartItems = cartModel.items.map((item) {
          String imageUrl = '';
          if (item.product.images.isNotEmpty) {
            final firstImage = item.product.images[0];
            if (firstImage is String) {
              imageUrl = firstImage;
            } else if (firstImage is Map<String, dynamic>) {
              imageUrl = firstImage['url']?.toString() ??
                  firstImage['path']?.toString() ??
                  firstImage['image']?.toString() ??
                  '';
            }
          }
          return {
            'product': {
              'name': item.product.name,
              'image_url': imageUrl,
              'price': item.price,
            },
            'quantity': item.quantity,
            'price': item.price,
          };
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  double get _subtotal =>
      (widget.checkoutSummary['subtotal'] as num?)?.toDouble() ?? 0.0;
  double get _shipping =>
      (widget.checkoutSummary['shipping_cost'] as num?)?.toDouble() ?? 0.0;
  double get _tax => (widget.checkoutSummary['tax'] as num?)?.toDouble() ?? 0.0;
  double get _discount =>
      (widget.checkoutSummary['discount'] as num?)?.toDouble() ?? 0.0;
  double get _total =>
      (widget.checkoutSummary['total'] as num?)?.toDouble() ?? 0.0;

  String get _paymentFlow {
    final configuredFlow = widget.selectedPaymentMethod['mobile_flow'];
    if (configuredFlow is String && configuredFlow.isNotEmpty) {
      return configuredFlow;
    }
    return switch ((widget.selectedPaymentMethod['code'] ?? '').toString()) {
      'cod' => 'cash_on_delivery',
      'bank_transfer' => 'manual_transfer',
      'razorpay' => 'razorpay',
      'stripe' => 'stripe',
      'paypal' => 'paypal',
      'phonepe' => 'phonepe',
      _ => 'unsupported',
    };
  }

  bool get _isManualTransfer => _paymentFlow == 'manual_transfer';

  List<Map<String, dynamic>> get _manualDestinations {
    final config = widget.selectedPaymentMethod['manual_payment'];
    if (config is! Map) return const [];
    final rawDestinations = config['destinations'];
    if (rawDestinations is! List) return const [];
    return rawDestinations.whereType<Map<String, dynamic>>().toList();
  }

  @override
  void dispose() {
    _notesController.dispose();
    _transferReferenceController.dispose();
    _razorpayService.dispose();
    _stripeService.dispose();
    super.dispose();
  }

  Future<void> _placeOrder() async {
    setState(() {
      _isPlacingOrder = true;
    });

    try {
      // Extract required data

      final shippingAddressId = widget.selectedAddress['id'] as int?;
      final paymentMethodCode = widget.selectedPaymentMethod['code'] as String?;
      final notes = _notesController.text.trim();

      if (shippingAddressId == null) {
        throw Exception('Shipping address is required');
      }
      if (paymentMethodCode == null) {
        throw Exception('Payment method is required');
      }

      if (widget.selectedPaymentMethod['mobile_supported'] == false ||
          _paymentFlow == 'unsupported') {
        throw Exception(
          widget.selectedPaymentMethod['mobile_support_reason']?.toString() ??
              'This payment method is not supported in the mobile app yet.',
        );
      }

      final orderNotes = notes.isNotEmpty ? notes : null;
      if (_paymentFlow == 'razorpay') {
        await _processRazorpayPayment(
          shippingAddressId: shippingAddressId,
          billingAddressId: widget.billingAddressId,
          shippingMethodCode: widget.selectedShippingMethod['code']?.toString(),
          notes: orderNotes,
        );
      } else if (_paymentFlow == 'stripe') {
        await _processStripePayment(
          shippingAddressId: shippingAddressId,
          billingAddressId: widget.billingAddressId,
          shippingMethodCode: widget.selectedShippingMethod['code']?.toString(),
          notes: orderNotes,
        );
      } else if (_paymentFlow == 'paypal') {
        await _processPayPalPayment(
          shippingAddressId: shippingAddressId,
          billingAddressId: widget.billingAddressId,
          shippingMethodCode: widget.selectedShippingMethod['code']?.toString(),
          notes: orderNotes,
        );
      } else if (_paymentFlow == 'phonepe') {
        await _processPhonePePayment(
          shippingAddressId: shippingAddressId,
          billingAddressId: widget.billingAddressId,
          shippingMethodCode: widget.selectedShippingMethod['code']?.toString(),
          notes: orderNotes,
        );
      } else if (_paymentFlow == 'manual_transfer') {
        await _placeManualTransferOrder(
          shippingAddressId: shippingAddressId,
          billingAddressId: widget.billingAddressId,
          shippingMethodCode: widget.selectedShippingMethod['code']?.toString(),
          paymentMethod: paymentMethodCode,
          notes: orderNotes,
        );
      } else if (_paymentFlow == 'cash_on_delivery') {
        await _placeOrderDirect(
          shippingAddressId: shippingAddressId,
          billingAddressId: widget.billingAddressId,
          shippingMethodCode: widget.selectedShippingMethod['code']?.toString(),
          paymentMethod: paymentMethodCode,
          notes: orderNotes,
        );
      } else {
        throw Exception('Unsupported mobile payment flow: $_paymentFlow');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to place order: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() {
        _isPlacingOrder = false;
      });
    }
  }

  Future<void> _processRazorpayPayment({
    required int shippingAddressId,
    int? billingAddressId,
    String? shippingMethodCode,
    String? notes,
  }) async {
    try {
      // Step 1: get gateway config for UI branding (name, theme)
      final paymentMethodData =
          await _checkoutService.setPaymentMethod('razorpay');
      final gatewayConfig =
          paymentMethodData['gateway_config'] as Map<String, dynamic>?;
      final businessName = gatewayConfig?['name'] as String? ??
          MobileAppSettingsScope.of(context).settings.appName;
      final themeColor = gatewayConfig?['theme_color'] as String? ?? '#3399cc';

      // Step 2: place order first — backend creates internal order + Razorpay order
      final orderResult = await _checkoutService.placeOrder(
        shippingAddressId: shippingAddressId,
        billingAddressId: billingAddressId,
        shippingMethodCode: shippingMethodCode,
        paymentMethod: 'razorpay',
        notes: notes,
      );

      final internalOrderId = (orderResult['order_id'] as num?)?.toInt() ??
          (orderResult['id'] as num?)?.toInt();
      final orderNumber = orderResult['order_number'] as String? ??
          '#VX-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
      final razorpayOrderId = orderResult['razorpay_order_id'] as String?;
      final razorpayKey = (orderResult['razorpay_key_id'] as String?) ??
          (gatewayConfig?['key_id'] as String?);

      if (internalOrderId == null) {
        throw Exception('Order creation failed — no order ID returned');
      }
      if (razorpayOrderId == null || razorpayOrderId.isEmpty) {
        throw Exception(
            'Razorpay order not created. Check Razorpay gateway configuration.');
      }
      if (razorpayKey == null || razorpayKey.isEmpty) {
        throw Exception('Razorpay key not found');
      }

      // Step 3: set up callbacks — order already placed, just verify on success
      _razorpayService.onSuccess = (PaymentSuccessResponse response) async {
        try {
          await _checkoutService.verifyPayment(
            orderId: internalOrderId,
            razorpayPaymentId: response.paymentId,
            razorpayOrderId: response.orderId,
            razorpaySignature: response.signature,
          );

          try {
            await _cartService.clearCart();
          } catch (_) {}

          if (mounted) {
            Navigator.pushNamed(
              context,
              '/order-success',
              arguments: {
                'orderNumber': orderNumber,
                'totalAmount': _total,
                'estimatedDelivery': 'Mon, Aug 24',
              },
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Payment verification failed: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        } finally {
          if (mounted) {
            setState(() {
              _isPlacingOrder = false;
            });
          }
        }
      };

      _razorpayService.onError = (PaymentFailureResponse response) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text(_razorpayService.getErrorMessage(response.code ?? 0)),
              backgroundColor: Colors.red,
            ),
          );
          setState(() {
            _isPlacingOrder = false;
          });
        }
      };

      _razorpayService.onExternalWallet = (ExternalWalletResponse response) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('External wallet selected: ${response.walletName}'),
            ),
          );
        }
      };

      // Step 4: open Razorpay checkout with the server-created order ID
      final amountInPaise = (_total * 100).toInt();
      final customerPhone = widget.selectedAddress['phone']?.toString() ?? '';
      final customerEmail = widget.selectedAddress['email']?.toString() ?? '';

      _razorpayService.openCheckout(
        amount: amountInPaise,
        key: razorpayKey,
        orderId: razorpayOrderId,
        name: businessName,
        description: 'Order Payment',
        prefillContact: customerPhone,
        prefillEmail: customerEmail,
        themeColor: themeColor,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment initialization failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isPlacingOrder = false;
        });
      }
    }
  }

  Future<void> _processStripePayment({
    required int shippingAddressId,
    int? billingAddressId,
    String? shippingMethodCode,
    String? notes,
  }) async {
    try {
      // First, set the payment method to get gateway configuration
      final paymentMethodData = await _checkoutService.setPaymentMethod(
        'stripe',
        shippingAddressId: shippingAddressId,
        shippingMethodCode: shippingMethodCode,
      );

      final gatewayConfig =
          paymentMethodData['gateway_config'] as Map<String, dynamic>?;

      if (gatewayConfig == null) {
        throw Exception('Gateway configuration not available for Stripe');
      }

      // Try multiple possible key names for publishable key
      final publishableKey = gatewayConfig['publishable_key'] as String? ??
          gatewayConfig['key'] as String? ??
          gatewayConfig['stripe_key'] as String? ??
          gatewayConfig['public_key'] as String?;

      // Try multiple possible key names for client secret
      final clientSecret = gatewayConfig['client_secret'] as String? ??
          gatewayConfig['payment_intent_client_secret'] as String?;

      final merchantName = gatewayConfig['name'] as String? ??
          gatewayConfig['merchant_name'] as String? ??
          MobileAppSettingsScope.of(context).settings.appName;

      if (publishableKey == null || publishableKey.isEmpty) {
        throw Exception(
            'Stripe publishable key not found in gateway configuration. Available keys: ${gatewayConfig.keys.join(", ")}');
      }

      if (clientSecret == null || clientSecret.isEmpty) {
        throw Exception(
            'Payment intent client secret not found. Backend must create a Payment Intent and return the client_secret.');
      }

      // Initialize Stripe with publishable key
      await _stripeService.initialize(publishableKey);

      // Small delay to ensure Stripe SDK is fully initialized
      await Future.delayed(const Duration(milliseconds: 300));

      // Setup Stripe callbacks
      _stripeService.onSuccess = (String paymentIntentId) async {
        try {
          // placeOrder first (same pattern as Razorpay/PhonePe)
          final result = await _checkoutService.placeOrder(
            shippingAddressId: shippingAddressId,
            billingAddressId: billingAddressId,
            shippingMethodCode: shippingMethodCode,
            paymentMethod: 'stripe',
            notes: notes,
            paymentId: paymentIntentId,
          );

          final internalOrderId = (result['order_id'] as num?)?.toInt() ??
              (result['id'] as num?)?.toInt();
          final orderNumber = result['order_number'] ??
              '#VX-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

          if (internalOrderId != null) {
            await _checkoutService.verifyPayment(
              orderId: internalOrderId,
              paymentIntentId: paymentIntentId,
            );
          }

          try {
            await _cartService.clearCart();
          } catch (_) {}

          if (mounted) {
            Navigator.pushNamed(
              context,
              '/order-success',
              arguments: {
                'orderNumber': orderNumber,
                'totalAmount': _total,
                'estimatedDelivery': 'Mon, Aug 24',
              },
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Order placement failed: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        } finally {
          if (mounted) {
            setState(() {
              _isPlacingOrder = false;
            });
          }
        }
      };

      _stripeService.onError = (String errorMessage) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Payment failed: $errorMessage'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() {
            _isPlacingOrder = false;
          });
        }
      };

      _stripeService.onCancelled = () {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment cancelled'),
              backgroundColor: Colors.orange,
            ),
          );
          setState(() {
            _isPlacingOrder = false;
          });
        }
      };

      // Present Stripe payment sheet
      // Get billing address from checkout summary
      final billingAddressData =
          widget.billingAddress ?? widget.checkoutSummary['billing_address'];

      // Determine which address to use for billing
      Map<String, dynamic> addressToUse;

      if (billingAddressData is Map<String, dynamic>) {
        // Check if it's a flag indicating to use shipping address
        final useShippingAddress =
            billingAddressData['use_shipping_address'] == true;

        // Check if billing address has street address (try both field name formats)
        final hasAddress = (billingAddressData['address1']?.toString() ??
                billingAddressData['address_line1']?.toString() ??
                billingAddressData['address_line_1']?.toString() ??
                '')
            .isNotEmpty;

        if (useShippingAddress || !hasAddress) {
          // Backend says to use shipping address OR billing address is incomplete
          addressToUse = widget.selectedAddress;
        } else {
          // Use the billing address from checkout summary
          addressToUse = billingAddressData;
        }
      } else {
        // No billing address in summary, use shipping address
        addressToUse = widget.selectedAddress;
      }

      // Map the address fields - API uses different field names (address1, address_line1, or address_line_1)
      final customerEmail = addressToUse['email']?.toString() ??
          widget.selectedAddress['email']?.toString();
      final customerName = (addressToUse['full_name']?.toString() ??
          '${addressToUse['first_name'] ?? ''} ${addressToUse['last_name'] ?? ''}'
              .trim());
      final customerPhone = addressToUse['phone']?.toString();
      final addressLine1 = addressToUse['address1']?.toString() ??
          addressToUse['address_line1']?.toString() ??
          addressToUse['address_line_1']?.toString();
      final addressLine2 = addressToUse['address2']?.toString() ??
          addressToUse['address_line2']?.toString() ??
          addressToUse['address_line_2']?.toString();
      final city = addressToUse['city']?.toString();
      final state = addressToUse['state']?.toString();
      final postalCode = addressToUse['zip_code']?.toString() ??
          addressToUse['postal_code']?.toString() ??
          addressToUse['zipcode']?.toString();
      final country = addressToUse['country']?.toString() ?? 'IN';

      // Validate required fields for Indian regulations
      if (customerName.isEmpty) {
        throw Exception(
            'Customer name is required. Please update your address.');
      }
      if (addressLine1 == null || addressLine1.isEmpty) {
        throw Exception(
            'Street address is required. Please update your address with complete street address.');
      }
      if (city == null || city.isEmpty) {
        throw Exception('City is required. Please update your address.');
      }
      if (postalCode == null || postalCode.isEmpty) {
        throw Exception(
            'Postal/ZIP code is required. Please update your address with postal code.');
      }

      await _stripeService.presentPaymentSheet(
        clientSecret: clientSecret,
        merchantDisplayName: merchantName,
        customerEmail: customerEmail,
        customerName: customerName,
        phone: customerPhone,
        addressLine1: addressLine1,
        addressLine2: addressLine2,
        city: city,
        state: state,
        postalCode: postalCode,
        country: country,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment initialization failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isPlacingOrder = false;
        });
      }
    }
  }

  Future<void> _processPhonePePayment({
    required int shippingAddressId,
    int? billingAddressId,
    String? shippingMethodCode,
    String? notes,
  }) async {
    try {
      // 1. Request PhonePe's configured environment for the mobile SDK.
      final paymentMethodData =
          await _checkoutService.setPaymentMethod('phonepe');
      final gatewayConfig =
          paymentMethodData['gateway_config'] as Map<String, dynamic>?;
      final envString =
          (gatewayConfig?['environment'] as String?)?.toUpperCase() ?? 'UAT';
      final sdkEnvironment = (envString == 'PRODUCTION')
          ? PhonePeEnvironment.production
          : PhonePeEnvironment.sandbox;

      // 2. Place the order first — the backend creates a PhonePe order linked
      //    to this internal order and returns the authoritative token.
      final orderResult = await _checkoutService.placeOrder(
        shippingAddressId: shippingAddressId,
        billingAddressId: billingAddressId,
        shippingMethodCode: shippingMethodCode,
        paymentMethod: 'phonepe',
        notes: notes,
      );

      final internalOrderId = (orderResult['id'] as num?)?.toInt() ??
          (orderResult['order_id'] as num?)?.toInt();

      final merchantId = (orderResult['merchant_id'] as String?) ?? '';
      final orderToken = (orderResult['phonepe_token'] as String?) ?? '';
      final phonePeOrderId = (orderResult['phonepe_order_id'] as String?) ?? '';

      if (merchantId.isEmpty || orderToken.isEmpty || phonePeOrderId.isEmpty) {
        throw Exception('PhonePe credentials missing from placeOrder response. '
            'Please ensure PhonePe is configured in the admin panel.');
      }

      // 3. Initialise the PhonePe SDK.
      await _phonePeService.initialize(
        merchantId: merchantId,
        environment: sdkEnvironment,
        enableLogging: true,
      );

      // 4. Launch the PhonePe payment sheet.
      final phonePeResult = await _phonePeService.startTransaction(
        orderId: phonePeOrderId,
        merchantId: merchantId,
        token: orderToken,
      );

      if (phonePeResult.isCancelled) {
        // Order exists in pending state — user can retry from order history.
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PhonePe payment was cancelled.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      if (!phonePeResult.isSuccess) {
        throw Exception(
            phonePeResult.errorMessage ?? 'PhonePe payment failed.');
      }

      // 5. Verify payment server-side with the internal order_id.
      if (internalOrderId != null) {
        await _checkoutService.verifyPayment(
          orderId: internalOrderId,
          transactionId: phonePeResult.transactionId,
        );
      }

      // 6. Clear cart (best-effort) and navigate to success.
      try {
        await _cartService.clearCart();
      } catch (_) {}

      final orderNumber = orderResult['order_number'] ??
          '#VX-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

      if (mounted) {
        Navigator.pushNamed(
          context,
          '/order-success',
          arguments: {
            'orderNumber': orderNumber,
            'totalAmount': _total,
            'estimatedDelivery': 'Mon, Aug 24',
          },
        );
      }
    } catch (e) {
      if (mounted) {
        final message = e is MissingPluginException
            ? 'PhonePe SDK is not ready. Please reinstall the app.'
            : 'PhonePe payment failed: $e';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPlacingOrder = false;
        });
      }
    }
  }

  // ─────────────────────────────────────────────────────────── PayPal ──

  Future<void> _processPayPalPayment({
    required int shippingAddressId,
    int? billingAddressId,
    String? shippingMethodCode,
    String? notes,
  }) async {
    try {
      // 1. Place order first — backend creates PayPal Order (v2) and returns
      //    paypal_order_id + approve_url.
      final orderResult = await _checkoutService.placeOrder(
        shippingAddressId: shippingAddressId,
        billingAddressId: billingAddressId,
        shippingMethodCode: shippingMethodCode,
        paymentMethod: 'paypal',
        notes: notes,
      );

      final internalOrderId = (orderResult['order_id'] as num?)?.toInt() ??
          (orderResult['id'] as num?)?.toInt();

      final paypalOrderId = orderResult['paypal_order_id'] as String?;
      final approveUrl = orderResult['approve_url'] as String?;

      if (paypalOrderId == null || approveUrl == null) {
        throw Exception('PayPal order details missing from server response. '
            'Please ensure PayPal is configured in the admin panel.');
      }

      // 2. Open PayPal WebView — user logs in and approves payment.
      if (!mounted) return;
      final paypalResult = await _paypalService.launchCheckout(
        context: context,
        approveUrl: approveUrl,
      );

      if (paypalResult.isCancelled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PayPal payment was cancelled.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      if (!paypalResult.isSuccess) {
        throw Exception(paypalResult.errorMessage ?? 'PayPal payment failed.');
      }

      // 3. Verify payment — backend CAPTURES the PayPal order and marks it paid.
      if (internalOrderId != null) {
        await _checkoutService.verifyPayment(
          orderId: internalOrderId,
          // Prefer the token echoed back by PayPal; fall back to the ID we got
          // from placeOrder (they are the same value).
          paypalOrderId: paypalResult.paypalOrderId?.isNotEmpty == true
              ? paypalResult.paypalOrderId
              : paypalOrderId,
        );
      }

      // 4. Clear cart (best-effort) and navigate to success screen.
      try {
        await _cartService.clearCart();
      } catch (_) {}

      final orderNumber = orderResult['order_number'] ??
          '#VX-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

      if (mounted) {
        Navigator.pushNamed(
          context,
          '/order-success',
          arguments: {
            'orderNumber': orderNumber,
            'totalAmount': _total,
            'estimatedDelivery': 'Mon, Aug 24',
          },
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PayPal payment failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPlacingOrder = false;
        });
      }
    }
  }

  Future<void> _placeManualTransferOrder({
    required int shippingAddressId,
    int? billingAddressId,
    String? shippingMethodCode,
    required String paymentMethod,
    String? notes,
  }) async {
    if (_manualDestinations.isEmpty) {
      throw Exception('No active manual transfer account is configured.');
    }
    if (_selectedManualDestinationId == null) {
      throw Exception('Select a bank or mobile-wallet account.');
    }
    if (_manualPaymentProof == null) {
      throw Exception('Choose a receipt image before submitting the order.');
    }

    // Keep the order response so a failed upload can be retried without
    // creating a second order from this screen.
    _createdManualOrder ??= await () async {
      await _checkoutService.setPaymentMethod(paymentMethod);
      return _checkoutService.placeOrder(
        shippingAddressId: shippingAddressId,
        billingAddressId: billingAddressId,
        shippingMethodCode: shippingMethodCode,
        paymentMethod: paymentMethod,
        notes: notes,
      );
    }();

    final orderId = (_createdManualOrder!['order_id'] as num?)?.toInt() ??
        (_createdManualOrder!['id'] as num?)?.toInt();
    if (orderId == null) {
      throw Exception('Order was created but no order ID was returned.');
    }

    await _checkoutService.submitManualPayment(
      orderId: orderId,
      destinationId: _selectedManualDestinationId!,
      proof: _manualPaymentProof!,
      transferReference: _transferReferenceController.text,
    );

    try {
      await _cartService.clearCart();
    } catch (_) {}

    if (mounted) {
      Navigator.pushNamed(
        context,
        '/order-success',
        arguments: {
          'orderNumber':
              _createdManualOrder!['order_number'] ?? 'Order $orderId',
          'totalAmount': _total,
          'estimatedDelivery': 'Pending payment review',
          'paymentPending': true,
          'paymentStatusMessage':
              'Your transfer receipt was submitted. Staff will verify the transfer before confirming payment.',
        },
      );
    }
  }

  Future<void> _placeOrderDirect({
    required int shippingAddressId,
    int? billingAddressId,
    String? shippingMethodCode,
    required String paymentMethod,
    String? notes,
  }) async {
    try {
      // Validate the configured method before creating the order.
      await _checkoutService.setPaymentMethod(paymentMethod);

      // Place the order via API
      final result = await _checkoutService.placeOrder(
        shippingAddressId: shippingAddressId,
        billingAddressId: billingAddressId,
        shippingMethodCode: shippingMethodCode,
        paymentMethod: paymentMethod,
        notes: notes,
      );

      final orderNumber = result['order_number'] ??
          '#VX-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

      // Backend already clears cart items in placeOrder; treat clear as best-effort
      // so a post-order cart call cannot block success navigation.
      try {
        await _cartService.clearCart();
      } catch (_) {}

      // Navigate to success screen
      if (mounted) {
        Navigator.pushNamed(
          context,
          '/order-success',
          arguments: {
            'orderNumber': orderNumber,
            'totalAmount': _total,
            'estimatedDelivery': 'Mon, Aug 24',
            'paymentPending': paymentMethod == 'cod',
            'paymentStatusMessage': paymentMethod == 'cod'
                ? 'Payment is due when your order is delivered.'
                : null,
          },
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPlacingOrder = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? AppColors.darkText : const Color(0xFF0F172A);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      body: Stack(
        children: [
          // Main scrollable content
          CustomScrollView(
            slivers: [
              // App Bar
              SliverAppBar(
                pinned: true,
                elevation: 0,
                backgroundColor: isDark
                    ? AppColors.backgroundDark.withOpacity(0.95)
                    : AppColors.backgroundLight.withOpacity(0.95),
                foregroundColor: titleColor,
                iconTheme: IconThemeData(color: titleColor),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
                title: Text(
                  'Review Order',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: titleColor,
                  ),
                ),
                centerTitle: true,
              ),

              // Content
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 180),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Progress Steps
                      _buildProgressSteps(isDark),

                      const SizedBox(height: 24),

                      _buildCartItemsSection(isDark),
                      const SizedBox(height: 24),
                      _buildShippingPaymentSection(isDark),
                      if (_isManualTransfer) ...[
                        const SizedBox(height: 16),
                        _buildManualTransferSection(isDark),
                      ],
                      const SizedBox(height: 24),
                      _buildOrderNotesSection(isDark),
                      const SizedBox(height: 24),
                      _buildOrderSummarySection(isDark),
                    ],
                  ),
                ),
              ),
            ],
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildProgressSteps(bool isDark) {
    return Column(
      children: [
        // Tab Labels
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Shipping',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primary,
                ),
              ),
              Text(
                'Payment',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primary,
                ),
              ),
              Text(
                'Review',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Progress Bar
        Container(
          height: 6,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            borderRadius: BorderRadius.circular(3),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: 1.0, // 3/3 progress - completed
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Step indicator
        Text(
          'Step 3 of 3',
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildCartItemsSection(bool isDark) {
    final titleColor = isDark ? AppColors.darkText : const Color(0xFF0F172A);
    final mutedColor =
        isDark ? AppColors.darkTextSecondary : Colors.grey.shade600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Items in your cart',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: titleColor,
          ),
        ),
        const SizedBox(height: 12),
        if (_isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_cartItems.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text(
                'No items in cart',
                style: TextStyle(color: mutedColor),
              ),
            ),
          )
        else
          ..._cartItems.map((item) => _buildCartItem(item, isDark)).toList(),
      ],
    );
  }

  Widget _buildCartItem(Map<String, dynamic> item, bool isDark) {
    final product = item['product'] ?? {};
    final productName = product['name'] ?? item['name'] ?? 'Product';
    final productImage = product['image_url'] ?? item['image'] ?? '';
    final quantity = item['quantity'] ?? 1;
    final variant = item['variant'];
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor =
        isDark ? AppColors.darkDivider : const Color(0xFFF1F1F1);
    final titleColor = isDark ? AppColors.darkText : const Color(0xFF0F172A);
    final mutedColor =
        isDark ? AppColors.darkTextSecondary : Colors.grey.shade600;
    final chipBg = isDark ? const Color(0xFF334155) : const Color(0xFFF1F1F1);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 70,
              height: 70,
              color: isDark ? const Color(0xFF334155) : Colors.grey[200],
              child: productImage.isNotEmpty
                  ? Image.network(
                      productImage,
                      fit: BoxFit.cover,
                      width: 70,
                      height: 70,
                      errorBuilder: (_, __, ___) =>
                          Icon(Icons.image, color: mutedColor),
                    )
                  : Icon(Icons.image, color: mutedColor),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  productName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: titleColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: chipBg,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Qty: $quantity',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: titleColor,
                        ),
                      ),
                    ),
                    if (variant != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        'Size: ${variant['size'] ?? ''} • ${variant['color'] ?? ''}',
                        style: TextStyle(
                          fontSize: 12,
                          color: mutedColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          StyledPriceText(
            amount: (item['price'] as num?)?.toDouble() ?? 0.0,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildShippingPaymentSection(bool isDark) {
    final titleColor = isDark ? AppColors.darkText : const Color(0xFF0F172A);
    final mutedColor =
        isDark ? AppColors.darkTextSecondary : Colors.grey.shade600;
    final chipBg = isDark ? const Color(0xFF334155) : const Color(0xFFF1F1F1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Shipping & Payment',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: titleColor,
          ),
        ),
        const SizedBox(height: 12),
        _buildInfoCard(
          isDark: isDark,
          icon: Icons.location_on,
          title: 'SHIPPING ADDRESS',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.selectedAddress['name'] ?? 'Shipping Address',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: titleColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${widget.selectedAddress['address'] ?? ''}\n${widget.selectedAddress['city'] ?? ''}, ${widget.selectedAddress['state'] ?? ''} ${widget.selectedAddress['postal_code'] ?? ''}',
                style: TextStyle(
                  fontSize: 14,
                  color: mutedColor,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _buildInfoCard(
          isDark: isDark,
          icon: Icons.receipt_long,
          title: 'BILLING ADDRESS',
          child: Text(
            'Same as shipping address',
            style: TextStyle(
              fontSize: 14,
              color: mutedColor,
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildInfoCard(
          isDark: isDark,
          icon: Icons.local_shipping,
          title: 'SHIPPING METHOD',
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.selectedShippingMethod['name'] ??
                          'Standard Shipping',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.selectedShippingMethod['description'] ??
                          'Delivery information',
                      style: TextStyle(
                        fontSize: 12,
                        color: mutedColor,
                      ),
                    ),
                  ],
                ),
              ),
              StyledPriceText(
                amount: (widget.checkoutSummary['shipping_cost'] as num?)
                        ?.toDouble() ??
                    0.0,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: titleColor,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _buildInfoCard(
          isDark: isDark,
          icon: Icons.credit_card,
          title: 'PAYMENT METHOD',
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: chipBg,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  (widget.selectedPaymentMethod['code'] ?? 'PAYMENT')
                      .toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? AppColors.primaryLight
                        : const Color(0xFF1A1F71),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.selectedPaymentMethod['name'] ??
                      'Selected payment method',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: titleColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildManualTransferSection(bool isDark) {
    final destinations = _manualDestinations;
    final instructions =
        widget.selectedPaymentMethod['instructions']?.toString() ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkDivider : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Manual transfer details',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            instructions.isEmpty
                ? 'Transfer the exact order total to one of the accounts below, then submit a receipt. Payment remains pending until staff verify it.'
                : '$instructions Payment remains pending until staff verify your receipt.',
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 12),
          if (destinations.isEmpty)
            const Text(
              'No active transfer account is configured. Choose another payment method.',
              style: TextStyle(color: Colors.red),
            )
          else
            ...destinations.map((destination) {
              final id = destination['id']?.toString() ?? '';
              return RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                value: id,
                groupValue: _selectedManualDestinationId,
                onChanged: (value) => setState(() {
                  _selectedManualDestinationId = value;
                }),
                title: Text(
                  destination['label']?.toString() ??
                      destination['provider']?.toString() ??
                      'Transfer account',
                ),
                subtitle: Text(
                  '${destination['provider'] ?? ''}\n'
                  'Account name: ${destination['account_name'] ?? '—'}\n'
                  'Account number: ${destination['account_number'] ?? '—'}'
                  '${(destination['instructions']?.toString().isNotEmpty ?? false) ? '\n${destination['instructions']}' : ''}',
                ),
              );
            }),
          const SizedBox(height: 8),
          TextField(
            controller: _transferReferenceController,
            maxLength: 150,
            decoration: const InputDecoration(
              labelText: 'Transfer reference (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _isPlacingOrder || _createdManualOrder != null
                ? null
                : _pickManualPaymentProof,
            icon: const Icon(Icons.upload_file),
            label: Text(_createdManualOrder != null
                ? 'Receipt attached to this order'
                : _manualPaymentProof == null
                    ? 'Choose receipt image'
                    : 'Change receipt image'),
          ),
          if (_manualPaymentProof != null) ...[
            const SizedBox(height: 6),
            Text(
              'Selected: ${_manualPaymentProof!.path.split(Platform.pathSeparator).last}',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
              ),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            'Accepted: JPG, PNG or WebP, up to 5 MB. A receipt is not payment confirmation.',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickManualPaymentProof() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 2048,
      maxHeight: 2048,
    );
    if (image == null || !mounted) return;

    final file = File(image.path);
    if (await file.length() > 5 * 1024 * 1024) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Receipt image must be 5 MB or smaller.')),
      );
      return;
    }
    if (mounted) setState(() => _manualPaymentProof = file);
  }

  Widget _buildInfoCard({
    required bool isDark,
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor =
        isDark ? AppColors.darkDivider : const Color(0xFFF1F1F1);
    final labelColor =
        isDark ? AppColors.darkTextSecondary : Colors.grey.shade500;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    icon,
                    size: 20,
                    color: labelColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: labelColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () {
                  // Handle edit action
                },
                child: Text(
                  'Edit',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(left: 28),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildOrderNotesSection(bool isDark) {
    final titleColor = isDark ? AppColors.darkText : const Color(0xFF0F172A);
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor =
        isDark ? AppColors.darkDivider : const Color(0xFFF1F1F1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Order Notes',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: titleColor,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: _notesController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Add a note to your order (optional)',
              hintStyle: TextStyle(
                color: isDark ? AppColors.darkTextSecondary : Colors.grey[400],
                fontSize: 14,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
            ),
            style: TextStyle(
              fontSize: 14,
              color: titleColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOrderSummarySection(bool isDark) {
    final titleColor = isDark ? AppColors.darkText : const Color(0xFF0F172A);
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor =
        isDark ? AppColors.darkDivider : const Color(0xFFF1F1F1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Order Summary',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: titleColor,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildSummaryRow('Subtotal', _subtotal, isDark: isDark),
              const SizedBox(height: 12),
              _buildSummaryRow('Shipping', _shipping, isDark: isDark),
              const SizedBox(height: 12),
              _buildSummaryRow('Tax (Estimated)', _tax, isDark: isDark),
              const SizedBox(height: 12),
              _buildSummaryRow(
                'Discount (SummerSale)',
                -_discount,
                isDark: isDark,
                color: const Color(0xFF10B981),
              ),
              const SizedBox(height: 16),
              Container(
                height: 1,
                color: borderColor,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: titleColor,
                    ),
                  ),
                  StyledPriceText(
                    amount: _total,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: titleColor,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(
    String label,
    double value, {
    required bool isDark,
    Color? color,
  }) {
    final mutedColor =
        isDark ? AppColors.darkTextSecondary : Colors.grey.shade600;
    final valueColor = isDark ? AppColors.darkText : const Color(0xFF0F172A);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: color ?? mutedColor,
            fontWeight: color != null ? FontWeight.w500 : FontWeight.normal,
          ),
        ),
        StyledPriceText(
          amount: value,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: color ?? valueColor,
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          border: Border(
            top: BorderSide(
              color: isDark ? AppColors.darkDivider : const Color(0xFFE2E8F0),
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
              blurRadius: 8,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isPlacingOrder ? null : _placeOrder,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isPlacingOrder)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  else
                    Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _isManualTransfer
                                ? (_createdManualOrder == null
                                    ? 'Submit Transfer Proof'
                                    : 'Retry Proof Upload')
                                : 'Place Order',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 16),
                          StyledPriceText(
                            amount: _total,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
