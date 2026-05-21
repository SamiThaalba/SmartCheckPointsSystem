import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';

class AddCheckpointDialog extends StatefulWidget {
  final LatLng position;
  final Future<void> Function({
    required String name,
    required double latitude,
    required double longitude,
    XFile? image,
  }) onAdd;

  const AddCheckpointDialog({
    super.key,
    required this.position,
    required this.onAdd,
  });

  @override
  State<AddCheckpointDialog> createState() => _AddCheckpointDialogState();
}

class _AddCheckpointDialogState extends State<AddCheckpointDialog> {
  final _nameController = TextEditingController();
  late final TextEditingController _latitudeController;
  late final TextEditingController _longitudeController;
  final _formKey = GlobalKey<FormState>();
  final _imagePicker = ImagePicker();
  XFile? _selectedImage;
  Uint8List? _selectedImageBytes;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _latitudeController = TextEditingController(
      text: widget.position.latitude.toStringAsFixed(6),
    );
    _longitudeController = TextEditingController(
      text: widget.position.longitude.toStringAsFixed(6),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      imageQuality: 82,
    );
    if (image == null) return;

    final bytes = await image.readAsBytes();
    if (!mounted) return;
    setState(() {
      _selectedImage = image;
      _selectedImageBytes = bytes;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      await widget.onAdd(
        name: _nameController.text.trim(),
        latitude: double.parse(_latitudeController.text.trim()),
        longitude: double.parse(_longitudeController.text.trim()),
        image: _selectedImage,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add checkpoint: $e'),
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
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.add_location_alt, color: Color(0xFF1565C0)),
          SizedBox(width: 8),
          Expanded(child: Text('Add Checkpoint')),
        ],
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Checkpoint name',
                  hintText: 'e.g. North Entrance',
                  prefixIcon: Icon(Icons.label_outline),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) return 'Please enter a name';
                  if (text.length < 3) return 'Name must be at least 3 chars';
                  return null;
                },
                onFieldSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _latitudeController,
                      keyboardType: const TextInputType.numberWithOptions(
                        signed: true,
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Latitude',
                        prefixIcon: Icon(Icons.north),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => _coordinateError(
                        value,
                        min: -90,
                        max: 90,
                        label: 'Latitude',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _longitudeController,
                      keyboardType: const TextInputType.numberWithOptions(
                        signed: true,
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Longitude',
                        prefixIcon: Icon(Icons.east),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => _coordinateError(
                        value,
                        min: -180,
                        max: 180,
                        label: 'Longitude',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _isSaving ? null : _submit,
          icon: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.add_location_alt),
          label: const Text('Add'),
        ),
      ],
    );
  }

  String? _coordinateError(
    String? value, {
    required double min,
    required double max,
    required String label,
  }) {
    final parsed = double.tryParse(value?.trim() ?? '');
    if (parsed == null) return '$label must be a number';
    if (parsed < min || parsed > max) return '$label is out of range';
    return null;
  }
}
