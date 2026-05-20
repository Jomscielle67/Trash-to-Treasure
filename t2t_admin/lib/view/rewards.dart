import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

// Theme colors for T2T
const Color kPrimaryGreen = Color(0xFF2E7D32);
const Color kAccentGreen = Color(0xFF4CAF50);
const Color kLightGreen = Color(0xFF66BB6A);
const Color kErrorRed = Color(0xFFE53E3E);
const Color kCardShadow = Color(0x1A000000);

// Department list as constants
const List<String> kDepartments = [
  'Accountancy, Business and Management',
  'College of Computer Studies',
  'College of Hospitality Management and Tourism',
  'College of Teacher Education',
  'College of Engineering',
  'Senior High School',
  'Food safety and security',
  'College of Fisheries',
  'College of Industrial Technology',
  'College of Agriculture',
  'College of Nursing',
  'Business Affairs Office',
];

// Shorter display names for dropdown
const Map<String, String> kDepartmentDisplayNames = {
  'Accountancy, Business and Management': 'ABM',
  'College of Computer Studies': 'Computer Studies',
  'College of Hospitality Management and Tourism': 'Hospitality & Tourism',
  'College of Teacher Education': 'Teacher Education',
  'College of Engineering': 'Engineering',
  'Senior High School': 'Senior High School',
  'Food safety and security': 'Food Safety & Security',
  'College of Fisheries': 'Fisheries',
  'College of Industrial Technology': 'Industrial Technology',
  'College of Agriculture': 'Agriculture',
  'College of Nursing': 'Nursing',
  'Business Affairs Office': 'Business Affairs',
};

class RewardsScreen extends StatefulWidget {
  const RewardsScreen({super.key});

  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen> {
  String _filter = 'all'; // all, available, out

  Future<bool?> _showEditDialog({DocumentSnapshot? doc}) async {
    final nameCtrl = TextEditingController(
      text: doc != null ? (doc['name'] ?? '') : '',
    );
    final descCtrl = TextEditingController(
      text: doc != null ? (doc['description'] ?? '') : '',
    );
    final costCtrl = TextEditingController(
      text: doc != null ? (doc['cost']?.toString() ?? '') : '',
    );
    final stockCtrl = TextEditingController(
      text: doc != null ? (doc['stock']?.toString() ?? '') : '',
    );
    final imageCtrl = TextEditingController(
      text: doc != null ? (doc['imageUrl'] ?? '') : '',
    );

    String selectedDepartment =
        doc != null
            ? (doc['department'] ?? kDepartments.first)
            : kDepartments.first;
    final key = GlobalKey<FormState>();
    final isNew = doc == null;

    return await showDialog<bool>(
      context: context,
      builder: (context) {
        bool uploading = false;

        Future<void> pickAndUpload(StateSetter setState) async {
          try {
            final ImagePicker picker = ImagePicker();
            final XFile? file = await picker.pickImage(
              source: ImageSource.gallery,
              maxWidth: 1600,
              maxHeight: 1600,
              imageQuality: 85,
            );
            if (file == null) return;
            setState(() {
              uploading = true;
            });

            // Convert image to base64 for storage in Firestore
            final bytes = await file.readAsBytes();

            // Check if image is too large (limit to 1MB for Firestore)
            if (bytes.length > 1024 * 1024) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Row(
                      children: [
                        Icon(Icons.warning, color: Colors.white),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Image is too large. Please select an image smaller than 1MB.',
                          ),
                        ),
                      ],
                    ),
                    backgroundColor: kErrorRed,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
              setState(() {
                uploading = false;
              });
              return;
            }

            // Convert to base64
            final base64String = base64Encode(bytes);
            final imageUrl = 'data:image/jpeg;base64,$base64String';

            imageCtrl.text = imageUrl;
            setState(() {
              uploading = false;
            });

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.white),
                      SizedBox(width: 12),
                      Text('Image uploaded successfully!'),
                    ],
                  ),
                  backgroundColor: kAccentGreen,
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 2),
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Image upload failed: $e'),
                  backgroundColor: kErrorRed,
                ),
              );
            }
            setState(() {
              uploading = false;
            });
          }
        }

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: kAccentGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isNew ? Icons.add_circle_outline : Icons.edit_outlined,
                      color: kAccentGreen,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isNew ? 'Add New Reward' : 'Edit Reward',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isNew
                              ? 'Create a new reward for students'
                              : 'Update reward details',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF6B7280),
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 520,
                height: 600,
                child: Form(
                  key: key,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader(
                          'Basic Information',
                          Icons.info_outline,
                        ),
                        const SizedBox(height: 16),

                        _buildFormField(
                          label: 'Reward Name',
                          isRequired: true,
                          child: TextFormField(
                            controller: nameCtrl,
                            decoration: _buildInputDecoration(
                              'Enter reward name',
                            ),
                            style: const TextStyle(
                              color: Color(0xFF2D3748),
                              fontSize: 16,
                            ),
                            validator:
                                (v) =>
                                    v?.isEmpty == true
                                        ? 'Name is required'
                                        : null,
                          ),
                        ),

                        _buildFormField(
                          label: 'Description',
                          isRequired: false,
                          child: TextFormField(
                            controller: descCtrl,
                            decoration: _buildInputDecoration(
                              'Enter reward description',
                            ),
                            style: const TextStyle(
                              color: Color(0xFF2D3748),
                              fontSize: 16,
                            ),
                            maxLines: 3,
                          ),
                        ),

                        _buildSectionHeader(
                          'Points & Availability',
                          Icons.stars_outlined,
                        ),
                        const SizedBox(height: 16),

                        Row(
                          children: [
                            Expanded(
                              child: _buildFormField(
                                label: 'Points Cost',
                                isRequired: true,
                                child: TextFormField(
                                  controller: costCtrl,
                                  decoration: _buildInputDecoration('0'),
                                  style: const TextStyle(
                                    color: Color(0xFF2D3748),
                                    fontSize: 16,
                                  ),
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  validator: (v) {
                                    if (v?.isEmpty == true)
                                      return 'Cost is required';
                                    final cost = int.tryParse(v!);
                                    if (cost == null || cost < 0)
                                      return 'Invalid cost';
                                    return null;
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildFormField(
                                label: 'Stock Quantity',
                                isRequired: true,
                                child: TextFormField(
                                  controller: stockCtrl,
                                  decoration: _buildInputDecoration('0'),
                                  style: const TextStyle(
                                    color: Color(0xFF2D3748),
                                    fontSize: 16,
                                  ),
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  validator: (v) {
                                    if (v?.isEmpty == true)
                                      return 'Stock is required';
                                    final stock = int.tryParse(v!);
                                    if (stock == null || stock < 0)
                                      return 'Invalid stock';
                                    return null;
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),

                        _buildFormField(
                          label: 'Department',
                          isRequired: true,
                          child: DropdownButtonFormField<String>(
                            value: selectedDepartment,
                            decoration: _buildInputDecoration(
                              'Select department',
                            ),
                            style: const TextStyle(
                              color: Color(0xFF2D3748),
                              fontSize: 16,
                            ),
                            dropdownColor: Colors.white,
                            selectedItemBuilder: (BuildContext context) {
                              return kDepartments.map<Widget>((String dept) {
                                return Container(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    kDepartmentDisplayNames[dept] ?? dept,
                                    style: const TextStyle(
                                      color: Color(0xFF2D3748),
                                      fontSize: 16,
                                      fontWeight: FontWeight.normal,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList();
                            },
                            items:
                                kDepartments
                                    .map(
                                      (dept) => DropdownMenuItem(
                                        value: dept,
                                        child: Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 8,
                                            horizontal: 12,
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                kDepartmentDisplayNames[dept] ??
                                                    dept,
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  color: Color(0xFF2D3748),
                                                  fontWeight: FontWeight.w600,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1,
                                              ),
                                              if (kDepartmentDisplayNames[dept] !=
                                                      null &&
                                                  kDepartmentDisplayNames[dept] !=
                                                      dept) ...[
                                                const SizedBox(height: 2),
                                                Text(
                                                  dept,
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: Color(0xFF6B7280),
                                                    fontWeight:
                                                        FontWeight.normal,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  maxLines: 1,
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                            onChanged:
                                (v) => setState(() => selectedDepartment = v!),
                            validator:
                                (v) =>
                                    v?.isEmpty == true
                                        ? 'Department is required'
                                        : null,
                            icon: const Icon(
                              Icons.arrow_drop_down,
                              color: Color(0xFF6B7280),
                            ),
                            iconSize: 24,
                          ),
                        ),

                        _buildFormField(
                          label: 'Reward Image',
                          isRequired: false,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (imageCtrl.text.isNotEmpty && !uploading) ...[
                                Container(
                                  height: 160,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: Image.network(
                                    imageCtrl.text,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (_, __, ___) => Container(
                                          color: Colors.grey[100],
                                          child: const Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.broken_image,
                                                color: Colors.grey,
                                                size: 40,
                                              ),
                                              SizedBox(height: 8),
                                              Text(
                                                'Failed to load image',
                                                style: TextStyle(
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],

                              if (uploading) ...[
                                const LinearProgressIndicator(
                                  backgroundColor: Colors.grey,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    kAccentGreen,
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],

                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed:
                                          uploading
                                              ? null
                                              : () => pickAndUpload(setState),
                                      icon: Icon(
                                        uploading
                                            ? Icons.hourglass_empty
                                            : Icons.cloud_upload_outlined,
                                        size: 20,
                                      ),
                                      label: Text(
                                        uploading
                                            ? 'Uploading...'
                                            : 'Choose Image',
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: kAccentGreen,
                                        side: const BorderSide(
                                          color: kAccentGreen,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 14,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (imageCtrl.text.isNotEmpty &&
                                      !uploading) ...[
                                    const SizedBox(width: 12),
                                    IconButton(
                                      onPressed:
                                          () =>
                                              setState(() => imageCtrl.clear()),
                                      icon: const Icon(Icons.delete_outline),
                                      color: kErrorRed,
                                      tooltip: 'Remove image',
                                    ),
                                  ],
                                ],
                              ),

                              const SizedBox(height: 12),
                              TextFormField(
                                controller: imageCtrl,
                                decoration: _buildInputDecoration(
                                  'Or paste image URL here',
                                ),
                                style: const TextStyle(
                                  color: Color(0xFF2D3748),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF6B7280),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Cancel', style: TextStyle(fontSize: 16)),
                ),

                Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [kPrimaryGreen, kAccentGreen],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ElevatedButton.icon(
                    onPressed:
                        uploading
                            ? null
                            : () async {
                              if (!key.currentState!.validate()) return;

                              try {
                                final data = {
                                  'name': nameCtrl.text.trim(),
                                  'description': descCtrl.text.trim(),
                                  'cost': int.parse(costCtrl.text),
                                  'stock': int.parse(stockCtrl.text),
                                  'department': selectedDepartment,
                                  'imageUrl': imageCtrl.text.trim(),
                                  'updatedAt': FieldValue.serverTimestamp(),
                                };

                                if (isNew) {
                                  data['createdAt'] =
                                      FieldValue.serverTimestamp();
                                  await FirebaseFirestore.instance
                                      .collection('rewards')
                                      .add(data);
                                } else {
                                  await doc.reference.update(data);
                                }

                                Navigator.pop(context, true);
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Error: $e'),
                                      backgroundColor: kErrorRed,
                                    ),
                                  );
                                }
                              }
                            },
                    icon: const Icon(
                      Icons.save_outlined,
                      size: 20,
                      color: Colors.white,
                    ),
                    label: Text(
                      isNew ? 'Create Reward' : 'Update Reward',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: kAccentGreen, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A1A),
          ),
        ),
      ],
    );
  }

  Widget _buildFormField({
    required String label,
    required Widget child,
    bool isRequired = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              text: label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
              ),
              children: [
                if (isRequired)
                  const TextSpan(
                    text: ' *',
                    style: TextStyle(color: kErrorRed),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  InputDecoration _buildInputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 16),
      labelStyle: const TextStyle(color: Color(0xFF2D3748), fontSize: 16),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade400, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade400, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kAccentGreen, width: 2.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kErrorRed, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kErrorRed, width: 2.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Future<void> _deleteReward(DocumentSnapshot doc) async {
    final name = doc['name'] ?? 'reward';
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: kErrorRed.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.delete_forever,
                    color: kErrorRed,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Delete Reward',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ],
            ),
            content: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF374151),
                    height: 1.5,
                  ),
                  children: [
                    const TextSpan(text: 'Are you sure you want to delete '),
                    TextSpan(
                      text: '"$name"',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const TextSpan(
                      text:
                          '?\n\nThis action cannot be undone and will permanently remove the reward from the system.',
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF6B7280),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Cancel', style: TextStyle(fontSize: 16)),
              ),
              Container(
                decoration: BoxDecoration(
                  color: kErrorRed,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context, true),
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: Colors.white,
                  ),
                  label: const Text(
                    'Delete',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
    );

    if (ok != true) return;

    try {
      await doc.reference.delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Text('Successfully deleted "$name"'),
              ],
            ),
            backgroundColor: kAccentGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Text('Delete failed: $e'),
              ],
            ),
            backgroundColor: kErrorRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Stream<QuerySnapshot> rewardsStream;
    try {
      Query q = FirebaseFirestore.instance.collection('rewards');
      // Apply filter first, then order by to avoid composite index requirement
      if (_filter == 'available') {
        q = q
            .where('stock', isGreaterThan: 0)
            .orderBy('stock', descending: true);
      } else if (_filter == 'out') {
        // Bypass composite index by fetching all and filtering client-side
        q = q.orderBy('name');
      } else {
        // For 'all' filter, just order by name to avoid index issues
        q = q.orderBy('name');
      }
      rewardsStream = q.snapshots();
    } catch (e) {
      rewardsStream = const Stream.empty();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFE8F5E9),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Text(
                    'Rewards Management',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1B5E20),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                        _RewardHeader(
                          filter: _filter,
                          onFilterChanged: (v) => setState(() => _filter = v),
                          onAdd: () async {
                            final ok = await _showEditDialog();
                            if (ok == true && mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Row(
                                    children: [
                                      Icon(
                                        Icons.check_circle,
                                        color: Colors.white,
                                      ),
                                      SizedBox(width: 12),
                                      Text('Reward saved successfully!'),
                                    ],
                                  ),
                                  backgroundColor: kAccentGreen,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: StreamBuilder<QuerySnapshot>(
                            stream: rewardsStream,
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return ListView.builder(
                                  itemCount: 3,
                                  itemBuilder:
                                      (_, __) => Container(
                                        margin: const EdgeInsets.only(
                                          bottom: 16,
                                        ),
                                        child: Card(
                                          elevation: 4,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                          ),
                                          child: Container(
                                            height: 140,
                                            decoration: BoxDecoration(
                                              color: Colors.grey[100],
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                            child: Row(
                                              children: [
                                                Container(
                                                  width: 120,
                                                  height: 140,
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey[200],
                                                    borderRadius:
                                                        const BorderRadius.only(
                                                          topLeft:
                                                              Radius.circular(
                                                                16,
                                                              ),
                                                          bottomLeft:
                                                              Radius.circular(
                                                                16,
                                                              ),
                                                        ),
                                                  ),
                                                ),
                                                Expanded(
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.all(
                                                          16.0,
                                                        ),
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Container(
                                                          height: 16,
                                                          width:
                                                              double.infinity,
                                                          color:
                                                              Colors.grey[300],
                                                        ),
                                                        const SizedBox(
                                                          height: 8,
                                                        ),
                                                        Container(
                                                          height: 12,
                                                          width: 120,
                                                          color:
                                                              Colors.grey[300],
                                                        ),
                                                        const SizedBox(
                                                          height: 8,
                                                        ),
                                                        Container(
                                                          height: 12,
                                                          width: 80,
                                                          color:
                                                              Colors.grey[300],
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                );
                              }

                              if (snapshot.hasError) {
                                return Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.error_outline,
                                        size: 64,
                                        color: kErrorRed,
                                      ),
                                      const SizedBox(height: 16),
                                      const Text(
                                        'Error loading rewards',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF1A1A1A),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        '${snapshot.error}',
                                        style: const TextStyle(
                                          color: Color(0xFF6B7280),
                                          fontSize: 14,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                );
                              }

                              final allDocs = snapshot.data?.docs ?? [];

                              // Apply client-side filtering for 'out of stock' to bypass composite index
                              final docs =
                                  _filter == 'out'
                                      ? allDocs.where((doc) {
                                        final data =
                                            doc.data() as Map<String, dynamic>;
                                        final stock = data['stock'] ?? 0;
                                        return stock == 0;
                                      }).toList()
                                      : allDocs;

                              if (docs.isEmpty) {
                                return Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(32),
                                        decoration: BoxDecoration(
                                          color: kAccentGreen.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            24,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.card_giftcard_outlined,
                                          size: 80,
                                          color: kAccentGreen,
                                        ),
                                      ),
                                      const SizedBox(height: 24),
                                      const Text(
                                        'No rewards found',
                                        style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF1A1A1A),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        _filter == 'all'
                                            ? 'Create your first reward to get started'
                                            : 'No rewards match the current filter',
                                        style: const TextStyle(
                                          color: Color(0xFF6B7280),
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 32),
                                      Container(
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [
                                              kPrimaryGreen,
                                              kAccentGreen,
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: ElevatedButton.icon(
                                          onPressed: () => _showEditDialog(),
                                          icon: const Icon(
                                            Icons.add_circle_outline,
                                            size: 20,
                                            color: Colors.white,
                                          ),
                                          label: const Text(
                                            'Create First Reward',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.transparent,
                                            shadowColor: Colors.transparent,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 24,
                                              vertical: 16,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            elevation: 0,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }

                              return ListView.builder(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8.0,
                                ),
                                itemCount: docs.length,
                                itemBuilder: (context, i) {
                                  final doc = docs[i];
                                  final data =
                                      doc.data() as Map<String, dynamic>;
                                  final name = data['name'] ?? '';
                                  final cost = data['cost'] ?? 0;
                                  final stock = data['stock'] ?? 0;
                                  final department = data['department'] ?? '';
                                  final image = data['imageUrl'] as String?;
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 16),
                                    child: _RewardCard(
                                      name: name,
                                      cost: cost,
                                      stock: stock,
                                      department: department,
                                      image: image,
                                      onEdit: () async {
                                        final ok = await _showEditDialog(
                                          doc: doc,
                                        );
                                        if (ok == true && mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: const Row(
                                                children: [
                                                  Icon(
                                                    Icons.check_circle,
                                                    color: Colors.white,
                                                  ),
                                                  SizedBox(width: 12),
                                                  Text(
                                                    'Reward updated successfully!',
                                                  ),
                                                ],
                                              ),
                                              backgroundColor: kAccentGreen,
                                              behavior:
                                                  SnackBarBehavior.floating,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                      onDelete: () => _deleteReward(doc),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  ),
                ],
          ),
          ),
    );
  }
}

class _RewardHeader extends StatelessWidget {
  final String filter;
  final ValueChanged<String> onFilterChanged;
  final VoidCallback onAdd;
  const _RewardHeader({
    required this.filter,
    required this.onFilterChanged,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                _FilterButton(
                  text: 'All',
                  isSelected: filter == 'all',
                  onTap: () => onFilterChanged('all'),
                ),
                _FilterButton(
                  text: 'Available',
                  isSelected: filter == 'available',
                  onTap: () => onFilterChanged('available'),
                ),
                _FilterButton(
                  text: 'Out of Stock',
                  isSelected: filter == 'out',
                  onTap: () => onFilterChanged('out'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [kPrimaryGreen, kAccentGreen],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add, size: 20, color: Colors.white),
            label: const Text(
              'Add Reward',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(0, 76, 168, 76),
              shadowColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
          ),
        ),
      ],
    );
  }
}

class _FilterButton extends StatelessWidget {
  final String text;
  final bool isSelected;
  final VoidCallback onTap;
  const _FilterButton({
    required this.text,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? kPrimaryGreen : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : const Color(0xFF6B7280),
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

class _RewardCard extends StatelessWidget {
  final String name;
  final int cost;
  final int stock;
  final String department;
  final String? image;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _RewardCard({
    required this.name,
    required this.cost,
    required this.stock,
    required this.department,
    required this.image,
    required this.onEdit,
    required this.onDelete,
  });

  // Helper method to get image widget for reward
  Widget _buildRewardImage() {
    if (image == null || image!.isEmpty) {
      return Container(
        color: Colors.grey[100],
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.card_giftcard, color: Colors.grey, size: 32),
            SizedBox(height: 4),
            Text(
              'No Image',
              style: TextStyle(color: Colors.grey, fontSize: 10),
            ),
          ],
        ),
      );
    }

    try {
      if (image!.startsWith('data:image')) {
        // Handle base64 images
        final base64String = image!.split(',')[1];
        final bytes = base64Decode(base64String);
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          errorBuilder:
              (_, __, ___) => Container(
                color: Colors.grey[100],
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.broken_image, color: Colors.grey, size: 32),
                    SizedBox(height: 4),
                    Text(
                      'Invalid Image',
                      style: TextStyle(color: Colors.grey, fontSize: 10),
                    ),
                  ],
                ),
              ),
        );
      } else {
        // Handle network URLs
        return Image.network(
          image!,
          fit: BoxFit.cover,
          errorBuilder:
              (_, __, ___) => Container(
                color: Colors.grey[100],
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.broken_image, color: Colors.grey, size: 32),
                    SizedBox(height: 4),
                    Text(
                      'Failed to Load',
                      style: TextStyle(color: Colors.grey, fontSize: 10),
                    ),
                  ],
                ),
              ),
        );
      }
    } catch (e) {
      return Container(
        color: Colors.grey[100],
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.grey, size: 32),
            SizedBox(height: 4),
            Text('Error', style: TextStyle(color: Colors.grey, fontSize: 10)),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isOutOfStock = stock <= 0;
    final theme = Theme.of(context);
    final text = theme.textTheme;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Stack(
          children: [
            Row(
              children: [
                // Image Section
                Container(
                  width: 120,
                  height: 180,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                    ),
                    child: _buildRewardImage(),
                  ),
                ),

                // Content Section
                Expanded(
                  child: Column(
                    children: [
                      // Main content area
                      Expanded(
                        child: Container(
                          color: Colors.white,
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Name and Department
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: text.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF1A1A1A),
                                        fontSize: 16,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 6),
                                    Expanded(
                                      child: Text(
                                        department,
                                        style: text.bodySmall?.copyWith(
                                          color: const Color(0xFF6B7280),
                                          fontSize: 11,
                                          height: 1.2,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Cost and Stock Row
                              Expanded(
                                flex: 1,
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: kAccentGreen.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '$cost pts',
                                        style: text.bodySmall?.copyWith(
                                          color: kPrimaryGreen,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            isOutOfStock
                                                ? kErrorRed.withOpacity(0.1)
                                                : Colors.green.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'Stock: $stock',
                                        style: text.bodySmall?.copyWith(
                                          color:
                                              isOutOfStock
                                                  ? kErrorRed
                                                  : Colors.green[700],
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Action Buttons at bottom
                      Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: const BorderRadius.only(
                            bottomRight: Radius.circular(16),
                          ),
                          border: Border(
                            top: BorderSide(
                              color: Colors.grey.shade200,
                              width: 1,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withOpacity(0.1),
                                    blurRadius: 2,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      onPressed: () {
                                        print('Edit button pressed for: $name');
                                        onEdit();
                                      },
                                      icon: const Icon(
                                        Icons.edit_outlined,
                                        size: 18,
                                      ),
                                      color: kPrimaryGreen,
                                      padding: const EdgeInsets.all(8),
                                      constraints: const BoxConstraints(
                                        minWidth: 32,
                                        minHeight: 32,
                                      ),
                                      splashRadius: 16,
                                      tooltip: 'Edit reward',
                                    ),
                                    Container(
                                      width: 1,
                                      height: 20,
                                      color: Colors.grey.shade300,
                                    ),
                                    IconButton(
                                      onPressed: () {
                                        print(
                                          'Delete button pressed for: $name',
                                        );
                                        onDelete();
                                      },
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        size: 18,
                                      ),
                                      color: kErrorRed,
                                      padding: const EdgeInsets.all(8),
                                      constraints: const BoxConstraints(
                                        minWidth: 32,
                                        minHeight: 32,
                                      ),
                                      splashRadius: 16,
                                      tooltip: 'Delete reward',
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Out of Stock Overlay
            if (isOutOfStock)
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: kErrorRed,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: kErrorRed.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    'OUT OF STOCK',
                    style: text.bodySmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
