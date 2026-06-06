import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';

import 'add_checkpoint_dialog.dart';
import 'auth_service.dart';
import 'checkpoint.dart';
import 'checkpoint_drawer.dart';
import 'checkpoint_service.dart';
import 'status_update_sheet.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final AuthService _authService = AuthService();
  final CheckpointService _checkpointService = CheckpointService();

  GoogleMapController? _mapController;
  List<Checkpoint> _checkpoints = [];
  Set<Marker> _markers = {};
  final Map<String, BitmapDescriptor> _detailedMarkerCache = {};
  StreamSubscription<List<Checkpoint>>? _checkpointSub;
  StreamSubscription<UserRole>? _roleSub;
  UserRole _currentRole = UserRole.user;
  double _currentZoom = _initialCamera.zoom;
  int _markerBuildVersion = 0;
  bool _isLoadingCheckpoints = true;
  String? _checkpointError;

  static const CameraPosition _initialCamera = CameraPosition(
    target: LatLng(31.7054, 35.2024),
    zoom: 13,
  );

  @override
  void initState() {
    super.initState();
    _listenToRole();
    _listenToCheckpoints();
  }

  @override
  void dispose() {
    _checkpointSub?.cancel();
    _roleSub?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  void _listenToRole() {
    _roleSub = _authService.currentUserRoleChanges().listen((role) {
      if (!mounted) return;
      setState(() => _currentRole = role);
    });
  }

  void _listenToCheckpoints() {
    _checkpointSub = _checkpointService.getCheckpoints().listen(
      (checkpoints) async {
        if (!mounted) return;
        _checkpoints = checkpoints;
        final markers = await _buildMarkers(checkpoints);
        if (!mounted) return;
        setState(() {
          _markers = markers;
          _isLoadingCheckpoints = false;
          _checkpointError = null;
        });
      },
      onError: (Object error) {
        if (!mounted) return;
        setState(() {
          _isLoadingCheckpoints = false;
          _checkpointError = 'Could not load checkpoints. $error';
        });
      },
    );
  }

  int get _markerZoomBucket {
    final zoom = _currentZoom.clamp(12.0, 18.0);
    return (zoom * 2).round();
  }

  bool get _useDetailedMarkers => _currentZoom >= 15;

  double _markerScaleForBucket(int bucket) {
    final zoom = bucket / 2;
    final progress = ((zoom - 12) / 6).clamp(0.0, 1.0);
    return 0.72 + (progress * 0.22);
  }

  Future<void> _refreshMarkers() async {
    final markers = await _buildMarkers(_checkpoints);
    if (!mounted) return;
    setState(() => _markers = markers);
  }

  Future<Set<Marker>> _buildMarkers(List<Checkpoint> checkpoints) async {
    final buildVersion = ++_markerBuildVersion;
    final detailed = _useDetailedMarkers;
    final zoomBucket = _markerZoomBucket;
    final markers = <Marker>{};

    for (final cp in checkpoints) {
      if (buildVersion != _markerBuildVersion) return _markers;
      markers.add(
        Marker(
          markerId: MarkerId(cp.id),
          position: LatLng(cp.latitude, cp.longitude),
          icon: detailed
              ? await _detailedMarkerIcon(cp, zoomBucket)
              : _regularMarkerIcon(cp),
          anchor: const Offset(0.5, 1),
          infoWindow: InfoWindow(
            title: cp.name,
            snippet:
                'Entrance: ${cp.entranceStatus.label} | Exit: ${cp.exitStatus.label}',
            onTap: () => _showStatusSheet(cp),
          ),
          onTap: () {
            _mapController?.showMarkerInfoWindow(MarkerId(cp.id));
            _showStatusSheet(cp);
          },
        ),
      );
    }

    return markers;
  }

  Future<BitmapDescriptor> _detailedMarkerIcon(
    Checkpoint checkpoint,
    int zoomBucket,
  ) async {
    final cacheKey =
        '${checkpoint.id}-${checkpoint.name}-${checkpoint.entranceStatus.name}-${checkpoint.exitStatus.name}-$zoomBucket';
    final cached = _detailedMarkerCache[cacheKey];
    if (cached != null) return cached;

    final icon = await _CheckpointMarkerPainter(
      checkpoint,
      scale: _markerScaleForBucket(zoomBucket),
    ).toBitmap();
    _detailedMarkerCache[cacheKey] = icon;
    return icon;
  }

  BitmapDescriptor _regularMarkerIcon(Checkpoint checkpoint) {
    if (checkpoint.entranceStatus == CheckpointStatus.closed ||
        checkpoint.exitStatus == CheckpointStatus.closed) {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
    }
    if (checkpoint.entranceStatus == CheckpointStatus.crowded ||
        checkpoint.exitStatus == CheckpointStatus.crowded) {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow);
    }
    return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
  }

  void _showStatusSheet(Checkpoint checkpoint) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatusUpdateSheet(
        checkpoint: checkpoint,
        isAdmin: _currentRole.isAdmin,
        onUpdate: (entranceStatus, exitStatus) async {
          await _checkpointService.updateStatus(
            checkpointId: checkpoint.id,
            entranceStatus: entranceStatus,
            exitStatus: exitStatus,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Status updated successfully')),
            );
          }
        },
      ),
    );
  }

  void _onCheckpointDrawerTap(Checkpoint cp) {
    _focusCheckpoint(cp);
  }

  void _focusCheckpoint(Checkpoint cp) {
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(cp.latitude, cp.longitude), 15),
    );
    Future.delayed(const Duration(milliseconds: 500), () {
      _mapController?.showMarkerInfoWindow(MarkerId(cp.id));
    });
  }

  void _onCameraMove(CameraPosition position) {
    final wasDetailed = _useDetailedMarkers;
    final previousBucket = _markerZoomBucket;
    _currentZoom = position.zoom;
    final isDetailed = _useDetailedMarkers;
    if (wasDetailed != isDetailed ||
        (isDetailed && previousBucket != _markerZoomBucket)) {
      _refreshMarkers();
    }
  }

  void _showAddCheckpointDialog(LatLng position) {
    if (!_currentRole.isAdmin) return;
    showDialog(
      context: context,
      builder: (_) => AddCheckpointDialog(
        position: position,
        onAdd: ({
          required String name,
          required double latitude,
          required double longitude,
          XFile? image,
        }) async {
          await _checkpointService.addCheckpoint(
            name: name,
            latitude: latitude,
            longitude: longitude,
            image: image,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Checkpoint added')),
            );
          }
        },
      ),
    );
  }

  void _onLongPress(LatLng position) {
    if (!_currentRole.isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only admins can add checkpoints')),
      );
      return;
    }
    _showAddCheckpointDialog(position);
  }

  Future<void> _addCheckpointByCoordinates() async {
    var position = _initialCamera.target;
    final controller = _mapController;
    if (controller != null) {
      final bounds = await controller.getVisibleRegion();
      position = LatLng(
        (bounds.northeast.latitude + bounds.southwest.latitude) / 2,
        (bounds.northeast.longitude + bounds.southwest.longitude) / 2,
      );
    }
    if (mounted) _showAddCheckpointDialog(position);
  }

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) await _authService.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = _currentRole.isAdmin;
    final isCompact = MediaQuery.sizeOf(context).width < 600;
    final searchField = _CheckpointSearchField(
      checkpoints: _checkpoints,
      onSelected: _focusCheckpoint,
    );

    return Scaffold(
      appBar: AppBar(
        title: isCompact
            ? const Text('Smart Checkpoint')
            : Row(
                children: [
                  const Text('Smart Checkpoint'),
                  const SizedBox(width: 16),
                  Expanded(child: searchField),
                ],
              ),
        bottom: isCompact
            ? PreferredSize(
                preferredSize: const Size.fromHeight(58),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: searchField,
                ),
              )
            : null,
        actions: [
          if (isAdmin && !isCompact) const _AdminBadge(),
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.add_location_alt),
              tooltip: 'Add checkpoint by coordinates',
              onPressed: _addCheckpointByCoordinates,
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: _signOut,
          ),
        ],
      ),
      drawer: CheckpointDrawer(
        checkpoints: _checkpoints,
        authService: _authService,
        role: _currentRole,
        onCheckpointTap: _onCheckpointDrawerTap,
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: _initialCamera,
            markers: _markers,
            onMapCreated: (controller) => _mapController = controller,
            onCameraMove: _onCameraMove,
            onLongPress: _onLongPress,
            myLocationButtonEnabled: false,
            myLocationEnabled: false,
            zoomControlsEnabled: true,
            mapToolbarEnabled: false,
          ),
          if (_isLoadingCheckpoints)
            const Positioned(
              top: 16,
              left: 0,
              right: 0,
              child: Center(child: _MapMessage(text: 'Loading checkpoints...')),
            ),
          if (_checkpointError != null)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: _MapMessage(text: _checkpointError!, isError: true),
            ),
          Positioned(
            bottom: 24,
            left: 16,
            child: _buildLegend(),
          ),
          if (isAdmin)
            Positioned(
              top: 12,
              left: 0,
              right: 0,
              child: Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    child: Text(
                      'Long-press map or use + to add a checkpoint',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Marker status',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 6),
          _legendItem(CheckpointStatus.open.emoji, 'Open'),
          _legendItem(CheckpointStatus.closed.emoji, 'Closed'),
          _legendItem(CheckpointStatus.crowded.emoji, 'Crowded'),
        ],
      ),
    );
  }

  Widget _legendItem(String emoji, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

class _AdminBadge extends StatelessWidget {
  const _AdminBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.amber,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          Icon(Icons.admin_panel_settings, size: 14, color: Colors.black87),
          SizedBox(width: 4),
          Text(
            'Admin',
            style: TextStyle(
              color: Colors.black87,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _MapMessage extends StatelessWidget {
  final String text;
  final bool isError;

  const _MapMessage({
    required this.text,
    this.isError = false,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isError ? Colors.red.shade700 : Colors.black87,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ),
    );
  }
}

class _CheckpointSearchField extends StatelessWidget {
  final List<Checkpoint> checkpoints;
  final ValueChanged<Checkpoint> onSelected;

  const _CheckpointSearchField({
    required this.checkpoints,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 600;
    final optionsWidth =
        isCompact ? MediaQuery.sizeOf(context).width - 32 : 360.0;

    return Autocomplete<Checkpoint>(
      displayStringForOption: (checkpoint) => checkpoint.name,
      optionsBuilder: (value) {
        final query = value.text.trim().toLowerCase();
        if (query.isEmpty) return const Iterable<Checkpoint>.empty();
        return checkpoints.where((checkpoint) {
          return checkpoint.name.toLowerCase().contains(query);
        }).take(6);
      },
      onSelected: onSelected,
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return SizedBox(
          height: 40,
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            textInputAction: TextInputAction.search,
            onTapOutside: (_) => focusNode.unfocus(),
            onSubmitted: (_) {
              final match = _firstMatchingCheckpoint(controller.text);
              if (match != null) onSelected(match);
              focusNode.unfocus();
            },
            decoration: InputDecoration(
              hintText: isCompact ? 'Search' : 'Search checkpoint',
              prefixIcon: const Icon(Icons.search, size: 18),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: optionsWidth,
              height: math.min(260, options.length * 72.0),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final checkpoint = options.elementAt(index);
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.location_on_outlined),
                    title: Text(checkpoint.name),
                    subtitle: Text(
                      'Entrance: ${checkpoint.entranceStatus.label} | '
                      'Exit: ${checkpoint.exitStatus.label}',
                    ),
                    onTap: () {
                      FocusScope.of(context).unfocus();
                      onSelected(checkpoint);
                    },
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Checkpoint? _firstMatchingCheckpoint(String value) {
    final query = value.trim().toLowerCase();
    if (query.isEmpty) return null;

    for (final checkpoint in checkpoints) {
      if (checkpoint.name.toLowerCase() == query) return checkpoint;
    }
    for (final checkpoint in checkpoints) {
      if (checkpoint.name.toLowerCase().contains(query)) return checkpoint;
    }
    return null;
  }
}

class _CheckpointMarkerPainter {
  final Checkpoint checkpoint;
  final double scale;

  const _CheckpointMarkerPainter(
    this.checkpoint, {
    required this.scale,
  });

  Future<BitmapDescriptor> toBitmap() async {
    const imageRatio = 2.0;
    const bubbleHeight = 52.0;
    const pointerHeight = 16.0;
    const height = bubbleHeight + pointerHeight + 4;
    final statusText =
        'In: ${checkpoint.entranceStatus.label}  Out: ${checkpoint.exitStatus.label}';
    final contentWidth = math.max(
      _measureText(
        checkpoint.name,
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
      _measureText(
        statusText,
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
    );
    final width = math.min(226.0, math.max(138.0, contentWidth + 28));
    final logicalSize = Size(width * scale, height * scale);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(imageRatio * scale);

    final statusColor = _statusColor(checkpoint);
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    final labelRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, width, bubbleHeight),
      const Radius.circular(12),
    );

    final pinPath = Path()
      ..moveTo(width / 2, bubbleHeight + pointerHeight)
      ..lineTo((width / 2) - 10, bubbleHeight - 1)
      ..lineTo((width / 2) + 10, bubbleHeight - 1)
      ..close();

    canvas.drawRRect(labelRect.shift(const Offset(0, 2)), shadowPaint);
    canvas.drawPath(pinPath.shift(const Offset(0, 2)), shadowPaint);
    canvas.drawPath(pinPath, Paint()..color = Colors.white);
    canvas.drawRRect(labelRect, Paint()..color = Colors.white);
    canvas.drawRRect(
      labelRect,
      Paint()
        ..color = statusColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawPath(
      pinPath,
      Paint()
        ..color = statusColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    _drawText(
      canvas,
      checkpoint.name,
      const Offset(12, 7),
      maxWidth: width - 24,
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: const Color(0xFF1F2937),
    );
    final statusColumnWidth = (width - 28) / 2;
    _drawText(
      canvas,
      'In: ${checkpoint.entranceStatus.label}',
      const Offset(12, 29),
      maxWidth: statusColumnWidth,
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: _statusColorFromValue(checkpoint.entranceStatus),
    );
    _drawText(
      canvas,
      'Out: ${checkpoint.exitStatus.label}',
      Offset(16 + statusColumnWidth, 29),
      maxWidth: statusColumnWidth,
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: _statusColorFromValue(checkpoint.exitStatus),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      (logicalSize.width * imageRatio).round(),
      (logicalSize.height * imageRatio).round(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(
      bytes!.buffer.asUint8List(),
      imagePixelRatio: imageRatio,
      width: logicalSize.width,
      height: logicalSize.height,
    );
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset offset, {
    required double maxWidth,
    required double fontSize,
    required FontWeight fontWeight,
    required Color color,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
        ),
      ),
      maxLines: 1,
      ellipsis: '...',
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);

    painter.paint(canvas, offset);
  }

  double _measureText(
    String text, {
    required double fontSize,
    required FontWeight fontWeight,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: fontWeight,
        ),
      ),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();

    return painter.width;
  }

  Color _statusColor(Checkpoint checkpoint) {
    if (checkpoint.entranceStatus == CheckpointStatus.closed ||
        checkpoint.exitStatus == CheckpointStatus.closed) {
      return Colors.red;
    }
    if (checkpoint.entranceStatus == CheckpointStatus.crowded ||
        checkpoint.exitStatus == CheckpointStatus.crowded) {
      return Colors.orange;
    }
    return Colors.green;
  }

  Color _statusColorFromValue(CheckpointStatus status) {
    switch (status) {
      case CheckpointStatus.open:
        return Colors.green;
      case CheckpointStatus.closed:
        return Colors.red;
      case CheckpointStatus.crowded:
        return Colors.orange;
    }
  }
}
