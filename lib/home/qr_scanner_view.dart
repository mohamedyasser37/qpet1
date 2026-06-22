import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:vet/home/edit_pet_view.dart';
import 'package:vet/main.dart';
import 'package:image_picker/image_picker.dart';

class QrScannerView extends StatefulWidget {
  const QrScannerView({super.key});

  @override
  State<QrScannerView> createState() => _QrScannerViewState();
}

class _QrScannerViewState extends State<QrScannerView> with WidgetsBindingObserver {
  MobileScannerController controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal, 
    autoStart: false,
    formats: [BarcodeFormat.qrCode],
  );
  bool isPermissionGranted = false;
  bool isProcessing = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _requestPermission();
  }

  Future<void> _requestPermission() async {
    final status = await Permission.camera.request();
    setState(() => isPermissionGranted = status.isGranted);
    if (isPermissionGranted) {
      Future.delayed(const Duration(milliseconds: 500), () { if (mounted) controller.start(); });
    }
  }

  Future<void> _pickAndScanImage() async {
    if (isProcessing) return;
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    setState(() => isProcessing = true);
    controller.stop();
    
    try {
      final BarcodeCapture? result = await controller.analyzeImage(image.path);
      if (result != null && result.barcodes.isNotEmpty) {
        final code = result.barcodes.first.rawValue;
        if (code != null) await _processResult(code);
      } else {
        setState(() => isProcessing = false);
        bool isAr = MyApp.of(context).locale.languageCode == 'ar';
        _showErrorDialog(isAr ? 'لم يتم العثور على رمز QR في هذه الصورة.' : 'No QR code found in this image.');
        controller.start();
      }
    } catch (e) {
      setState(() => isProcessing = false);
      _showErrorDialog('Error: $e');
      controller.start();
    }
  }

  String _extractIdFromUrl(String data) {
    // استخراج المعرف من الرابط (يأخذ الجزء الأخير بعد /)
    if (data.contains('/')) {
      return data.split('/').last.trim();
    }
    return data.trim();
  }

  Future<void> _processResult(String code) async {
    final petId = _extractIdFromUrl(code);
    try {
      final doc = await FirebaseFirestore.instance.collection('pets').doc(petId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        if (mounted) {
          setState(() => isProcessing = false);
          _showResultSheet(petId, data);
        }
      } else {
        setState(() => isProcessing = false);
        bool isAr = MyApp.of(context).locale.languageCode == 'ar';
        _showErrorDialog(isAr ? 'عذراً، هذا الرمز غير مسجل لدينا.' : 'Sorry, this code is not registered.');
        controller.start();
      }
    } catch (e) {
      setState(() => isProcessing = false);
      _showErrorDialog('Error: $e');
      controller.start();
    }
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (isProcessing || capture.barcodes.isEmpty) return;
    final code = capture.barcodes.first.rawValue;
    if (code == null) return;
    setState(() => isProcessing = true);
    controller.stop();
    await _processResult(code);
  }

  void _showResultSheet(String petId, Map<String, dynamic> data) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    bool isAr = MyApp.of(context).locale.languageCode == 'ar';
    Color primaryColor = Theme.of(context).primaryColor;

    // فحص إذا كان هذا الحيوان مضاف بالفعل لهذا المستخدم، ومعرفة نوع الحساب
    bool alreadyLinked = false;
    String? role;
    if (currentUser != null) {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
      alreadyLinked = userDoc.data()?['petId'] == petId;
      role = userDoc.data()?['role'];
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(Icons.pets, color: primaryColor, size: 40),
                if (currentUser != null)
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.orange),
                    onPressed: () => _verifyPassword(petId, data, true), // true يعني تعديل
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(isAr ? 'بيانات الأليف' : 'Pet Details', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            _buildDataRow(isAr ? 'الاسم:' : 'Name:', data['animalName']),
            _buildDataRow(isAr ? 'النوع:' : 'Type:', data['animalType']),
            _buildDataRow(isAr ? 'الصاحب:' : 'Owner:', data['ownerName']),
            _buildDataRow(isAr ? 'الهاتف:' : 'Phone:', data['ownerPhone']),
            const SizedBox(height: 30),
            
            // زر الإضافة لـ "أليفي" يظهر فقط للمستخدم العادي ولم يقم بالإضافة بعد
            if (currentUser != null && role == 'owner' && !alreadyLinked)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _verifyPassword(petId, data, false), // false يعني إضافة للقائمة
                    icon: const Icon(Icons.add_task),
                    label: Text(isAr ? 'إضافة إلى أليفي' : 'Add to My Pet'),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), side: BorderSide(color: primaryColor), foregroundColor: primaryColor),
                  ),
                ),
              ),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(backgroundColor: primaryColor, padding: const EdgeInsets.symmetric(vertical: 16)),
                child: Text(isAr ? 'إغلاق' : 'Close', style: const TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    ).then((_) { if (isPermissionGranted && !isProcessing) controller.start(); });
  }

  void _verifyPassword(String petId, Map<String, dynamic> data, bool forEdit) {
    final passController = TextEditingController();
    bool isAr = MyApp.of(context).locale.languageCode == 'ar';
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(forEdit 
          ? (isAr ? 'كلمة سر التعديل' : 'Edit Password')
          : (isAr ? 'كلمة سر الإضافة' : 'Add Password')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(isAr ? 'أدخل كلمة السر الخاصة بهذا الأليف' : 'Enter the password for this pet', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 15),
            TextField(
              controller: passController,
              decoration: InputDecoration(hintText: isAr ? 'كلمة السر' : 'Password', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(isAr ? 'إلغاء' : 'Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (passController.text == data['editPassword']) {
                Navigator.pop(c); // غلق الديالوج
                if (forEdit) {
                  Navigator.pop(context); // غلق الشيت
                  Navigator.push(context, MaterialPageRoute(builder: (context) => EditPetView(petId: petId, initialData: data)));
                } else {
                  // عملية الإضافة لقائمة "أليفي"
                  final user = FirebaseAuth.instance.currentUser;
                  await FirebaseFirestore.instance.collection('users').doc(user!.uid).update({'petId': petId});
                  
                  if (mounted) {
                    Navigator.pop(context); // غلق الشيت (Bottom Sheet)
                    Navigator.pop(context); // الخروج من شاشة الماسح (Scanner View)
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(isAr ? 'تمت الإضافة إلى أليفي بنجاح!' : 'Added to My Pet successfully!'), 
                        backgroundColor: Colors.green
                      )
                    );
                  }
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isAr ? 'كلمة السر خاطئة!' : 'Wrong Password!'), backgroundColor: Colors.red));
              }
            },
            child: Text(isAr ? 'تأكيد' : 'Confirm'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isAr = MyApp.of(context).locale.languageCode == 'ar';
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(isAr ? 'ماسح QPet' : 'QPet Scanner'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.image),
            onPressed: _pickAndScanImage,
            tooltip: isAr ? 'مسح من المعرض' : 'Scan from Gallery',
          ),
        ],
      ),
      body: !isPermissionGranted ? Center(child: Text(isAr ? 'يرجى إعطاء إذن الكاميرا' : 'Please grant camera permission', style: const TextStyle(color: Colors.white))) :
      Stack(
        children: [
          MobileScanner(controller: controller, onDetect: _onDetect),
          Center(child: Container(width: 250, height: 250, decoration: BoxDecoration(border: Border.all(color: Theme.of(context).primaryColor, width: 4), borderRadius: BorderRadius.circular(20)))),
          if (isProcessing) Center(child: CircularProgressIndicator(color: Theme.of(context).primaryColor)),
        ],
      ),
    );
  }

  void _showErrorDialog(String msg) {
    showDialog(context: context, builder: (c) => AlertDialog(content: Text(msg), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK'))]));
  }

  Widget _buildDataRow(String l, String? v) => Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l, style: const TextStyle(color: Colors.grey)), Text(v ?? '?', style: const TextStyle(fontWeight: FontWeight.bold))]));

  @override
  void dispose() { WidgetsBinding.instance.removeObserver(this); controller.dispose(); super.dispose(); }
}
