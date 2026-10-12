import 'package:flutter/material.dart';
import '../../data/booking_repository.dart';
import '../../models/user_role_model.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';

class AssignRoleScreen extends StatefulWidget {
  final BookingRepository repository;
  final UserRoleModel? initialUser;
  final bool isEmbedded;

  const AssignRoleScreen({
    super.key,
    required this.repository,
    this.initialUser,
    this.isEmbedded = false,
  });

  @override
  State<AssignRoleScreen> createState() => _AssignRoleScreenState();
}

class _AssignRoleScreenState extends State<AssignRoleScreen> {
  List<UserRoleModel> _users = [];
  List<RoleItemModel> _roles = [];
  List<PermissionItemModel> _permissions = [];
  UserRoleModel? _selectedUser;
  String? _selectedRole;
  final Set<String> _selectedPermissions = {};
  bool _isLoading = true;
  bool _isSaving = false;
  int _activeTab = 0; // 0 = Roles, 1 = Permissions
  final TextEditingController _permissionSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _permissionSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final roles = await widget.repository.getRoles();
      final permissions = await widget.repository.getPermissions();
      final users = await widget.repository.getUsers();

      UserRoleModel? currentSelectedUser = widget.initialUser;
      if (currentSelectedUser != null) {
        // Find latest data for this user
        final matched = users.firstWhere(
          (u) => u.id == currentSelectedUser!.id,
          orElse: () => currentSelectedUser!,
        );
        currentSelectedUser = matched;
      } else if (users.isNotEmpty) {
        currentSelectedUser = users.first;
      }

      if (mounted) {
        setState(() {
          _roles = roles;
          _permissions = permissions;
          _users = users;
          _isLoading = false;
        });
        if (currentSelectedUser != null) {
          _selectUser(currentSelectedUser);
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _selectUser(UserRoleModel user) {
    setState(() {
      _selectedUser = user;
      _selectedRole = (user.role.isEmpty || user.role == '-') ? null : user.role;
      _selectedPermissions.clear();
      _selectedPermissions.addAll(user.permissions);

      // If permissions are empty, seed from the role default permissions
      if (_selectedPermissions.isEmpty && _selectedRole != null) {
        final roleObj = _roles.firstWhere(
          (r) => r.name.toLowerCase() == _selectedRole?.toLowerCase(),
          orElse: () => const RoleItemModel(id: 0, name: '', displayName: ''),
        );
        _selectedPermissions.addAll(roleObj.permissions);
      }
    });
  }

  List<String> get _currentRoleDefaultPermissions {
    if (_selectedRole == null) return [];
    final roleObj = _roles.firstWhere(
      (r) => r.name.toLowerCase() == _selectedRole?.toLowerCase(),
      orElse: () => const RoleItemModel(id: 0, name: '', displayName: ''),
    );
    return roleObj.permissions;
  }

  Future<void> _handleSave() async {
    if (_selectedUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih pengguna terlebih dahulu.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final success = await widget.repository.assignUserRole(
        _selectedUser!.id,
        _selectedRole,
        permissions: _selectedPermissions.toList(),
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Role & hak akses berhasil diperbarui untuk ${_selectedUser!.name}'),
            backgroundColor: const Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
          ),
        );

        // Refresh user data from server
        final updatedUsers = await widget.repository.getUsers();
        if (mounted) {
          setState(() {
            _users = updatedUsers;
            _selectedUser = updatedUsers.firstWhere(
              (u) => u.id == _selectedUser!.id,
              orElse: () => _selectedUser!,
            );
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal assign role & permission: $e'),
            backgroundColor: Colors.red.shade800,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
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

  // =========================================================================
  // SUB-VIEWS
  // =========================================================================

  Widget _buildUserSelectorCard() {
    if (_selectedUser == null) {
      return const SizedBox.shrink();
    }

    final initials = _getUserInitials(_selectedUser!.name);
    final isSuper = _selectedUser!.role.toLowerCase().contains('super');

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(16),
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
        children: [
          Row(
            children: [
              const Text(
                'Pengguna Terpilih',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
              ),
              const Spacer(),
              if (_users.length > 1)
                InkWell(
                  onTap: _showSelectUserBottomSheet,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.swap_horiz_rounded, size: 14, color: Color(0xFF0F172A)),
                        SizedBox(width: 4),
                        Text(
                          'Ganti User',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: isSuper ? const Color(0xFFF3E8FF) : const Color(0xFFF1F5F9),
                child: Text(
                  initials,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isSuper ? const Color(0xFF9333EA) : const Color(0xFF475569),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            _selectedUser!.name,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildRoleBadge(_selectedUser!.role),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _selectedUser!.email,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  '${_selectedPermissions.length} Izin Aktif',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF475569),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showSelectUserBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      backgroundColor: Colors.white,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text(
              'Pilih Pengguna',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _users.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final u = _users[index];
                  final isSelected = _selectedUser?.id == u.id;
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFFF1F5F9),
                      child: Text(
                        _getUserInitials(u.name),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569)),
                      ),
                    ),
                    title: Text(u.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text('${u.email} • ${u.roleDisplay}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle_rounded, color: Color(0xFF0F172A), size: 20)
                        : null,
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _selectUser(u);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _activeTab = 0),
              borderRadius: BorderRadius.circular(10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: _activeTab == 0 ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: _activeTab == 0
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.admin_panel_settings_rounded,
                      size: 16,
                      color: _activeTab == 0 ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Pilih Peran (Role)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: _activeTab == 0 ? FontWeight.bold : FontWeight.w500,
                        color: _activeTab == 0 ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _activeTab = 1),
              borderRadius: BorderRadius.circular(10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: _activeTab == 1 ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: _activeTab == 1
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.vpn_key_rounded,
                      size: 16,
                      color: _activeTab == 1 ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Hak Akses (${_selectedPermissions.length})',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: _activeTab == 1 ? FontWeight.bold : FontWeight.w500,
                        color: _activeTab == 1 ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRolesList() {
    if (_roles.isEmpty) {
      return const Center(child: Text('Tidak ada role yang tersedia'));
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
      itemCount: _roles.length,
      itemBuilder: (context, index) {
        final role = _roles[index];
        final isSelected = _selectedRole?.toLowerCase() == role.name.toLowerCase();

        String description;
        if (role.name.contains('super')) {
          description = 'Akses penuh tanpa batasan ke seluruh menu, pengaturan dan data keuangan.';
        } else if (role.name.contains('staff') || role.name.contains('kasir')) {
          description = 'Operasional harian: booking, penerimaan unit, dan cetak struk kasir.';
        } else {
          description = 'Manajemen cabang: unit iPhone, monitoring booking cabang dan mutasi.';
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: InkWell(
            onTap: () {
              setState(() {
                _selectedRole = role.name;
                if (role.permissions.isNotEmpty) {
                  _selectedPermissions.addAll(role.permissions);
                }
              });
            },
            borderRadius: BorderRadius.circular(16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFF8FAFC) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                  width: isSelected ? 1.5 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Radio<String>(
                    value: role.name,
                    groupValue: _selectedRole,
                    activeColor: const Color(0xFF0F172A),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedRole = val;
                          if (role.permissions.isNotEmpty) {
                            _selectedPermissions.addAll(role.permissions);
                          }
                        });
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              role.displayName,
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _buildRoleBadge(role.name),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          description,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.vpn_key_rounded, size: 12, color: Color(0xFF94A3B8)),
                            const SizedBox(width: 4),
                            Text(
                              '${role.permissionsCount} Izin bawaan peran ini',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPermissionsList() {
    final defaultPerms = _currentRoleDefaultPermissions;
    final query = _permissionSearchController.text.trim().toLowerCase();
    var filtered = _permissions;
    if (query.isNotEmpty) {
      filtered = filtered.where((p) => p.name.toLowerCase().contains(query) || p.displayName.toLowerCase().contains(query)).toList();
    }

    return Column(
      children: [
        // Search & Quick Action Buttons
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              TextField(
                controller: _permissionSearchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Cari izin hak akses...',
                  hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                  prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  isDense: true,
                ),
                style: const TextStyle(fontSize: 12.5),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _selectedPermissions.addAll(_permissions.map((p) => p.name));
                      });
                    },
                    icon: const Icon(Icons.select_all_rounded, size: 14),
                    label: const Text('Pilih Semua', style: TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _selectedPermissions.clear();
                        _selectedPermissions.addAll(defaultPerms);
                      });
                    },
                    icon: const Icon(Icons.restart_alt_rounded, size: 14),
                    label: const Text('Reset ke Role', style: TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _selectedPermissions.clear();
                      });
                    },
                    icon: const Icon(Icons.clear_all_rounded, size: 14),
                    label: const Text('Kosongkan', style: TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Permissions Items
        Expanded(
          child: filtered.isEmpty
              ? const Center(child: Text('Tidak ada izin yang sesuai pencarian'))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final perm = filtered[index];
                    final isChecked = _selectedPermissions.contains(perm.name);
                    final isDefaultRole = defaultPerms.contains(perm.name);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            if (isChecked) {
                              _selectedPermissions.remove(perm.name);
                            } else {
                              _selectedPermissions.add(perm.name);
                            }
                          });
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isChecked ? const Color(0xFFF0FDF4) : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isChecked ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Row(
                            children: [
                              Checkbox(
                                value: isChecked,
                                activeColor: const Color(0xFF10B981),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                onChanged: (_) {
                                  setState(() {
                                    if (isChecked) {
                                      _selectedPermissions.remove(perm.name);
                                    } else {
                                      _selectedPermissions.add(perm.name);
                                    }
                                  });
                                },
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          perm.displayName,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: isChecked ? FontWeight.bold : FontWeight.w500,
                                            color: const Color(0xFF1E293B),
                                          ),
                                        ),
                                        if (isDefaultRole) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Text(
                                              'Default Role',
                                              style: TextStyle(fontSize: 10, color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Kode izin: ${perm.name}',
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildBottomSaveBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
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
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _handleSave,
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check_circle_outline_rounded, size: 18),
                label: const Text(
                  'Simpan Peran & Hak Akses',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isAuthorized = AuthService().isSuperAdmin || AuthService().isAdmin;
    if (!isAuthorized) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text('Akses Ditolak', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold)),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Akses ditolak: Hanya Super Admin yang berwenang menetapkan role & hak akses pengguna.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
            ),
          ),
        ),
      );
    }

    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text('Assign Role & Hak Akses', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold)),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final content = Column(
      children: [
        _buildUserSelectorCard(),
        _buildTabSelector(),
        Expanded(
          child: _activeTab == 0 ? _buildRolesList() : _buildPermissionsList(),
        ),
        _buildBottomSaveBar(),
      ],
    );

    if (widget.isEmbedded) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: content,
      );
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
              'Assign Role & Hak Akses',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            SizedBox(height: 1),
            Text(
              'Tetapkan peran & konfigurasi izin tim',
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
      body: content,
    );
  }
}
