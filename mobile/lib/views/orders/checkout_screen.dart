import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/item_model.dart';
import '../../models/order_model.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/order_repository.dart';
import '../../theme/app_theme.dart';
import 'order_detail_screen.dart';

class CheckoutScreen extends StatefulWidget {
  final ItemModel product;

  const CheckoutScreen({super.key, required this.product});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final OrderRepository _orderRepo = RestOrderRepository();

  List<SafeZoneModel> _safeZones = [];
  String _selectedSafeZoneId = 'safe-zone-akl-police';
  bool _isCustomLocation = false;
  final TextEditingController _customAddressController = TextEditingController();

  DateTime _scheduledDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _scheduledTime = const TimeOfDay(hour: 14, minute: 0);

  bool _loading = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSafeZones();
  }

  Future<void> _loadSafeZones() async {
    final zones = await _orderRepo.getSafeZones();
    if (mounted) {
      setState(() {
        _safeZones = zones;
        if (zones.isNotEmpty) {
          _selectedSafeZoneId = zones.first.id;
        }
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _customAddressController.dispose();
    super.dispose();
  }

  Future<void> _handlePayAndEscrow() async {
    setState(() {
      _submitting = true;
      _error = null;
    });

    final auth = context.read<AuthProvider>();
    final selectedZone = _safeZones.firstWhere(
      (z) => z.id == _selectedSafeZoneId,
      orElse: () => _safeZones.isNotEmpty
          ? _safeZones.first
          : const SafeZoneModel(
              id: 'safe-zone-akl-police',
              name: 'Auckland Central Police Station Safe Trading Zone',
              category: 'police_station',
              address: '13-15 Cook Street, Auckland CBD',
              suburb: 'Auckland CBD',
              city: 'Auckland',
              latitude: -36.8524,
              longitude: 174.7618,
              features: ['24/7 CCTV Monitored'],
              operatingHours: '24 Hours',
            ),
    );

    final meetingLocation = _isCustomLocation
        ? {
            'name': _customAddressController.text.trim().isNotEmpty
                ? _customAddressController.text.trim()
                : 'Custom Meetup Address',
            'address': _customAddressController.text.trim(),
          }
        : {
            'name': selectedZone.name,
            'address': selectedZone.address,
            'latitude': selectedZone.latitude,
            'longitude': selectedZone.longitude,
          };

    final scheduledIso = DateTime(
      _scheduledDate.year,
      _scheduledDate.month,
      _scheduledDate.day,
      _scheduledTime.hour,
      _scheduledTime.minute,
    ).toIso8601String();

    try {
      // 1. Initiate Checkout
      final checkoutRes = await _orderRepo.checkout(
        itemId: widget.product.id,
        meetingLocation: meetingLocation,
        scheduledAt: scheduledIso,
        token: auth.token,
        userId: auth.user?.id,
      );

      final orderMap = checkoutRes['order'] as Map<String, dynamic>;
      final orderId = (orderMap['_id'] ?? orderMap['id']).toString();

      // 2. Authorize & Escrow Payment
      final payRes = await _orderRepo.payOrder(
        orderId,
        token: auth.token,
        userId: auth.user?.id,
      );

      final updatedOrderMap = payRes['order'] as Map<String, dynamic>;
      final handoverMap = payRes['handover'] is Map ? payRes['handover'] as Map<String, dynamic> : null;
      final orderModel = OrderModel.fromMap(
        updatedOrderMap,
        handover: handoverMap != null ? HandoverInfo.fromMap(handoverMap) : null,
      );

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => OrderDetailScreen(orderId: orderModel.id, initialOrder: orderModel),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception:', '').trim();
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final itemPrice = widget.product.numericPrice;
    final standardFee = (itemPrice * 0.01);
    final feeDiscount = standardFee; // 100% Launch Early-bird waiver
    final buyerTotal = itemPrice;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Secure Escrow Checkout'),
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Step 1: Meetup Safe Zone
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
                              CircleAvatar(
                                radius: 12,
                                backgroundColor: colors.primary,
                                child: const Text(
                                  '1',
                                  style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Text(
                                'Select Safe Meetup Location',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          const Text(
                            'Official Safe Trading Zones feature 24/7 CCTV surveillance and security staff.',
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: AppSpacing.md),

                          // List Safe Zones
                          ..._safeZones.map((zone) {
                            final isSelected = !_isCustomLocation && _selectedSafeZoneId == zone.id;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    _isCustomLocation = false;
                                    _selectedSafeZoneId = zone.id;
                                  });
                                },
                                borderRadius: BorderRadius.circular(AppRadius.medium),
                                child: Container(
                                  padding: const EdgeInsets.all(AppSpacing.sm),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(AppRadius.medium),
                                    border: Border.all(
                                      color: isSelected ? colors.primary : colors.outlineVariant,
                                      width: isSelected ? 2 : 1,
                                    ),
                                    color: isSelected ? const Color(0xFFF0FDF4) : colors.surface,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.shield_outlined,
                                        color: isSelected ? const Color(0xFF16A34A) : colors.primary,
                                        size: 20,
                                      ),
                                      const SizedBox(width: AppSpacing.sm),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              zone.name,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                            ),
                                            Text(
                                              zone.address,
                                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (isSelected)
                                        const Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 18),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // Step 2: Schedule Meetup
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
                              CircleAvatar(
                                radius: 12,
                                backgroundColor: colors.primary,
                                child: const Text(
                                  '2',
                                  style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Text(
                                'Meetup Date & Time',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: _scheduledDate,
                                      firstDate: DateTime.now(),
                                      lastDate: DateTime.now().add(const Duration(days: 30)),
                                    );
                                    if (picked != null) {
                                      setState(() => _scheduledDate = picked);
                                    }
                                  },
                                  icon: const Icon(Icons.calendar_today, size: 16),
                                  label: Text('${_scheduledDate.day}/${_scheduledDate.month}/${_scheduledDate.year}'),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    final picked = await showTimePicker(
                                      context: context,
                                      initialTime: _scheduledTime,
                                    );
                                    if (picked != null) {
                                      setState(() => _scheduledTime = picked);
                                    }
                                  },
                                  icon: const Icon(Icons.access_time, size: 16),
                                  label: Text(_scheduledTime.format(context)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // Step 3: Transparent Escrow Summary
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
                            'Escrow Payment & Fee Breakdown',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Item Price:'),
                              Text('\$${itemPrice.toStringAsFixed(2)} NZD', style: const TextStyle(fontWeight: FontWeight.w600)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Service Fee (1.0%):'),
                              Text(
                                '+\$${standardFee.toStringAsFixed(2)}',
                                style: const TextStyle(decoration: TextDecoration.lineThrough, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Launch Special (100% OFF):', style: TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.bold)),
                              Text('-\$${feeDiscount.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const Divider(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Total Escrow Deposit:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              Text(
                                '\$${buyerTotal.toStringAsFixed(2)} NZD',
                                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: colors.primary),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFBBF7D0)),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.shield, color: Color(0xFF16A34A), size: 18),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Funds are held securely by KiwiShare Escrow and only released after you inspect and scan the QR code on-site.',
                                    style: TextStyle(fontSize: 11, color: Color(0xFF15803D)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      _error!,
                      style: const TextStyle(color: Colors.red, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ],

                  const SizedBox(height: AppSpacing.lg),

                  FilledButton(
                    key: const Key('checkout-confirm-pay-button'),
                    onPressed: _submitting ? null : _handlePayAndEscrow,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: AppColors.brandPrimary,
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Text(
                            'Authorize \$${buyerTotal.toStringAsFixed(2)} NZD & Hold in Escrow',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
