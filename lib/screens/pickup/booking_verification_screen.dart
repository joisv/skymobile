import 'package:flutter/material.dart';
import '../../data/booking_repository.dart';
import '../../models/booking_model.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';

class BookingVerificationScreen extends StatefulWidget {
  final BookingModel? initialBooking;
  final BookingRepository repository;

  const BookingVerificationScreen({
    super.key,
    this.initialBooking,
    required this.repository,
  });

  @override
  State<BookingVerificationScreen> createState() => _BookingVerificationScreenState();
}

class _BookingVerificationScreenState extends State<BookingVerificationScreen> {
  BookingModel? _currentBooking;
  bool _isLoading = false;
  String? _errorMessage;

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  // Verification Checklist Items
  bool _isIdCardMatched = false;
  bool _isPhoneVerified = false;
  bool _isCollateralSecured = false;
  bool _isTermsAgreed = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialBooking != null) {
      _currentBooking = widget.initialBooking;
      _searchController.text = widget.initialBooking!.bookingCode;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  bool get _isAllVerified =>
      _isIdCardMatched && _isPhoneVerified && _isCollateralSecured && _isTermsAgreed;

  Future<void> _searchBooking(String code) async {
    final cleanCode = code.trim();
    if (cleanCode.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final found = await widget.repository.getBookingByCode(cleanCode);

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (found != null) {
        _currentBooking = found;
        _resetChecklist();
      } else {
        _errorMessage = 'Booking dengan kode "$cleanCode" tidak ditemukan.';
      }
    });
  }

  void _resetChecklist() {
    _isIdCardMatched = false;
    _isPhoneVerified = false;
    _isCollateralSecured = false;
    _isTermsAgreed = false;
    _notesController.clear();
  }

  void _proceedToPickup() {
    if (_currentBooking == null || !_isAllVerified) return;

    Navigator.pushNamed(
      context,
      AppRoutes.pickup,
      arguments: _currentBooking,
    );
  }

  void _showRejectDialog() {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626)),
            SizedBox(width: 8),
            Text('Tolak / Tunda Verifikasi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Masukkan alasan penolakan atau penundaan verifikasi untuk booking ${_currentBooking?.bookingCode}:',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Misal: Dokumen KTP tidak cocok, jaminan kurang lengkap...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Verifikasi booking ${_currentBooking?.bookingCode} ditunda: ${reasonController.text}'),
                  backgroundColor: const Color(0xFFDC2626),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            child: const Text('Simpan Penolakan'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Verifikasi Booking & Identitas'),
        actions: [
          IconButton(
            tooltip: 'Pindai QR Booking',
            icon: const Icon(Icons.qr_code_scanner_rounded),
            onPressed: () async {
              final result = await Navigator.pushNamed(context, AppRoutes.qrScanner);
              if (result is String && result.isNotEmpty) {
                _searchController.text = result;
                _searchBooking(result);
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Search Bar Header
          _buildSearchHeader(),

          // 2. Main Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _currentBooking == null
                    ? _buildEmptyState()
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Status Banner
                            _buildStatusBanner(),
                            const SizedBox(height: 16),

                            // Customer & Identity Card
                            _buildCustomerCard(),
                            const SizedBox(height: 16),

                            // Identity Verification Checklist
                            _buildChecklistSection(),
                            const SizedBox(height: 16),

                            // Rental & Device Card
                            _buildDeviceCard(),
                            const SizedBox(height: 16),

                            // Financial & Deposit Card
                            _buildFinancialCard(),
                            const SizedBox(height: 16),

                            // Staff Notes Card
                            _buildNotesInput(),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
          ),

          // 3. Sticky Bottom Action Bar
          if (_currentBooking != null) _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildSearchHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: 'Cari Kode Booking (SKY...)',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AppTheme.cardBorder),
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
              ),
              onSubmitted: _searchBooking,
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => _searchBooking(_searchController.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Cari'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Masukkan atau pindai kode booking untuk memulai verifikasi identitas penyewa.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: _errorMessage != null ? const Color(0xFFDC2626) : AppTheme.textSecondary,
                fontWeight: _errorMessage != null ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () async {
                final result = await Navigator.pushNamed(context, AppRoutes.qrScanner);
                if (result is String && result.isNotEmpty) {
                  _searchController.text = result;
                  _searchBooking(result);
                }
              },
              icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
              label: const Text('Pindai QR Pelanggan'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primary,
                side: BorderSide(color: AppTheme.primary),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBanner() {
    final b = _currentBooking!;
    final isReady = b.canPickup;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isReady ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isReady ? const Color(0xFF86EFAC) : const Color(0xFFFECACA),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isReady ? Icons.verified_user_rounded : Icons.warning_amber_rounded,
            color: isReady ? const Color(0xFF047857) : const Color(0xFFDC2626),
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'STATUS: ${b.status.label.toUpperCase()}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: isReady ? const Color(0xFF047857) : const Color(0xFFDC2626),
                      ),
                    ),
                    Text(
                      b.bookingCode,
                      style: TextStyle(fontSize: 12,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'monospace',
                        color: AppTheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  isReady
                      ? 'Booking telah dikonfirmasi dan memenuhi syarat untuk dilakukan verifikasi & serah terima unit iPhone.'
                      : 'Perhatian: Booking berstatus ${b.status.label}. Hanya booking yang berstatus "Dikonfirmasi" yang dapat diserahkan ke pelanggan.',
                  style: TextStyle(
                    fontSize: 11,
                    color: isReady ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerCard() {
    final b = _currentBooking!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppTheme.primary.withValues(alpha: 0.08),
                child: Icon(Icons.person_rounded, color: AppTheme.primary, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      b.customerName,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.primary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      b.customerPhone,
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Text(
                  'Jaminan: ${b.jaminanType}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1D4ED8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: AppTheme.cardBorder),
          const SizedBox(height: 12),
          _buildInfoRow('Email', b.customerEmail.isNotEmpty ? b.customerEmail : '-'),
          _buildInfoRow('Alamat Domisili', b.address ?? '-'),
          _buildInfoRow('Metode Pengambilan', b.pickupType),
        ],
      ),
    );
  }

  Widget _buildChecklistSection() {
    final b = _currentBooking!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _isAllVerified ? const Color(0xFF86EFAC) : AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                  Icon(Icons.fact_check_outlined, color: AppTheme.accent, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Checklist Verifikasi Wajib',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.primary),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _isAllVerified ? const Color(0xFFF0FDF4) : const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _isAllVerified ? 'LENGKAP' : 'BELUM LENGKAP',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: _isAllVerified ? const Color(0xFF047857) : const Color(0xFFB45309),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Centang seluruh poin verifikasi setelah memeriksa dokumen fisik penyewa.',
            style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 12),

          _buildCheckItem(
            title: 'Kesesuaian KTP / Tanda Pengenal Asli',
            subtitle: 'Nama dan foto pada KTP fisik pelanggan cocok dengan orang yang hadir mengambil unit.',
            value: _isIdCardMatched,
            onChanged: (v) => setState(() => _isIdCardMatched = v ?? false),
          ),
          const SizedBox(height: 8),

          _buildCheckItem(
            title: 'Nomor WhatsApp & Kontak Aktif',
            subtitle: 'Nomor telepon ${b.customerPhone} telah divalidasi dan dapat menerima pesan/panggilan operasional.',
            value: _isPhoneVerified,
            onChanged: (v) => setState(() => _isPhoneVerified = v ?? false),
          ),
          const SizedBox(height: 8),

          _buildCheckItem(
            title: 'Dokumen Jaminan Fisik (${b.jaminanType}) Diterima',
            subtitle: 'Fisik jaminan asli telah diserahkan dan dimasukkan ke dalam tempat penyimpanan aman outlet.',
            value: _isCollateralSecured,
            onChanged: (v) => setState(() => _isCollateralSecured = v ?? false),
          ),
          const SizedBox(height: 8),

          _buildCheckItem(
            title: 'Persetujuan Syarat & Ketentuan Rental',
            subtitle: 'Pelanggan telah memahami ketentuan denda keterlambatan, kerusakan, dan penahanan jaminan.',
            value: _isTermsAgreed,
            onChanged: (v) => setState(() => _isTermsAgreed = v ?? false),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceCard() {
    final iphone = _currentBooking!.iphone;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
              Icon(Icons.phone_iphone_rounded, color: AppTheme.accent, size: 18),
              const SizedBox(width: 8),
              Text(
                'Unit & Jadwal Rental',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.primary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: AppTheme.cardBorder),
          const SizedBox(height: 12),
          _buildInfoRow('Unit Dipesan', iphone.fullName, isHighlight: true),
          _buildInfoRow('Warna / Storage', '${iphone.color} • ${iphone.storage}'),
          _buildInfoRow('Mulai Sewa', Formatters.dateTime(_currentBooking!.startDate)),
          _buildInfoRow('Selesai Sewa', Formatters.dateTime(_currentBooking!.endDate)),
          _buildInfoRow('Durasi Rental', '${_currentBooking!.durationDays} Hari'),
        ],
      ),
    );
  }

  Widget _buildFinancialCard() {
    final b = _currentBooking!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                  Icon(Icons.account_balance_wallet_outlined, color: AppTheme.accent, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Kewajiban Pembayaran & Deposit',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.primary),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: b.paymentStatus == PaymentStatus.paid
                      ? const Color(0xFFF0FDF4)
                      : const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  b.paymentStatus.label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: b.paymentStatus == PaymentStatus.paid
                        ? const Color(0xFF047857)
                        : const Color(0xFFB45309),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: AppTheme.cardBorder),
          const SizedBox(height: 12),
          _buildInfoRow('Biaya Sewa Unit', Formatters.currency(b.price)),
          _buildInfoRow('Uang Jaminan (Deposit)', Formatters.currency(b.deposit)),
          const SizedBox(height: 6),
          Divider(height: 1, color: AppTheme.cardBorder),
          const SizedBox(height: 6),
          _buildInfoRow('TOTAL TAGIHAN', Formatters.currency(b.totalBill), isBold: true, isHighlight: true),
        ],
      ),
    );
  }

  Widget _buildNotesInput() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
              Icon(Icons.note_alt_outlined, color: AppTheme.accent, size: 18),
              const SizedBox(width: 8),
              Text(
                'Catatan Khusus Staff (Opsional)',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.primary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _notesController,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Misal: KTP disimpan di brankas slot #12, pelanggan membawa SIM tambahan.',
              hintStyle: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppTheme.cardBorder),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    final isReady = _currentBooking!.canPickup;
    final canApprove = isReady && _isAllVerified;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.cardBorder)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            OutlinedButton(
              onPressed: _showRejectDialog,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFDC2626),
                side: const BorderSide(color: Color(0xFFFCA5A5)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Tolak / Tunda'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: canApprove ? _proceedToPickup : null,
                icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                label: Text(
                  canApprove
                      ? 'Verifikasi Sah & Mulai Serah Terima'
                      : _isAllVerified
                          ? 'Status Booking Belum Siap'
                          : 'Lengkapi 4 Poin Verifikasi',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: canApprove ? const Color(0xFF047857) : Colors.grey.shade400,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckItem({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool?> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: value ? const Color(0xFFF0FDF4) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: value ? const Color(0xFF86EFAC) : AppTheme.cardBorder,
          width: value ? 1.5 : 1,
        ),
      ),
      child: CheckboxListTile(
        title: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
        value: value,
        activeColor: const Color(0xFF047857),
        controlAffinity: ListTileControlAffinity.leading,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isBold = false, bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: (isBold || isHighlight) ? FontWeight.bold : FontWeight.w600,
              color: isHighlight ? AppTheme.accent : AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}