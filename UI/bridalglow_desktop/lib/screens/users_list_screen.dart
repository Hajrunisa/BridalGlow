import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:bridalglow_desktop/models/user.dart';
import 'package:bridalglow_desktop/providers/user_provider.dart';

class UsersListScreen extends StatefulWidget {
  const UsersListScreen({super.key});

  @override
  State<UsersListScreen> createState() => _UsersListScreenState();
}

class _UsersListScreenState extends State<UsersListScreen> {
  List<User> _users = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _loading = true);
    try {
      final result = await context.read<UserProvider>().get(filter: {
        'includeTotalCount': true,
        'page': 0,
        'pageSize': 50,
      });
      setState(() => _users = result.items);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleActive(User user) async {
    final provider = context.read<UserProvider>();
    if (user.isActive) {
      await provider.deactivateUser(user.id);
    } else {
      await provider.activateUser(user.id);
    }
    await _loadUsers();
  }

  Future<void> _promoteToStaff(User user) async {
    try {
      await context.read<UserProvider>().promoteToSalonStaff(user.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${user.fullName} promoted to SalonStaff.'),
        ),
      );
      await _loadUsers();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Users', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 16),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.separated(
                    itemCount: _users.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final user = _users[index];
                      return ListTile(
                        title: Text(user.fullName),
                        subtitle: Text('${user.username} • ${user.roleName} • ${user.isActive ? 'Active' : 'Inactive'}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (user.isActive && user.isCustomer)
                              TextButton(
                                onPressed: () => _promoteToStaff(user),
                                child: const Text('Promote to SalonStaff'),
                              ),
                            TextButton(
                              onPressed: () => _toggleActive(user),
                              child: Text(
                                  user.isActive ? 'Deactivate' : 'Activate'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
