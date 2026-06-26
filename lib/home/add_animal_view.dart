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

  String? generatedUrl;
  String? editPassword;
  String? currentPetId;
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
              const SizedBox(height: 20),
              Icon(Icons.pets, size: 80, color: primaryColor),
              const SizedBox(height: 32),
              Text(isAr ? 'أدخل اسم الأليف لإنشاء الرمز' : 'Enter pet name to generate QR', 
                textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 20),
              TextFormField(
                controller: _animalNameController,
                decoration: InputDecoration(
                  labelText: isAr ? 'اسم الحيوان' : 'Pet Name', 
                  prefixIcon: Icon(Icons.badge, color: primaryColor), 
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))
                ),
                validator: (value) => value!.isEmpty ? (isAr ? 'مطلوب' : 'Required') : null,
              ),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                onPressed: isSaving ? null : _saveToFirebase,
                icon: isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.qr_code),
                label: Text(isSaving ? (isAr ? 'جاري الحفظ...' : 'Saving...') : (isAr ? 'إنشاء الرمز وكلمة السر' : 'Create QR & Pass')),
                style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveToFirebase() async {
    if (_formKey.currentState!.validate()) {
      setState(() => isSaving = true);
      try {
        final newPassword = _generateRandomPassword();
        final querySnapshot = await FirebaseFirestore.instance.collection('pets').orderBy(FieldPath.documentId).get();

        int nextId = 1;
        if (querySnapshot.docs.isNotEmpty) {
          List<int> existingIds = querySnapshot.docs.map((doc) => int.tryParse(doc.id) ?? 0).toList();
          existingIds.sort();
          nextId = existingIds.last + 1;
        }

        final customId = nextId.toString();

        await FirebaseFirestore.instance.collection('pets').doc(customId).set({
          'animalName': _animalNameController.text.trim(),
          'animalType': '',
          'gender': '',
          'sterilizationStatus': '',
          'ownerName': '',
          'ownerPhone': '',
          'editPassword': newPassword,
          'timestamp': FieldValue.serverTimestamp(),
          'petIndex': nextId,
          'vaccinations_list': [],
          'surgeries_list': [],
          'medications_list': [],
          'allergies_list': [],
          'chronic_diseases_list': [],
        });

        final url = 'https://mohamedyasser37.github.io/qpet1/#/pet/$customId';
        
        setState(() {
          currentPetId = customId;
          generatedUrl = url;
          editPassword = newPassword;
          isSaving = false;
        });
        _showQrDialog();
      } catch (e) {
        setState(() => isSaving = false);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _showQrDialog() {
    bool isAr = MyApp.of(context).locale.languageCode == 'ar';
    Color primaryColor = Theme.of(context).primaryColor;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
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
                      Text('ID: $currentPetId', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: primaryColor)),
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
          TextButton.icon(onPressed: _shareQrCode, icon: Icon(Icons.share, color: primaryColor), label: Text(isAr ? 'مشاركة' : 'Share')),
          TextButton(onPressed: () { Navigator.pop(context); Navigator.pop(context); }, child: Text(isAr ? 'إغلاق' : 'Close')),
        ],
      ),
    );
  }
}
