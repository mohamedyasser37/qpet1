import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vet/main.dart';

class AddAnimalView extends StatefulWidget {
  const AddAnimalView({super.key});

  @override
  State<AddAnimalView> createState() => _AddAnimalViewState();
}

class _AddAnimalViewState extends State<AddAnimalView> {
  final _formKey = GlobalKey<FormState>();
  final _qrKey = GlobalKey();
  final _animalNameController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _ownerPhoneController = TextEditingController();

  String selectedAnimalType = 'قطة';
  String? generatedUrl;
  String? editPassword;
  bool isSaving = false;

  String _generateRandomPassword() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    return String.fromCharCodes(Iterable.generate(6, (_) => chars.codeUnitAt(Random().nextInt(chars.length))));
  }

  Future<void> _shareQrCode() async {
    try {
      RenderRepaintBoundary boundary = _qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      final directory = await getTemporaryDirectory();
      final imagePath = await File('${directory.path}/qr_code.png').create();
      await imagePath.writeAsBytes(pngBytes);

      await Share.shareXFiles(
        [XFile(imagePath.path)],
        text: 'QPet - بيانات الأليف: ${_animalNameController.text}\nكلمة سر التعديل: $editPassword',
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isAr = MyApp.of(context).locale.languageCode == 'ar';
    Color primaryColor = Theme.of(context).primaryColor;
    final List<String> animalTypes = isAr 
      ? ['قطة', 'كلب', 'طائر', 'أرنب', 'هامستر']
      : ['Cat', 'Dog', 'Bird', 'Rabbit', 'Hamster'];

    return Scaffold(
      appBar: AppBar(
        title: Text(isAr ? 'إضافة أليف جديد' : 'Add New Pet'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.pets, size: 80, color: primaryColor),
              const SizedBox(height: 32),
              _buildTextField(_animalNameController, isAr ? 'اسم الحيوان' : 'Pet Name', Icons.badge, primaryColor),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: isAr ? selectedAnimalType : _translateType(selectedAnimalType),
                decoration: InputDecoration(
                  labelText: isAr ? 'نوع الحيوان' : 'Animal Type',
                  prefixIcon: Icon(Icons.category, color: primaryColor),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: animalTypes.map((String type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
                onChanged: (String? val) => setState(() => selectedAnimalType = isAr ? val! : _reverseTranslate(val!)),
              ),
              const SizedBox(height: 16),
              _buildTextField(_ownerNameController, isAr ? 'اسم الصاحب' : 'Owner Name', Icons.person, primaryColor),
              const SizedBox(height: 16),
              _buildTextField(_ownerPhoneController, isAr ? 'رقم الهاتف' : 'Phone Number', Icons.phone, primaryColor, keyboardType: TextInputType.phone),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                onPressed: isSaving ? null : _saveToFirebase,
                icon: isSaving ? const CircularProgressIndicator(color: Colors.white) : const Icon(Icons.qr_code),
                label: Text(isSaving ? (isAr ? 'جاري الحفظ...' : 'Saving...') : (isAr ? 'إنشاء الرمز وكلمة السر' : 'Create QR & Pass')),
                style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _translateType(String type) {
    Map<String, String> map = {'قطة': 'Cat', 'كلب': 'Dog', 'طائر': 'Bird', 'أرنب': 'Rabbit', 'هامستر': 'Hamster'};
    return map[type] ?? type;
  }
  String _reverseTranslate(String type) {
    Map<String, String> map = {'Cat': 'قطة', 'Dog': 'كلب', 'Bird': 'طائر', 'Rabbit': 'أرنب', 'Hamster': 'هامستر'};
    return map[type] ?? type;
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, Color color, {TextInputType? keyboardType}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon, color: color), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
      validator: (value) => value!.isEmpty ? (MyApp.of(context).locale.languageCode == 'ar' ? 'مطلوب' : 'Required') : null,
    );
  }

  Future<void> _saveToFirebase() async {
    if (_formKey.currentState!.validate()) {
      setState(() => isSaving = true);
      try {
        final newPassword = _generateRandomPassword();
        final docRef = await FirebaseFirestore.instance.collection('pets').add({
          'animalName': _animalNameController.text,
          'animalType': selectedAnimalType,
          'ownerName': _ownerNameController.text,
          'ownerPhone': _ownerPhoneController.text,
          'editPassword': newPassword,
          'timestamp': FieldValue.serverTimestamp(),
        });

        // رابط GitHub Pages الحقيقي
        final url = 'https://mohamedyasser37.github.io/qpet1/#/pet/${docRef.id}';
        
        setState(() {
          generatedUrl = url;
          editPassword = newPassword;
          isSaving = false;
        });
        _showQrDialog();
      } catch (e) {
        setState(() => isSaving = false);
      }
    }
  }

  void _showQrDialog() {
    bool isAr = MyApp.of(context).locale.languageCode == 'ar';
    Color primaryColor = Theme.of(context).primaryColor;
    showGeneralDialog(
      context: context,
      pageBuilder: (context, anim1, anim2) => const SizedBox.shrink(),
      transitionBuilder: (context, anim1, anim2, child) {
        return Transform.scale(
          scale: anim1.value,
          child: Opacity(
            opacity: anim1.value,
            child: AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Center(child: Text(isAr ? 'تم التسجيل بنجاح' : 'Registered Successfully')),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RepaintBoundary(
                      key: _qrKey,
                      child: Container(
                        color: Colors.white,
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            Icon(Icons.pets, color: primaryColor, size: 30),
                            const SizedBox(height: 10),
                            SizedBox(width: 180, height: 180, child: QrImageView(data: generatedUrl!, version: QrVersions.auto, eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.circle, color: primaryColor))),
                            const SizedBox(height: 10),
                            Text(_animalNameController.text, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: primaryColor)),
                          ],
                        ),
                      ),
                    ),
                    const Divider(),
                    Text(isAr ? 'كلمة سر التعديل:' : 'Edit Password:', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      width: double.infinity,
                      decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(15)),
                      child: ListTile(
                        title: Text(editPassword!, textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: primaryColor, letterSpacing: 3)),
                        trailing: IconButton(
                          icon: Icon(Icons.copy_all, color: primaryColor),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: editPassword!));
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isAr ? 'تم النسخ' : 'Copied')));
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton.icon(
                  onPressed: _shareQrCode,
                  icon: Icon(Icons.share, color: primaryColor),
                  label: Text(isAr ? 'مشاركة أو حفظ' : 'Share or Save', style: TextStyle(color: primaryColor)),
                ),
                TextButton(onPressed: () => Navigator.pop(context), child: Text(isAr ? 'إغلاق' : 'Close')),
              ],
            ),
          ),
        );
      },
    );
  }
}
