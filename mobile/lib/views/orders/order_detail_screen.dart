import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/order_model.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/order_repository.dart';
import '../../theme/app_theme.dart';

class OrderDetailScreen extends StatefulWidget {
  final String orderId;
  final OrderModel? initialOrder;

  const OrderDetailScreen({
    super.key,
    required this.orderId,
    this.initialOrder,
  });

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  final OrderRepository _orderRepo = RestOrderRepository();

  OrderModel? _order;
  String _userRole = 'buyer';
  HandoverInfo? _handover;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.initialOrder != null) {
      _order = widget.initialOrder;
      _handover = widget.initialOrder?.handover;
      _loading = false;
    }
    _fetchOrder();
  }

  Future<void> _fetchOrder() async {
    final auth = context.read<AuthProvider>();
    try {
      final res = await _orderRepo.getOrderById(
        widget.orderId,
        token: auth.token,
        userId: auth.user?.id,
      );
      if (mounted) {
        final orderMap = res['order'] as Map<String, dynamic>;
        final handoverMap = res['handover'] is Map ? res['handover'] as Map<String, dynamic> : null;
        setState(() {
          _userRole = (res['userRole'] ?? 'buyer').toString();
          _handover = handoverMap != null ? HandoverInfo.fromMap(handoverMap) : null;
          _order = OrderModel.fromMap(orderMap, handover: _handover);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted && _order == null) {
        setState(() {
          _error = e.toString().replaceAll('Exception:', '').trim();
          _loading = false;
        });
      }
    }
  }

  void _showVerifyModal() {
    final pinController = TextEditingController();
    bool verifying = false;
    String? modalError;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Text('Verify Handover'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Enter the 6-digit PIN shown on the buyer\'s screen to confirm handover and release escrow payment.',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: pinController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 4),
                  decoration: const InputDecoration(
                    hintText: '482910',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (modalError != null) ...[
                  const SizedBox(height: 8),
                  Text(modalError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: verifying
                    ? null
                    : () async {
                        final pin = pinController.text.trim();
                        if (pin.isEmpty) return;
                        setDialogState(() {
                          verifying = true;
                          modalError = null;
                        });
                        final auth = context.read<AuthProvider>();
                        try {
                          await _orderRepo.verifyHandover(
                            widget.orderId,
                            claimCode: pin,
                            qrToken: pin,
                            token: auth.token,
                            userId: auth.user?.id,
                          );
                          if (mounted) {
                            Navigator.of(dialogCtx).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Handover verified! Escrow funds released to seller.'),
                                backgroundColor: Color(0xFF16A34A),
                              ),
                            );
                            _fetchOrder();
                          }
                        } catch (e) {
                          setDialogState(() {
                            modalError = e.toString().replaceAll('Exception:', '').trim();
                            verifying = false;
                          });
                        }
                      },
                child: verifying
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Confirm Handover'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Order Escrow Hub')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null || _order == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Order Escrow Hub')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: AppSpacing.sm),
                Text(_error ?? 'Order not found.'),
              ],
            ),
          ),
        ),
      );
    }

    final order = _order!;
    final isBuyer = _userRole == 'buyer';
    final isCompleted = order.isCompleted;

    return Scaffold(
      appBar: AppBar(
        title: Text('Order #${order.orderNumber}'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Banner
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: isCompleted ? const Color(0xFFF0FDF4) : const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(AppRadius.medium),
                border: Border.all(
                  color: isCompleted ? const Color(0xFFBBF7D0) : const Color(0xFFBFDBFE),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isCompleted ? Icons.check_circle : Icons.shield_outlined,
                    color: isCompleted ? const Color(0xFF16A34A) : const Color(0xFF2563EB),
                    size: 28,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isCompleted
                              ? 'Handover Completed & Settled'
                              : 'Funds Protected in Escrow',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: isCompleted ? const Color(0xFF15803D) : const Color(0xFF1D4ED8),
                          ),
                        ),
                        Text(
                          isCompleted
                              ? 'The item handover was verified and escrow payment was released.'
                              : isBuyer
                                  ? 'Show your QR code / PIN to the seller during meetup after inspecting item.'
                                  : 'Buyer has paid. Verify their PIN to receive payout.',
                          style: TextStyle(
                            fontSize: 12,
                            color: isCompleted ? const Color(0xFF166534) : const Color(0xFF1E40AF),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // Buyer QR / PIN Card OR Seller Action Card
            if (isCompleted)
              Card(
                elevation: 0,
                color: const Color(0xFFF0FDF4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.medium),
                  side: const BorderSide(color: Color(0xFFBBF7D0)),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    children: [
                      Icon(Icons.verified, color: Color(0xFF16A34A), size: 48),
                      SizedBox(height: 8),
                      Text(
                        'Transaction Completed',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF15803D)),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Escrow payout released successfully.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF166534)),
                      ),
                    ],
                  ),
                ),
              )
            else if (isBuyer)
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.medium),
                  side: BorderSide(color: colors.primary, width: 2),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    children: [
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.qr_code_2, color: Color(0xFF16A34A), size: 24),
                          SizedBox(width: 8),
                          Text(
                            'Buyer Handover Pass',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      const Text(
                        'Present this 6-digit PIN to the seller when you meet up:',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _handover?.claimCode ?? order.orderNumber.substring(order.orderNumber.length - 6),
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 6,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(width: 12),
                            IconButton(
                              icon: const Icon(Icons.copy, size: 20),
                              onPressed: () {
                                final pin = _handover?.claimCode ?? order.orderNumber.substring(order.orderNumber.length - 6);
                                Clipboard.setData(ClipboardData(text: pin));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('PIN copied to clipboard')),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.medium),
                  side: const BorderSide(color: Color(0xFFBFDBFE), width: 2),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    children: [
                      const Text(
                        'Meet Buyer & Confirm Handover',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Verify buyer\'s 6-digit PIN on-site to release \$${order.displaySellerPayoutNzd.toStringAsFixed(2)} NZD to your balance.',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      FilledButton.icon(
                        onPressed: _showVerifyModal,
                        icon: const Icon(Icons.qr_code_scanner),
                        label: const Text('Verify Buyer PIN / Handover'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.brandPrimary,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: AppSpacing.md),

            // Meetup Location Info
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.medium),
                side: BorderSide(color: colors.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.location_on, color: colors.primary, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Meetup Location & Schedule',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      order.locationName,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    if (order.scheduledAt != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Scheduled: ${order.scheduledAt!.day}/${order.scheduledAt!.month}/${order.scheduledAt!.year} at ${order.scheduledAt!.hour.toString().padLeft(2, '0')}:${order.scheduledAt!.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // Item Snapshot & Payment Summary
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.medium),
                side: BorderSide(color: colors.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text('Condition: ${order.condition}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Item Price:'),
                        Text('\$${order.displayPriceNzd.toStringAsFixed(2)} NZD'),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Service Fee (1.0%):'),
                        Text(
                          '+\$${(order.displayPriceNzd * 0.01).toStringAsFixed(2)}',
                          style: const TextStyle(decoration: TextDecoration.lineThrough, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Launch Special (100% OFF):', style: TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.bold)),
                        Text('-\$${(order.displayPriceNzd * 0.01).toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Escrow Deposit:', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(
                          '\$${order.displayTotalNzd.toStringAsFixed(2)} NZD',
                          style: TextStyle(fontWeight: FontWeight.w900, color: colors.primary, fontSize: 16),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
