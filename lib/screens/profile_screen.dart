import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../widgets/custom_button.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.authService,
    required this.onLogout,
  });

  final AuthService authService;
  final VoidCallback onLogout;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<UserModel> _future;
  bool _isLoggingOut = false;

  @override
  void initState() {
    super.initState();
    _future = widget.authService.profile();
  }

  Future<void> _logout() async {
    setState(() => _isLoggingOut = true);
    try {
      await widget.authService.logout();
      if (!mounted) return;
      widget.onLogout();
    } on ApiException catch (error) {
      _showMessage(error.message);
    } finally {
      if (mounted) {
        setState(() => _isLoggingOut = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: FutureBuilder<UserModel>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text('Gagal memuat profil: ${snapshot.error}'),
              ],
            );
          }

          final user = snapshot.data!;

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 34,
                        child: Text(
                          user.name.isEmpty ? '?' : user.name[0].toUpperCase(),
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        user.name,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(user.position ?? user.nip ?? '-'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _ProfileRow(label: 'Username', value: user.username),
                      _ProfileRow(label: 'Email', value: user.email),
                      _ProfileRow(label: 'NIP', value: user.nip),
                      _ProfileRow(label: 'Unit', value: user.unit),
                      _ProfileRow(label: 'Departemen', value: user.department),
                      _ProfileRow(label: 'No HP', value: user.noHp),
                      _ProfileRow(label: 'Alamat', value: user.alamat),
                      _ProfileRow(
                        label: 'Data wajah',
                        value: user.hasFaceEnrollment
                            ? 'Sudah terdaftar'
                            : 'Belum terdaftar',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              CustomButton(
                label: 'Logout',
                icon: Icons.logout,
                isLoading: _isLoggingOut,
                backgroundColor: Colors.red,
                onPressed: _logout,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          Expanded(child: Text(value?.isNotEmpty == true ? value! : '-')),
        ],
      ),
    );
  }
}
