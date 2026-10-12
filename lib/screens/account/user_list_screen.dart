import 'package:flutter/material.dart';
import '../../data/booking_repository.dart';
import '../../models/user_role_model.dart';
import '../../routes/app_routes.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import 'assign_role_screen.dart';

class UserListScreen extends StatefulWidget {
  final BookingRepository repository;
  final bool isEmbedded;

  const UserListScreen({
    super.key,
    required this.repository,
    this.isEmbedded = false,
  });

  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<UserRoleModel> _users = [];
  List<RoleItemModel> _roles = [];
  bool _isLoading = true;
  String _selectedRoleFilter = 'all'; // 'all', 'super-admin', 'admin_cabang', 'staff'
  String _sortBy = 'created_at'; // 'created_at', 'name'
  bool _sortAscending = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final roles = await widget.repository.getRoles();
      final users = await widget.repository.getUsers(
        search: _searchController.text.trim().isNotEmpty ? _searchController.text.trim() : null,
      );

      if (mounted) {
        setState(() {
          _roles = roles;
          _users = users;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<UserRoleModel> get _filteredUsers {
    var list = List<UserRoleModel>.from(_users);
    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      list = list.where((u) => u.name.toLowerCase().contains(query) || u.email.toLowerCase().contains(query)).toList();
    }

    if (_selectedRoleFilter != 'all') {
      list = list.where((u) {
        final lower = u.role.toLowerCase().trim();
        if (_selectedRoleFilter == 'super-admin') {
          return lower.contains('super-admin') || lower.contains('superadmin');
        } else if (_selectedRoleFilter == 'admin_cabang') {
          return lower.contains('affiliate') || lower.contains('admin') && !lower.contains('super');
        } else if (_selectedRoleFilter == 'staff') {
          return lower.contains('staff') || lower.contains('kasir');
        }
        return true;
      }).toList();
    }

    list.sort((a, b) {
      if (_sortBy == 'name') {
        return _sortAscending ? a.name.compareTo(b.name) : b.name.compareTo(a.name);
      }
      // default: created_at
      final aDate = a.createdAt ?? DateTime(2026, 1, 1);
      final bDate = b.createdAt ?? DateTime(2026, 1, 1);
      return _sortAscending ? aDate.compareTo(bDate) : bDate.compareTo(aDate);
    });

    return list;
  }

  int get _countSuperAdmin => _users.where((u) {
        final lower = u.role.toLowerCase();
        return lower.contains('super-admin') || lower.contains('superadmin');
      }).length;

  int get _countAdminCabang => _users.where((u) {
        final lower = u.role.toLowerCase();
        return lower.contains('affiliate') || (lower.contains('admin') && !lower.contains('super'));
      }).length;

  int get _countStaff => _users.where((u) {
        final lower = u.role.toLowerCase();
        return lower.contains('staff') || lower.contains('kasir');
      }).length;

  String _formatDate(UserRoleModel user) {
    if (user.createdAt != null) {
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
      final day = user.createdAt!.day.toString().padLeft(2, '0');
      final month = months[user.createdAt!.month - 1];
      final year = user.createdAt!.year;
      return '$day $month $year';
    }
    if (user.createdAtFormatted != null && user.createdAtFormatted!.isNotEmpty) {
      return user.createdAtFormatted!.split(',').first.trim();
    }
    return '04 Okt 2026';
  }

  String _getUserInitials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'U';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      final first = parts[0].isNotEmpty ? parts[0][0] : '';
      final second = parts[1].isNotEmpty ? parts[1][0] : '';
      return '$first$second'.toUpperCase();
    }
    return trimmed.substring(0, trimmed.length >= 2 ? 2 : 1).toUpperCase();
  }

  Color _getAvatarBgColor(String role) {
    final lower = role.toLowerCase().trim();
    if (lower.contains('super-admin') || lower.contains('superadmin')) {
      return const Color(0xFFF3E8FF); // soft purple
    }
    if (lower.contains('staff') || lower.contains('kasir')) {
      return const Color(0xFFFEF3C7); // soft amber
    }
    return const Color(0xFFF1F5F9); // soft slate
  }

  Color _getAvatarTextColor(String role) {
    final lower = role.toLowerCase().trim();
    if (lower.contains('super-admin') || lower.contains('superadmin')) {
      return const Color(0xFF9333EA); // purple
    }
    if (lower.contains('staff') || lower.contains('kasir')) {
      return const Color(0xFFB45309); // amber
    }
    return const Color(0xFF475569); // slate
  }

  Widget _buildRoleBadge(String role) {
    final lower = role.toLowerCase().trim();
    Color bg;
    Color text;
    String label;

    if (lower.contains('super-admin') || lower.contains('superadmin')) {
      bg = const Color(0xFFF3E8FF);
      text = const Color(0xFF7E22CE);
      label = 'Super Admin';
    } else if (lower.contains('staff') || lower.contains('kasir')) {
      bg = const Color(0xFFFEF3C7);
      text = const Color(0xFFB45309);
      label = 'Staff Kasir';
    } else {
      bg = const Color(0xFFDCFCE7);
      text = const Color(0xFF15803D);
      label = 'Admin Cabang';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: text,
        ),
      ),
    );
  }

  void _showSortFilterModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      backgroundColor: Colors.white,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const Text(
                    'Urutkan & Filter Pengguna',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 16),
                  const Text('Urutkan Berdasarkan:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      ChoiceChip(
                        label: const Text('Waktu Dibuat'),
                        selected: _sortBy == 'created_at',
                        selectedColor: const Color(0xFF0F172A),
                        labelStyle: TextStyle(color: _sortBy == 'created_at' ? Colors.white : const Color(0xFF334155), fontSize: 12),
                        onSelected: (val) {
                          if (val) {
                            setState(() => _sortBy = 'created_at');
                            setSheetState(() {});
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Nama (A-Z)'),
                        selected: _sortBy == 'name',
                        selectedColor: const Color(0xFF0F172A),
                        labelStyle: TextStyle(color: _sortBy == 'name' ? Colors.white : const Color(0xFF334155), fontSize: 12),
                        onSelected: (val) {
                          if (val) {
                            setState(() => _sortBy = 'name');
                            setSheetState(() {});
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Arah Pengurutan:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      ChoiceChip(
                        label: const Text('Terbaru / Z-A'),
                        selected: !_sortAscending,
                        selectedColor: const Color(0xFF0F172A),
                        labelStyle: TextStyle(color: !_sortAscending ? Colors.white : const Color(0xFF334155), fontSize: 12),
                        onSelected: (val) {
                          if (val) {
                            setState(() => _sortAscending = false);
                            setSheetState(() {});
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Terlama / A-Z'),
                        selected: _sortAscending,
                        selectedColor: const Color(0xFF0F172A),
                        labelStyle: TextStyle(color: _sortAscending ? Colors.white : const Color(0xFF334155), fontSize: 12),
                        onSelected: (val) {
                          if (val) {
                            setState(() => _sortAscending = true);
                            setSheetState(() {});
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Terapkan', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showCreateUserModal() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    String selectedRole = _roles.isNotEmpty ? _roles.first.name : 'staff';
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.person_add_rounded, color: Color(0xFF0F172A), size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Tambah Pengguna Baru',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Nama Lengkap',
                        hintText: 'Misal: Ahmad Kasir',
                        prefixIcon: const Icon(Icons.badge_outlined, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        isDense: true,
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Nama wajib diisi' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Alamat Email',
                        hintText: 'ahmad@skyrental.id',
                        prefixIcon: const Icon(Icons.email_outlined, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        isDense: true,
                      ),
                      validator: (v) => (v == null || !v.contains('@')) ? 'Email tidak valid' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: passwordCtrl,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Kata Sandi Awal',
                        hintText: 'Minimal 6 karakter',
                        prefixIcon: const Icon(Icons.lock_outline, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        isDense: true,
                      ),
                      validator: (v) => (v == null || v.length < 6) ? 'Kata sandi minimal 6 karakter' : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedRole,
                      decoration: InputDecoration(
                        labelText: 'Pilih Role Awal',
                        prefixIcon: const Icon(Icons.admin_panel_settings_outlined, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        isDense: true,
                      ),
                      items: _roles.map((r) {
                        return DropdownMenuItem(
                          value: r.name,
                          child: Text(r.displayName),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() => selectedRole = val);
                        }
                      },
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: isSaving ? null : () => Navigator.of(ctx).pop(),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              side: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            child: const Text('Batal', style: TextStyle(color: Color(0xFF64748B))),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: isSaving
                                ? null
                                : () async {
                                    if (!formKey.currentState!.validate()) return;
                                    setModalState(() => isSaving = true);
                                    try {
                                      await widget.repository.createUser(
                                        name: nameCtrl.text.trim(),
                                        email: emailCtrl.text.trim(),
                                        password: passwordCtrl.text.trim(),
                                        role: selectedRole,
                                      );
                                      if (ctx.mounted) {
                                        Navigator.of(ctx).pop();
                                      }
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Pengguna baru berhasil dibuat'),
                                            backgroundColor: Color(0xFF059669),
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                        _loadData();
                                      }
                                    } catch (e) {
                                      if (ctx.mounted) {
                                        setModalState(() => isSaving = false);
                                      }
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Gagal membuat user: $e'),
                                            backgroundColor: Colors.red.shade800,
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      }
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0F172A),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: isSaving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Text('Simpan Pengguna', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  },
);
  }

  void _confirmDeleteUser(UserRoleModel user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 24),
            SizedBox(width: 8),
            Text('Hapus Pengguna?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Apakah Anda yakin ingin menghapus akun "${user.name}" (${user.email})? Tindakan ini tidak dapat dibatalkan.',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Batal', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                final ok = await widget.repository.deleteUser(user.id);
                if (ok && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Pengguna ${user.name} berhasil dihapus'),
                      backgroundColor: Colors.red.shade800,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  _loadData();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Gagal menghapus user: $e'),
                      backgroundColor: Colors.red.shade900,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text('Hapus Akun'),
          ),
        ],
      ),
    );
  }

  void _navigateToAssignRole(UserRoleModel user) {
    Navigator.of(context)
        .pushNamed(
          AppRoutes.assignRole,
          arguments: user,
        )
        .then((_) => _loadData());
  }

  // =========================================================================
  // UI WIDGET BUILDERS
  // =========================================================================

  Widget _buildSummaryCards({bool isTablet = false}) {
    final padding = EdgeInsets.symmetric(horizontal: isTablet ? 20 : 16, vertical: 12);
    if (isTablet) {
      return Container(
        padding: padding,
        child: Row(
          children: [
            // Card 1: Total
            Expanded(
              child: _buildSummaryCardItem(
                label: 'Total',
                value: '${_users.length}',
                subtext: 'Akun',
                subtextColor: const Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(width: 12),
            // Card 2: Super Admin
            Expanded(
              child: _buildSummaryCardItem(
                label: 'Super Admin',
                value: '$_countSuperAdmin',
                subtext: 'Aktif',
                subtextColor: const Color(0xFF9333EA),
              ),
            ),
            const SizedBox(width: 12),
            // Card 3: Admin Cabang
            Expanded(
              child: _buildSummaryCardItem(
                label: 'Admin Cabang',
                value: '$_countAdminCabang',
                subtext: 'Mitra',
                subtextColor: const Color(0xFF15803D),
              ),
            ),
            const SizedBox(width: 12),
            // Card 4: Staf
            Expanded(
              child: _buildSummaryCardItem(
                label: 'Staf',
                value: '$_countStaff',
                subtext: 'Kasir',
                subtextColor: const Color(0xFFB45309),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: padding,
      child: Row(
        children: [
          // Card 1: Total
          Expanded(
            child: _buildSummaryCardItem(
              label: 'Total',
              value: '${_users.length}',
              subtext: 'Akun',
              subtextColor: const Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(width: 10),
          // Card 2: Super Admin
          Expanded(
            child: _buildSummaryCardItem(
              label: 'Super Admin',
              value: '$_countSuperAdmin',
              subtext: 'Aktif',
              subtextColor: const Color(0xFF9333EA),
            ),
          ),
          const SizedBox(width: 10),
          // Card 3: Staf
          Expanded(
            child: _buildSummaryCardItem(
              label: 'Staf',
              value: '$_countStaff',
              subtext: '-',
              subtextColor: const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCardItem({
    required String label,
    required String value,
    required String subtext,
    required Color subtextColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const Spacer(),
              Text(
                subtext,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: subtextColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilterRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Search input
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Cari nama atau email...',
                hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF94A3B8)),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18, color: Color(0xFF94A3B8)),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.5),
                ),
                isDense: true,
              ),
              style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
            ),
          ),
          const SizedBox(width: 10),
          // Filter button
          InkWell(
            onTap: _showSortFilterModal,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Icon(Icons.tune_rounded, size: 20, color: Color(0xFF475569)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChipsRow() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildCustomFilterChip('all', 'Semua (${_users.length})'),
            const SizedBox(width: 8),
            _buildCustomFilterChip('super-admin', 'Super Admin ($_countSuperAdmin)'),
            const SizedBox(width: 8),
            _buildCustomFilterChip('admin_cabang', 'Admin Cabang ($_countAdminCabang)'),
            if (_countStaff > 0) ...[
              const SizedBox(width: 8),
              _buildCustomFilterChip('staff', 'Staf ($_countStaff)'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCustomFilterChip(String key, String label) {
    final isSelected = _selectedRoleFilter == key;
    return InkWell(
      onTap: () => setState(() => _selectedRoleFilter = key),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF334155),
          ),
        ),
      ),
    );
  }

  Widget _buildTabletSearchAndFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          // Search input
          Expanded(
            flex: 5,
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Cari nama atau email...',
                hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF94A3B8)),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18, color: Color(0xFF94A3B8)),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.5),
                ),
                isDense: true,
              ),
              style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
            ),
          ),
          const SizedBox(width: 14),
          // Filter chips row
          Expanded(
            flex: 6,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildCustomFilterChip('all', 'Semua (${_users.length})'),
                  const SizedBox(width: 8),
                  _buildCustomFilterChip('super-admin', 'Super Admin ($_countSuperAdmin)'),
                  const SizedBox(width: 8),
                  _buildCustomFilterChip('admin_cabang', 'Admin Cabang ($_countAdminCabang)'),
                  if (_countStaff > 0) ...[
                    const SizedBox(width: 8),
                    _buildCustomFilterChip('staff', 'Staf ($_countStaff)'),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Filter & Sort button
          InkWell(
            onTap: _showSortFilterModal,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Icon(Icons.tune_rounded, size: 20, color: Color(0xFF475569)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(UserRoleModel user, {bool isGrid = false}) {
    final initials = _getUserInitials(user.name);
    final avatarBg = _getAvatarBgColor(user.role);
    final avatarTextColor = _getAvatarTextColor(user.role);
    final dateStr = _formatDate(user);

    return Container(
      margin: isGrid ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Top Row: Avatar + Name & Role Badge + 3-dots Menu
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              CircleAvatar(
                radius: 20,
                backgroundColor: avatarBg,
                child: Text(
                  initials,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: avatarTextColor,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Name, Badge & Email
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            user.name,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildRoleBadge(user.role),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      user.email,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // 3-dots Menu
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, size: 20, color: Color(0xFF94A3B8)),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onSelected: (val) {
                  if (val == 'assign_role') {
                    _navigateToAssignRole(user);
                  } else if (val == 'delete') {
                    _confirmDeleteUser(user);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'assign_role',
                    child: Row(
                      children: [
                        Icon(Icons.security_rounded, size: 16, color: Color(0xFF4F46E5)),
                        SizedBox(width: 10),
                        Text('Atur Role & Hak Akses', style: TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red),
                        SizedBox(width: 10),
                        Text('Hapus Pengguna', style: TextStyle(fontSize: 13, color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Bottom Row: Permissions Tag, Bullet, Date, and Action Buttons (Atur Izin + Trash)
          Row(
            children: [
              // Permissions pill tag
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  user.directPermissions.isNotEmpty
                      ? '${user.permissions.length} Izin (+${user.directPermissions.length})'
                      : '${user.permissions.length} Izin',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF475569),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text('•', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  dateStr,
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Spacer(),
              // Atur Izin Outlined Pill Button
              InkWell(
                onTap: () => _navigateToAssignRole(user),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Text(
                    'Atur Izin',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Trash Icon Button
              InkWell(
                onTap: () => _confirmDeleteUser(user),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    size: 19,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ),
            ],
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
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.people_outline_rounded, size: 48, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 16),
            const Text(
              'Tidak ada pengguna ditemukan',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 6),
            const Text(
              'Coba sesuaikan kata kunci pencarian atau filter peran yang dipilih.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () {
                _searchController.clear();
                setState(() => _selectedRoleFilter = 'all');
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFE2E8F0)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Reset Filter', style: TextStyle(color: Color(0xFF0F172A))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final users = _filteredUsers;

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final isTablet = screenWidth >= 600;
        final isWide = screenWidth >= 700;
        final isExtraWide = screenWidth >= 1050;

        return RefreshIndicator(
          onRefresh: _loadData,
          color: const Color(0xFF0F172A),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _buildSummaryCards(isTablet: isTablet),
              ),
              if (isWide)
                SliverToBoxAdapter(
                  child: _buildTabletSearchAndFilterBar(),
                )
              else ...[
                SliverToBoxAdapter(
                  child: _buildSearchAndFilterRow(),
                ),
                SliverToBoxAdapter(
                  child: _buildFilterChipsRow(),
                ),
              ],
              if (users.isEmpty)
                SliverFillRemaining(hasScrollBody: false, child: _buildEmptyState())
              else if (isTablet)
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(isWide ? 20 : 16, 8, isWide ? 20 : 16, 90),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: isExtraWide ? 3 : 2,
                      mainAxisExtent: 148,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _buildUserCard(users[index], isGrid: true),
                      childCount: users.length,
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.only(bottom: 90),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _buildUserCard(users[index], isGrid: false),
                      childCount: users.length,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmbeddedLayout(BuildContext context) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final users = _filteredUsers;

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final isWide = screenWidth >= 700;
        final isExtraWide = screenWidth >= 1050;
        final columns = isExtraWide ? 3 : (screenWidth >= 600 ? 2 : 1);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Detail Header matching tablet styling
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Daftar Pengguna',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Kelola akun tim, peran (role), dan hak akses izin pengguna sistem.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: _loadData,
                      icon: const Icon(Icons.refresh_rounded, size: 20, color: Color(0xFF475569)),
                      tooltip: 'Segarkan Data',
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _showCreateUserModal,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Tambah Pengguna', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Summary Cards
            _buildSummaryCards(isTablet: true),
            const SizedBox(height: 8),

            // Search and Filter Bar
            if (isWide)
              _buildTabletSearchAndFilterBar()
            else ...[
              _buildSearchAndFilterRow(),
              _buildFilterChipsRow(),
            ],
            const SizedBox(height: 12),

            // User Cards Grid/List
            if (users.isEmpty)
              _buildEmptyState()
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 24),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisExtent: 148,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                ),
                itemCount: users.length,
                itemBuilder: (context, index) {
                  return _buildUserCard(users[index], isGrid: true);
                },
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isEmbedded) {
      return _buildEmbeddedLayout(context);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pengguna & Hak Akses',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            SizedBox(height: 1),
            Text(
              'Manajemen peran & izin tim',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFF1F5F9), height: 1),
        ),
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateUserModal,
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        shape: const StadiumBorder(),
        icon: const Icon(Icons.add, size: 19),
        label: const Text('Tambah Pengguna', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      ),
    );
  }
}
