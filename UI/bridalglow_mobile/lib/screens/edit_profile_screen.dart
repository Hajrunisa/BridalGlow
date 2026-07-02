import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:bridalglow_mobile/providers/user_provider.dart';
import 'package:bridalglow_mobile/utils/session_storage.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _phoneController;
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final user = UserProvider.currentUser;
    _firstNameController = TextEditingController(text: user?.firstName ?? '');
    _lastNameController = TextEditingController(text: user?.lastName ?? '');
    _phoneController = TextEditingController(text: user?.phone ?? '');
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    final userProvider = context.read<UserProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _loading = true);
    try {
      await userProvider.updateMyProfile({
        'firstName': _firstNameController.text.trim(),
        'lastName': _lastNameController.text.trim(),
        'phone': _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
      });
      if (UserProvider.currentUser != null) {
        await SessionStorage.updateUser(UserProvider.currentUser!);
      }
      if (_newPasswordController.text.isNotEmpty) {
        await userProvider.changePassword(
          _currentPasswordController.text,
          _newPasswordController.text,
        );
      }
      if (!mounted) return;
      navigator.pop();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(controller: _firstNameController, decoration: const InputDecoration(labelText: 'First name'), validator: (v) => v == null || v.isEmpty ? 'Required' : null),
              TextFormField(controller: _lastNameController, decoration: const InputDecoration(labelText: 'Last name'), validator: (v) => v == null || v.isEmpty ? 'Required' : null),
              TextFormField(controller: _phoneController, decoration: const InputDecoration(labelText: 'Phone')),
              const Divider(height: 32),
              TextFormField(controller: _currentPasswordController, decoration: const InputDecoration(labelText: 'Current password (optional)'), obscureText: true),
              TextFormField(controller: _newPasswordController, decoration: const InputDecoration(labelText: 'New password (optional)'), obscureText: true),
              const SizedBox(height: 24),
              _loading ? const CircularProgressIndicator() : ElevatedButton(onPressed: _saveProfile, child: const Text('Save')),
            ],
          ),
        ),
      ),
    );
  }
}
