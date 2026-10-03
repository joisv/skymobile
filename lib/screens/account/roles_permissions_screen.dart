import 'package:flutter/material.dart';
import '../../data/booking_repository.dart';
import '../../models/user_role_model.dart';
import '../../theme/app_theme.dart';

class RolesPermissionsScreen extends StatefulWidget {
  final BookingRepository repository;
  final bool isEmbedded;

  const RolesPermissionsScreen({
    super.key,
    required this.repository,
    this.isEmbedded = false,
  });

  @override
  State<RolesPermissionsScreen> createState() => _RolesPermissionsScreenState();
}

class _RolesPermissionsScreenState extends State<RolesPermissionsScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<UserRoleModel> _users = [];
  List<RoleItemModel> _roles = [];
  List<PermissionItemModel> _permissions = [];
  bool _isLoading = true;
  String _selectedRoleFilter = 'all';

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
      final permissions = await widget.repository.getPermissions();
      final users = await widget.repository.getUsers(
        search: _searchController.text.trim().isNotEmpty ? _searchController.text.trim() : null,
        role: _selectedRoleFilter != 'all' ? _selectedRoleFilter : null,
      );

      if (mounted) {
        setState(() {
          _roles = roles;
          _permissions = permissions;
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
    var list = _users;
    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      list = list.where((u) => u.name.toLowerCase().contains(query) || u.email.toLowerCase().contains(query)).toList();
    }
    if (_selectedRoleFilter != 'all') {
      list = list.where((u) {
        if (_selectedRoleFilter == 'none') {
          return u.role == '-' || u.role.isEmpty;
        }
        return u.role.toLowerCase() == _selectedRoleFilter.toLowerCase();
      }).toList();
    }
    return list;
  }

  int get _countSuperAdmin => _users.where((u) => u.role.toLowerCase().contains('super-admin')).length;
  int get _countAdmin => _users.where((u) => u.role.toLowerCase() == 'admin').length;
  int get _countStaff => _users.where((u) => u.role.toLowerCase() == 'staff' || u.role.toLowerCase() == 'kasir').length;

  Color _getRoleBadgeColor(String role) {
    final lower = role.toLowerCase().trim();
    if (lower.contains('super-admin')) return const Color(0xFF4F46E5); // Indigo
    if (lower == 'admin') return const Color(0xFF0284C7); // Sky/Blue
    if (lower == 'staff' || lower == 'kasir') return const Color(0xFFD97706); // Amber
    if (lower.contains('affiliate')) return const Color(0xFF059669); // Emerald
    return const Color(0xFF64748B); // Slate Gray
  }

  Future<void> _handleAssignRole(UserRoleModel user, String? roleName, {List<String>? permissions}) async {
    try {
      final success = await widget.repository.assignUserRole(user.id, roleName, permissions: permissions);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Role & hak akses berhasil diperbarui untuk ${user.name}'),
            backgroundColor: const Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadData();
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
    }
  }

  void _showAssignRoleModal(UserRoleModel user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String? selectedRole = (user.role.isEmpty || user.role == '-') ? null : user.role;
        // Seed initial permissions from user.permissions
        final Set<String> selectedPermissions = Set<String>.from(user.permissions);
        if (selectedPermissions.isEmpty && selectedRole != null) {
          final matchedRole = _roles.firstWhere(
            (r) => r.name.toLowerCase() == selectedRole?.toLowerCase(),
            orElse: () => const RoleItemModel(id: 0, name: '', displayName: ''),
          );
          selectedPermissions.addAll(matchedRole.permissions);
        }
        int activeTab = 0; // 0 = Roles, 1 = Permissions
        bool isSubmitting = false;

        return StatefulBuilder(
          builder: (context, setModalState) {
            final currentRoleObj = _roles.firstWhere(
              (r) => r.name.toLowerCase() == selectedRole?.toLowerCase(),
              orElse: () => const RoleItemModel(id: 0, name: '', displayName: ''),
            );
            final roleDefaultPerms = currentRoleObj.permissions;

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.85,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEA580C).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.security_rounded, color: Color(0xFFEA580C), size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Assign Role & Izin',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Pilih salah satu role dan hak akses untuk ${user.name}',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Segmented Tab Selector
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setModalState(() => activeTab = 0),
                            borderRadius: BorderRadius.circular(10),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: activeTab == 0 ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: activeTab == 0
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
                                    color: activeTab == 0 ? const Color(0xFFEA580C) : const Color(0xFF64748B),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Pilih Role',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: activeTab == 0 ? FontWeight.bold : FontWeight.w500,
                                      color: activeTab == 0 ? const Color(0xFFEA580C) : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () => setModalState(() => activeTab = 1),
                            borderRadius: BorderRadius.circular(10),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: activeTab == 1 ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: activeTab == 1
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
                                    color: activeTab == 1 ? const Color(0xFFEA580C) : const Color(0xFF64748B),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Hak Akses (${selectedPermissions.length})',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: activeTab == 1 ? FontWeight.bold : FontWeight.w500,
                                      color: activeTab == 1 ? const Color(0xFFEA580C) : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Tab Content
                  Expanded(
                    child: activeTab == 0
                        ? _buildRolesTab(
                            selectedRole: selectedRole,
                            onSelectRole: (roleName) {
                              setModalState(() {
                                selectedRole = roleName;
                                if (roleName != null) {
                                  final rObj = _roles.firstWhere(
                                    (r) => r.name.toLowerCase() == roleName.toLowerCase(),
                                    orElse: () => const RoleItemModel(id: 0, name: '', displayName: ''),
                                  );
                                  if (rObj.permissions.isNotEmpty) {
                                    selectedPermissions.addAll(rObj.permissions);
                                  }
                                }
                              });
                            },
                          )
                        : _buildPermissionsTab(
                            selectedPermissions: selectedPermissions,
                            roleDefaultPerms: roleDefaultPerms,
                            onTogglePermission: (permName) {
                              setModalState(() {
                                if (selectedPermissions.contains(permName)) {
                                  selectedPermissions.remove(permName);
                                } else {
                                  selectedPermissions.add(permName);
                                }
                              });
                            },
                            onSelectAll: () {
                              setModalState(() {
                                selectedPermissions.addAll(_permissions.map((p) => p.name));
                              });
                            },
                            onDeselectAll: () {
                              setModalState(() {
                                selectedPermissions.clear();
                              });
                            },
                            onResetToRole: () {
                              setModalState(() {
                                selectedPermissions.clear();
                                selectedPermissions.addAll(roleDefaultPerms);
                              });
                            },
                          ),
                  ),

                  const SizedBox(height: 14),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  const SizedBox(height: 12),

                  // Footer Actions
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: isSubmitting ? null : () => Navigator.of(ctx).pop(),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
                          child: const Text('Batal', style: TextStyle(color: Color(0xFF64748B))),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  setModalState(() => isSubmitting = true);
                                  Navigator.of(ctx).pop();
                                  await _handleAssignRole(
                                    user,
                                    selectedRole,
                                    permissions: selectedPermissions.toList(),
                                  );
                                },
                          icon: isSubmitting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.check_circle_outline_rounded, size: 18),
                          label: const Text(
                            'Simpan Role & Izin',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEA580C),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRolesTab({
    required String? selectedRole,
    required ValueChanged<String?> onSelectRole,
  }) {
    if (_roles.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      children: [
        ...List.generate(_roles.length, (index) {
          final role = _roles[index];
          final isSelected = selectedRole?.toLowerCase() == role.name.toLowerCase();

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              onTap: () => onSelectRole(role.name),
              borderRadius: BorderRadius.circular(14),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFFFF7ED) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? const Color(0xFFEA580C) : const Color(0xFFE2E8F0),
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: const Color(0xFFEA580C).withValues(alpha: 0.12),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _getRoleBadgeColor(role.name).withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.admin_panel_settings_rounded,
                        color: _getRoleBadgeColor(role.name),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            role.displayName,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? const Color(0xFF9A3412) : const Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${role.permissionsCount} Permissions bawaan',
                            style: TextStyle(
                              fontSize: 12,
                              color: isSelected ? const Color(0xFFC2410C) : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      Container(
                        width: 26,
                        height: 26,
                        decoration: const BoxDecoration(
                          color: Color(0xFFEA580C),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check, color: Colors.white, size: 16),
                      )
                    else
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.grey.shade300, width: 1.5),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        }),
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: InkWell(
            onTap: () => onSelectRole(null),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: selectedRole == null ? const Color(0xFFF8FAFC) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selectedRole == null ? Colors.blueGrey : const Color(0xFFE2E8F0),
                  width: selectedRole == null ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.person_off_outlined, color: Colors.grey.shade600, size: 20),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Tanpa Role', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        Text('Hapus penetapan role dari user ini', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                  if (selectedRole == null)
                    const Icon(Icons.check_circle, color: Colors.blueGrey, size: 22),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPermissionsTab({
    required Set<String> selectedPermissions,
    required List<String> roleDefaultPerms,
    required ValueChanged<String> onTogglePermission,
    required VoidCallback onSelectAll,
    required VoidCallback onDeselectAll,
    required VoidCallback onResetToRole,
  }) {
    final permissionsList = _permissions.isNotEmpty
        ? _permissions
        : const [
            PermissionItemModel(id: 1, name: 'create', displayName: 'Create (Tambah Data)'),
            PermissionItemModel(id: 2, name: 'update', displayName: 'Update (Ubah Data)'),
            PermissionItemModel(id: 3, name: 'delete', displayName: 'Delete (Hapus Data)'),
          ];

    return Column(
      children: [
        Row(
          children: [
            TextButton.icon(
              onPressed: onSelectAll,
              icon: const Icon(Icons.select_all_rounded, size: 15),
              label: const Text('Pilih Semua', style: TextStyle(fontSize: 11)),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF2563EB),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: onDeselectAll,
              icon: const Icon(Icons.deselect_rounded, size: 15),
              label: const Text('Hapus Semua', style: TextStyle(fontSize: 11)),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red.shade700,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const Spacer(),
            if (roleDefaultPerms.isNotEmpty)
              TextButton.icon(
                onPressed: onResetToRole,
                icon: const Icon(Icons.restore_rounded, size: 15),
                label: const Text('Reset ke Role', style: TextStyle(fontSize: 11)),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFEA580C),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.separated(
            itemCount: permissionsList.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final perm = permissionsList[index];
              final isChecked = selectedPermissions.contains(perm.name);
              final isRoleDefault = roleDefaultPerms.contains(perm.name);

              return InkWell(
                onTap: () => onTogglePermission(perm.name),
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
                        onChanged: (_) => onTogglePermission(perm.name),
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
                                if (isRoleDefault) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEA580C).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'Role',
                                      style: TextStyle(fontSize: 10, color: Color(0xFFEA580C), fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Izin: ${perm.name}',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
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
            return Container(
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
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.person_add_rounded, color: AppTheme.primary, size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Tambah Pengguna Baru',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
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
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
                            ),
                            child: const Text('Batal'),
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
                                          ),
                                        );
                                      }
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
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
            child: const Text('Batal'),
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

  Widget _buildKpiSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 600;
          if (isNarrow) {
            return Row(
              children: [
                Expanded(child: _buildKpiCard('Total Pengguna', _users.length.toString(), Icons.people_alt_rounded, const Color(0xFF2563EB))),
                const SizedBox(width: 8),
                Expanded(child: _buildKpiCard('Super Admin', _countSuperAdmin.toString(), Icons.admin_panel_settings_rounded, const Color(0xFF4F46E5))),
                const SizedBox(width: 8),
                Expanded(child: _buildKpiCard('Staff Kasir', _countStaff.toString(), Icons.badge_rounded, const Color(0xFFD97706))),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: _buildKpiCard('Total Pengguna', _users.length.toString(), Icons.people_alt_rounded, const Color(0xFF2563EB))),
              const SizedBox(width: 12),
              Expanded(child: _buildKpiCard('Super Admin', _countSuperAdmin.toString(), Icons.admin_panel_settings_rounded, const Color(0xFF4F46E5))),
              const SizedBox(width: 12),
              Expanded(child: _buildKpiCard('Admin Sistem', _countAdmin.toString(), Icons.verified_user_rounded, const Color(0xFF0284C7))),
              const SizedBox(width: 12),
              Expanded(child: _buildKpiCard('Staff Kasir', _countStaff.toString(), Icons.badge_rounded, const Color(0xFFD97706))),
            ],
          );
        },
      ),
    );
  }

  Widget _buildKpiCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                ),
                Text(
                  label,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Cari nama atau email pengguna...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
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
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: _showCreateUserModal,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add User'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _showGlobalAssignRoleModal,
                icon: const Icon(Icons.security_rounded, size: 16, color: Color(0xFFEA580C)),
                label: const Text('Assign Role & Izin', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFEA580C))),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFEA580C), width: 1.2),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildRoleFilterChip('all', 'Semua (${_users.length})'),
                const SizedBox(width: 8),
                _buildRoleFilterChip('super-admin', 'Super Admin ($_countSuperAdmin)'),
                const SizedBox(width: 8),
                _buildRoleFilterChip('admin', 'Admin ($_countAdmin)'),
                const SizedBox(width: 8),
                _buildRoleFilterChip('staff', 'Staff Kasir ($_countStaff)'),
                const SizedBox(width: 8),
                _buildRoleFilterChip('none', 'Tanpa Role'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleFilterChip(String key, String label) {
    final isSelected = _selectedRoleFilter == key;
    return FilterChip(
      selected: isSelected,
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.white : const Color(0xFF475569),
        ),
      ),
      backgroundColor: Colors.white,
      selectedColor: AppTheme.primary,
      checkmarkColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: isSelected ? AppTheme.primary : Colors.grey.shade300),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      onSelected: (_) {
        setState(() => _selectedRoleFilter = key);
      },
    );
  }

  Widget _buildUserCard(UserRoleModel user) {
    final badgeColor = _getRoleBadgeColor(user.role);
    final initials = user.name.isNotEmpty
        ? user.name.trim().split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join('').toUpperCase()
        : 'U';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
                CircleAvatar(
                  radius: 20,
                  backgroundColor: badgeColor.withValues(alpha: 0.12),
                  child: Text(
                    initials,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: badgeColor,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Name & Email
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.mail_outline_rounded, size: 13, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              user.email,
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Role Badge & Permissions count badge
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: badgeColor.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.shield_outlined, size: 12, color: badgeColor),
                          const SizedBox(width: 4),
                          Text(
                            user.roleDisplay,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: badgeColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.vpn_key_rounded, size: 10, color: Colors.blueGrey.shade600),
                          const SizedBox(width: 3),
                          Text(
                            '${user.permissions.length} Izin',
                            style: TextStyle(fontSize: 10, color: Colors.blueGrey.shade700, fontWeight: FontWeight.w600),
                          ),
                          if (user.directPermissions.isNotEmpty) ...[
                            const SizedBox(width: 3),
                            Text(
                              '(+${user.directPermissions.length} Direct)',
                              style: const TextStyle(fontSize: 9, color: Color(0xFF059669), fontWeight: FontWeight.bold),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 20, color: Color(0xFFF1F5F9)),
            // Bottom Row: Created Date and Action Buttons
            Row(
              children: [
                Icon(Icons.calendar_today_outlined, size: 12, color: Colors.grey.shade400),
                const SizedBox(width: 4),
                Text(
                  user.createdAtFormatted ?? 'Baru saja',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
                const Spacer(),
                // Assign Role & Izin Button
                ElevatedButton.icon(
                  onPressed: () => _showAssignRoleModal(user),
                  icon: const Icon(Icons.key_rounded, size: 14),
                  label: const Text('Assign Role & Izin', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEA580C), // Orange accent matching web
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(width: 8),
                // Delete button
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  color: Colors.red.shade600,
                  tooltip: 'Hapus Pengguna',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: () => _confirmDeleteUser(user),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showGlobalAssignRoleModal() {
    if (_users.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Belum ada data pengguna.')),
      );
      return;
    }
    UserRoleModel selectedUser = _users.first;
    showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (context, setDlgState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.security_rounded, color: Color(0xFFEA580C), size: 22),
                SizedBox(width: 10),
                Text('Assign Role & Permission', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Pilih pengguna yang ingin diatur peran dan izinnya:'),
                const SizedBox(height: 12),
                DropdownButtonFormField<UserRoleModel>(
                  initialValue: selectedUser,
                  isExpanded: true,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: _users.map((u) {
                    return DropdownMenuItem(
                      value: u,
                      child: Text('${u.name} (${u.roleDisplay})', overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setDlgState(() => selectedUser = val);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dlgCtx).pop(),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEA580C),
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  Navigator.of(dlgCtx).pop();
                  _showAssignRoleModal(selectedUser);
                },
                child: const Text('Lanjut Atur Role & Izin'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.manage_accounts_outlined, size: 54, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            const Text(
              'Tidak ada pengguna ditemukan',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 4),
            const Text(
              'Coba ubah kata kunci pencarian atau filter role',
              style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody({bool isEmbedded = false}) {
    if (_isLoading) {
      return const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()));
    }

    final users = _filteredUsers;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildKpiSection(),
        _buildSearchAndFilters(),
        if (isEmbedded) ...[
          if (users.isEmpty)
            _buildEmptyState()
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: users.length,
              padding: const EdgeInsets.only(bottom: 24),
              itemBuilder: (context, index) {
                return _buildUserCard(users[index]);
              },
            ),
        ] else ...[
          Expanded(
            child: users.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    itemCount: users.length,
                    padding: const EdgeInsets.only(bottom: 24),
                    itemBuilder: (context, index) {
                      return _buildUserCard(users[index]);
                    },
                  ),
          ),
        ],
      ],
    );

    if (isEmbedded) {
      return content;
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: content,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isEmbedded) {
      return _buildBody(isEmbedded: true);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Users & Role Permissions'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.security_rounded),
            tooltip: 'Assign Role & Permission',
            onPressed: _showGlobalAssignRoleModal,
          ),
          IconButton(
            icon: const Icon(Icons.person_add_rounded),
            tooltip: 'Tambah Pengguna Baru',
            onPressed: _showCreateUserModal,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Segarkan data',
            onPressed: _loadData,
          ),
        ],
      ),
      body: _buildBody(isEmbedded: false),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateUserModal,
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Add User', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}
