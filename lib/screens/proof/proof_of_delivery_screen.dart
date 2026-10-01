import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/delivery.dart';
import '../../services/delivery_service.dart';

class ProofOfDeliveryScreen extends StatefulWidget {
  final Delivery delivery;
  final VoidCallback? onCompleted;

  const ProofOfDeliveryScreen({
    super.key,
    required this.delivery,
    this.onCompleted,
  });

  @override
  State<ProofOfDeliveryScreen> createState() => _ProofOfDeliveryScreenState();
}

class _ProofOfDeliveryScreenState extends State<ProofOfDeliveryScreen> {
  final ImagePicker _picker = ImagePicker();
  final DeliveryService _deliveryService = DeliveryService();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _recipientController = TextEditingController();

  XFile? _capturedImage;
  bool _isUploading = false;
  bool _permissionExplanationShown = false;
  String? _uploadError;

  @override
  void dispose() {
    _notesController.dispose();
    _recipientController.dispose();
    super.dispose();
  }

  /// Step 2 from Spec: Show a plain-language explanation before invoking camera
  Future<bool> _requestCameraPermissionExplanation() async {
    if (_permissionExplanationShown) return true;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.camera_alt_outlined, size: 48, color: Colors.deepOrange),
        title: const Text('Camera Permission Required'),
        content: const Text(
          'FleetFlow requires camera access to take a photo as Proof of Delivery (POD) for customer handover verification. The image will be securely uploaded to verify order completion.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Continue to Camera'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _permissionExplanationShown = true;
      return true;
    }
    return false;
  }

  Future<void> _takePhoto() async {
    final granted = await _requestCameraPermissionExplanation();
    if (!granted) return;

    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1600,
      );

      if (photo != null) {
        setState(() {
          _capturedImage = photo;
          _uploadError = null;
        });
      }
    } catch (e) {
      debugPrint('Camera error: $e. Falling back to option dialog.');
      if (mounted) {
        _showImageSourceSheet();
      }
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (photo != null) {
        setState(() {
          _capturedImage = photo;
          _uploadError = null;
        });
      }
    } catch (e) {
      setState(() => _uploadError = 'Could not select photo: $e');
    }
  }

  void _useDemoSamplePhoto() {
    // Quick fallback helper for emulators without camera
    setState(() {
      _capturedImage = XFile('https://images.unsplash.com/photo-1549465220-1a8b9238cd48?auto=format&fit=crop&w=800&q=80');
      _uploadError = null;
    });
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Take Photo with Camera'),
                onTap: () {
                  Navigator.pop(context);
                  _takePhoto();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickFromGallery();
                },
              ),
              ListTile(
                leading: const Icon(Icons.art_track),
                title: const Text('Use Demo Sample Photo (Emulator Mode)'),
                onTap: () {
                  Navigator.pop(context);
                  _useDemoSamplePhoto();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmAndSubmitProof() async {
    if (_capturedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please capture or choose a photo first')),
      );
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadError = null;
    });

    try {
      File? fileToUpload;
      if (!kIsWeb && !_capturedImage!.path.startsWith('http')) {
        fileToUpload = File(_capturedImage!.path);
      }

      await _deliveryService.submitProofOfDelivery(
        deliveryId: widget.delivery.id,
        photoFile: fileToUpload,
        location: {
          'lat': 37.7749,
          'lng': -122.4194,
          'address': widget.delivery.destination,
        },
        notes: _notesController.text.trim(),
        recipientName: _recipientController.text.trim().isNotEmpty
            ? _recipientController.text.trim()
            : widget.delivery.customerName,
      );

      if (mounted) {
        setState(() => _isUploading = false);
        _showSuccessDialog();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadError = 'Failed to submit proof: $e';
        });
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.check_circle, size: 56, color: Colors.green),
        title: const Text('Delivery Completed!'),
        content: Text(
          'Proof of Delivery for Order ${widget.delivery.id} was uploaded successfully. Status updated to Delivered and manager notified.',
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop(); // dismiss dialog
              if (widget.onCompleted != null) {
                widget.onCompleted!();
              } else {
                Navigator.of(context).pop(); // dismiss proof screen
              }
            },
            child: const Text('Finish'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Proof of Delivery (POD)'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Delivery Overview Card
              Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            widget.delivery.id,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'ARRIVED AT DESTINATION',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Customer: ${widget.delivery.customerName}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.location_on, size: 16, color: Colors.deepOrange),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              widget.delivery.destination,
                              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Image Capture / Preview Area
              Text(
                'Photo Evidence *',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (_capturedImage == null)
                InkWell(
                  onTap: _showImageSourceSheet,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 220,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300, width: 2),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.camera_enhance_outlined, size: 54, color: Colors.deepOrange.shade400),
                        const SizedBox(height: 12),
                        const Text(
                          'Tap to Capture Handover Photo',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Doorstep, recipient handover, or signed docket',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        height: 240,
                        width: double.infinity,
                        color: Colors.black,
                        child: _capturedImage!.path.startsWith('http')
                            ? Image.network(
                                _capturedImage!.path,
                                fit: BoxFit.cover,
                              )
                            : Image.file(
                                File(_capturedImage!.path),
                                fit: BoxFit.cover,
                              ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: _showImageSourceSheet,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retake Photo'),
                        ),
                      ],
                    ),
                  ],
                ),

              const SizedBox(height: 16),

              // Recipient & Notes Fields
              TextField(
                controller: _recipientController,
                decoration: InputDecoration(
                  labelText: 'Received By (Optional)',
                  hintText: 'e.g. John Doe (Customer / Receptionist)',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notesController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Delivery Notes (Optional)',
                  hintText: 'e.g. Left at front porch as requested by customer',
                  prefixIcon: const Icon(Icons.notes_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),

              if (_uploadError != null) ...[
                const SizedBox(height: 12),
                Text(
                  _uploadError!,
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                ),
              ],

              const SizedBox(height: 24),

              // Confirm Button
              FilledButton.icon(
                onPressed: _isUploading ? null : _confirmAndSubmitProof,
                icon: _isUploading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: Text(
                  _isUploading ? 'Uploading Proof...' : 'Confirm & Complete Delivery',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.green.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
