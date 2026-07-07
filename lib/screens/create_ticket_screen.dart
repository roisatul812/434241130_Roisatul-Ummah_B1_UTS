import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/supabase_service.dart';

class CreateTicketScreen extends StatefulWidget {
  const CreateTicketScreen({super.key});

  @override
  State<CreateTicketScreen> createState() => _CreateTicketScreenState();
}

class _CreateTicketScreenState extends State<CreateTicketScreen> {
  final TextEditingController titleController = TextEditingController();
  final TextEditingController descController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  String priority = "Medium";
  XFile? _selectedFile;
  bool _isSubmitting = false;

  /// Applies alpha to a color without deprecated opacity helpers.
  Color _alphaColor(Color color, double alpha) {
    return Color.fromARGB(
      (alpha * 255).round(),
      (color.r * 255).round(),
      (color.g * 255).round(),
      (color.b * 255).round(),
    );
  }

  @override
  void dispose() {
    titleController.dispose();
    descController.dispose();
    super.dispose();
  }

  /// Picks an attachment from camera or gallery.
  Future<void> _pickAttachment(ImageSource source) async {
    final file = await _imagePicker.pickImage(source: source, imageQuality: 85);
    if (file == null) {
      return;
    }

    setState(() {
      _selectedFile = file;
    });
  }

  /// Creates the ticket in Supabase and uploads the attachment if provided.
  Future<void> submitTicket() async {
    if (titleController.text.trim().isEmpty) return;

    final currentUser = SupabaseService.client.auth.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan login terlebih dahulu')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      String? attachmentUrl;
      if (_selectedFile != null) {
        attachmentUrl = await SupabaseService.uploadTicketAttachment(
          file: _selectedFile!,
          userId: currentUser.id,
        );
      }

      await SupabaseService.createTicket(
        title: titleController.text,
        description: descController.text,
        priority: priority.toLowerCase(),
        createdBy: currentUser.id,
        attachmentUrl: attachmentUrl,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ticket berhasil dibuat')));
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal membuat ticket: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final inputFill = isDark ? Theme.of(context).cardColor : Colors.white;

    final borderStyle = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(
        color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text("Create Ticket")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Judul", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),

            TextField(
              controller: titleController,
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
              decoration: InputDecoration(
                hintText: "Masukkan judul masalah",
                filled: true,
                fillColor: inputFill,
                border: borderStyle,
                enabledBorder: borderStyle,
                focusedBorder: borderStyle,
              ),
            ),

            const SizedBox(height: 15),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x12000000),
                    blurRadius: 18,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  _priorityPill(context, 'Low', Colors.green),
                  const SizedBox(width: 8),
                  _priorityPill(context, 'Medium', Colors.orange),
                  const SizedBox(width: 8),
                  _priorityPill(context, 'High', Colors.red),
                ],
              ),
            ),

            const SizedBox(height: 15),

            const Text(
              "Lampiran",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickAttachment(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Galeri'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickAttachment(ImageSource.camera),
                    icon: const Icon(Icons.photo_camera),
                    label: const Text('Kamera'),
                  ),
                ),
              ],
            ),

            if (_selectedFile != null) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.attachment),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_selectedFile!.name)),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 15),

            const Text(
              "Deskripsi",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            TextField(
              controller: descController,
              maxLines: 3,
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
              decoration: InputDecoration(
                hintText: "Jelaskan masalah",
                filled: true,
                fillColor: inputFill,
                border: borderStyle,
                enabledBorder: borderStyle,
                focusedBorder: borderStyle,
              ),
            ),

            const SizedBox(height: 15),

            const Text(
              "Prioritas",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            DropdownButtonFormField<String>(
              initialValue: priority,
              dropdownColor: inputFill,
              items: [
                "Low",
                "Medium",
                "High",
              ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (value) {
                setState(() {
                  priority = value!;
                });
              },
              decoration: InputDecoration(
                filled: true,
                fillColor: inputFill,
                border: borderStyle,
                enabledBorder: borderStyle,
                focusedBorder: borderStyle,
              ),
            ),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? Colors.white : Colors.black,
                  foregroundColor: isDark ? Colors.black : Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                onPressed: _isSubmitting ? null : submitTicket,
                child: _isSubmitting
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text("Submit Ticket"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a visual priority chip.
  Widget _priorityPill(BuildContext context, String label, Color color) {
    final selected = priority == label;

    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            priority = label;
          });
        },
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? _alphaColor(color, 0.14) : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: selected ? color : Colors.grey.shade300),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? color : Colors.grey.shade700,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
