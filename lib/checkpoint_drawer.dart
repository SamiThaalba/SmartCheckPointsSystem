import 'package:flutter/material.dart';

import 'auth_service.dart';
import 'checkpoint.dart';

class CheckpointDrawer extends StatelessWidget {
  final List<Checkpoint> checkpoints;
  final AuthService authService;
  final UserRole role;
  final void Function(Checkpoint) onCheckpointTap;

  const CheckpointDrawer({
    super.key,
    required this.checkpoints,
    required this.authService,
    required this.role,
    required this.onCheckpointTap,
  });

  @override
  Widget build(BuildContext context) {
    final user = authService.currentUser;
    final isAdmin = role.isAdmin;

    return Drawer(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 16,
              left: 20,
              right: 20,
              bottom: 20,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0D47A1), Color(0xFF1976D2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundImage: user?.photoURL != null
                      ? NetworkImage(user!.photoURL!)
                      : null,
                  backgroundColor: Colors.white30,
                  child: user?.photoURL == null
                      ? Text(
                          (user?.displayName ?? 'U')[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                const SizedBox(height: 12),
                Text(
                  user?.displayName ?? 'User',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  user?.email ?? '',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isAdmin ? Colors.amber : Colors.white24,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isAdmin ? Icons.admin_panel_settings : Icons.person,
                        size: 12,
                        color: isAdmin ? Colors.black87 : Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isAdmin ? 'Admin' : 'User',
                        style: TextStyle(
                          color: isAdmin ? Colors.black87 : Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                const Icon(
                  Icons.list_alt,
                  size: 18,
                  color: Color(0xFF1565C0),
                ),
                const SizedBox(width: 8),
                Text(
                  'Checkpoints (${checkpoints.length})',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF1A237E),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: checkpoints.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.location_off, size: 48, color: Colors.grey),
                        SizedBox(height: 12),
                        Text(
                          'No checkpoints yet',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: checkpoints.length,
                    itemBuilder: (context, index) {
                      final cp = checkpoints[index];
                      return ListTile(
                        onTap: () {
                          Navigator.pop(context);
                          onCheckpointTap(cp);
                        },
                        leading: CircleAvatar(
                          backgroundColor: Colors.blueGrey.shade50,
                          child: Text(
                            cp.entranceStatus.emoji,
                            style: const TextStyle(fontSize: 17),
                          ),
                        ),
                        title: Text(
                          cp.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          'Entrance: ${cp.entranceStatus.label} | '
                          'Exit: ${cp.exitStatus.label}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: const Icon(
                          Icons.chevron_right,
                          size: 18,
                          color: Colors.grey,
                        ),
                      );
                    },
                  ),
          ),
          const Divider(height: 1),
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'Smart Checkpoint | SWER354B | 2026',
              style: TextStyle(color: Colors.grey, fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
