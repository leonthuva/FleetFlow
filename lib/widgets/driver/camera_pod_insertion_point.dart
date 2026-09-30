import 'package:flutter/material.dart';

/// Contract & Insertion Point for:
/// - Member 5: Proof-of-Delivery camera integration, signature capture,
///   and Firebase Storage photo upload.
class CameraPodInsertionPoint extends StatefulWidget {
  final String deliveryId;
  final String? initialPhotoUrl;
  final String? initialNotes;
  final ValueChanged<String>? onPhotoCaptured;
  final void Function(String recipientName, String notes)? onDetailsSubmitted;
  final bool isRequired;

  const CameraPodInsertionPoint({
    super.key,
    required this.deliveryId,
    this.initialPhotoUrl,
    this.initialNotes,
    this.onPhotoCaptured,
    this.onDetailsSubmitted,
    this.isRequired = true,
  });

  @override
  State<CameraPodInsertionPoint> createState() => _CameraPodInsertionPointState();
}

class _CameraPodInsertionPointState extends State<CameraPodInsertionPoint> {
  late final TextEditingController _recipientNameController;
  late final TextEditingController _notesController;
  String? _capturedPhotoPreview;

  @override
  void initState() {
    super.initState();
    _recipientNameController = TextEditingController();
    _notesController = TextEditingController(text: widget.initialNotes ?? '');
    _capturedPhotoPreview = widget.initialPhotoUrl;
  }

  @override
  void dispose() {
    _recipientNameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _simulatePhotoCapture() {
    // Contract mock: Simulate camera hardware capture or delegate to Member 5 image_picker
    final mockCapturedUrl =
        'https://storage.googleapis.com/fleetflow-dev/pod/${widget.deliveryId}_pod.jpg';
    setState(() {
      _capturedPhotoPreview = mockCapturedUrl;
    });
    if (widget.onPhotoCaptured != null) {
      widget.onPhotoCaptured!(mockCapturedUrl);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasPhoto = _capturedPhotoPreview != null && _capturedPhotoPreview!.isNotEmpty;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Insertion Header Banner (Contract Agreement)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.purple.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.camera_alt_outlined, color: Colors.purple.shade700, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Camera & POD Insertion Point (Member 5 Component)',
                      style: TextStyle(
                        color: Colors.purple.shade900,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            Text(
              'Proof of Delivery (POD)',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Capture recipient signature or photo of delivered parcel at the doorstep.',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),

            // Photo Capture Slot
            GestureDetector(
              onTap: _simulatePhotoCapture,
              child: Container(
                height: 150,
                decoration: BoxDecoration(
                  color: hasPhoto ? Colors.purple.shade900 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: hasPhoto ? Colors.purple : Colors.grey.shade300,
                    width: 1.5,
                    style: hasPhoto ? BorderStyle.solid : BorderStyle.solid,
                  ),
                ),
                child: hasPhoto
                    ? Stack(
                        alignment: Alignment.center,
                        children: [
                          Positioned.fill(
                            child: Container(
                              color: Colors.purple.shade900.withOpacity(0.8),
                              child: const Icon(Icons.check_circle_outline, color: Colors.white, size: 54),
                            ),
                          ),
                          Positioned(
                            bottom: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black70,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'POD Photo Captured (Tap to retake)',
                                style: TextStyle(color: Colors.white, fontSize: 11),
                              ),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo_outlined, size: 40, color: Colors.purple.shade400),
                          const SizedBox(height: 8),
                          Text(
                            'Tap to Capture Delivery Photo',
                            style: TextStyle(
                              color: Colors.purple.shade700,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.isRequired ? '(Required before completion)' : '(Optional)',
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 16),

            // Recipient Received-By Name
            TextField(
              controller: _recipientNameController,
              decoration: InputDecoration(
                labelText: 'Received By (Name / Title)',
                hintText: 'e.g. John Doe, Receptionist',
                prefixIcon: const Icon(Icons.badge_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              onChanged: (val) {
                if (widget.onDetailsSubmitted != null) {
                  widget.onDetailsSubmitted!(val, _notesController.text);
                }
              },
            ),
            const SizedBox(height: 12),

            // Handover Delivery Notes
            TextField(
              controller: _notesController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Delivery Notes / Condition',
                hintText: 'e.g. Left on front porch behind pillar as requested.',
                prefixIcon: const Icon(Icons.notes_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              onChanged: (val) {
                if (widget.onDetailsSubmitted != null) {
                  widget.onDetailsSubmitted!(_recipientNameController.text, val);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
