import 'package:flutter/material.dart';

import 'checkpoint.dart';

class StatusUpdateSheet extends StatefulWidget {
  final Checkpoint checkpoint;
  final bool isAdmin;
  final Future<void> Function(
    CheckpointStatus entranceStatus,
    CheckpointStatus exitStatus,
  ) onUpdate;

  const StatusUpdateSheet({
    super.key,
    required this.checkpoint,
    required this.isAdmin,
    required this.onUpdate,
  });

  @override
  State<StatusUpdateSheet> createState() => _StatusUpdateSheetState();
}

class _StatusUpdateSheetState extends State<StatusUpdateSheet> {
  late CheckpointStatus _entranceStatus;
  late CheckpointStatus _exitStatus;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _entranceStatus = widget.checkpoint.entranceStatus;
    _exitStatus = widget.checkpoint.exitStatus;
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await widget.onUpdate(_entranceStatus, _exitStatus);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Icon(Icons.location_on, color: Color(0xFF1565C0), size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.checkpoint.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A237E),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            widget.isAdmin
                ? 'Admin override for entrance and exit directions'
                : 'Choose one of the predefined status options',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
          ),
          if (widget.checkpoint.updatedAt != null) ...[
            const SizedBox(height: 4),
            Text(
              'Last update: ${_formatUpdatedAt(widget.checkpoint.updatedAt!)}',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
          ],
          const SizedBox(height: 24),
          _buildStatusSection(
            label: 'Entrance Status',
            icon: Icons.login,
            currentStatus: _entranceStatus,
            onChanged: (status) => setState(() => _entranceStatus = status),
          ),
          const SizedBox(height: 20),
          _buildStatusSection(
            label: 'Exit Status',
            icon: Icons.logout,
            currentStatus: _exitStatus,
            onChanged: (status) => setState(() => _exitStatus = status),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Update Status',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusSection({
    required String label,
    required IconData icon,
    required CheckpointStatus currentStatus,
    required void Function(CheckpointStatus) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: Colors.grey.shade600),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: CheckpointStatus.values.map((status) {
            final isSelected = currentStatus == status;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _StatusButton(
                  status: status,
                  isSelected: isSelected,
                  onTap: () => onChanged(status),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

String _formatUpdatedAt(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.year}-${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')} $hour:$minute';
}

class _StatusButton extends StatelessWidget {
  final CheckpointStatus status;
  final bool isSelected;
  final VoidCallback onTap;

  const _StatusButton({
    required this.status,
    required this.isSelected,
    required this.onTap,
  });

  Color get _color {
    switch (status) {
      case CheckpointStatus.open:
        return Colors.green;
      case CheckpointStatus.closed:
        return Colors.red;
      case CheckpointStatus.crowded:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? _color : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? _color : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: _color.withValues(alpha: 0.3), blurRadius: 8)]
              : [],
        ),
        child: Column(
          children: [
            Text(status.emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 4),
            Text(
              status.label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
