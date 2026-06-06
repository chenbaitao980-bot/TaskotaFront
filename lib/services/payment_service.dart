import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants/app_constants.dart';
import '../core/utils/file_logger.dart';

class PaymentOrder {
  final String outTradeNo;
  final String qrCode;
  final String amount;
  final String subject;

  const PaymentOrder({
    required this.outTradeNo,
    required this.qrCode,
    required this.amount,
    required this.subject,
  });
}

enum PaymentStatus { pending, paid, closed, error }

class PaymentService {
  static final PaymentService _instance = PaymentService._();
  static PaymentService get instance => _instance;
  PaymentService._();

  final _client = Supabase.instance.client;

  Future<PaymentOrder> createOrder(String plan) async {
    final response = await _client.functions.invoke(
      'create-order',
      body: {'plan': plan},
    );

    if (response.status != 200) {
      final error = response.data?['error'] ?? '创建订单失败';
      throw Exception(error);
    }

    final data = response.data as Map<String, dynamic>;
    return PaymentOrder(
      outTradeNo: data['out_trade_no'] as String,
      qrCode: data['qr_code'] as String,
      amount: data['amount'] as String,
      subject: data['subject'] as String,
    );
  }

  Future<PaymentStatus> queryOrderStatus(String outTradeNo) async {
    final response = await _client.functions.invoke(
      'order-status',
      body: {'out_trade_no': outTradeNo},
    );

    if (response.status != 200) {
      return PaymentStatus.error;
    }

    final data = response.data as Map<String, dynamic>;
    final status = data['status'] as String?;
    switch (status) {
      case 'paid':
        return PaymentStatus.paid;
      case 'closed':
        return PaymentStatus.closed;
      default:
        return PaymentStatus.pending;
    }
  }

  Stream<PaymentStatus> pollOrderStatus(
    String outTradeNo, {
    Duration interval = const Duration(seconds: 3),
    Duration timeout = const Duration(minutes: 5),
  }) {
    final controller = StreamController<PaymentStatus>();
    Timer? timer;
    final stopwatch = Stopwatch()..start();

    void poll() async {
      if (controller.isClosed) return;

      try {
        final status = await queryOrderStatus(outTradeNo);
        if (!controller.isClosed) {
          controller.add(status);
          if (status == PaymentStatus.paid || status == PaymentStatus.closed) {
            timer?.cancel();
            controller.close();
            return;
          }
        }
      } catch (e) {
        flog('[Payment] poll error: $e');
        if (!controller.isClosed) {
          controller.add(PaymentStatus.error);
        }
      }

      if (stopwatch.elapsed > timeout) {
        timer?.cancel();
        if (!controller.isClosed) {
          controller.add(PaymentStatus.closed);
          controller.close();
        }
      }
    }

    timer = Timer.periodic(interval, (_) => poll());
    poll();

    controller.onCancel = () {
      timer?.cancel();
      stopwatch.stop();
    };

    return controller.stream;
  }
}
