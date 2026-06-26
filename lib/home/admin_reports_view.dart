import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vet/home/edit_pet_view.dart';
import 'package:vet/main.dart';

class AdminReportsView extends StatefulWidget {
  const AdminReportsView({super.key});

  @override
  State<AdminReportsView> createState() => _AdminReportsViewState();
}

class _AdminReportsViewState extends State<AdminReportsView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _qrKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  Future<void> _shareQrCode(String name, String password) async {
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
        text: 'QPet - بيانات الأليف: $name\nكلمة سر التعديل: $password',
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _showPetQr(String petId, Map<String, dynamic> pet, bool isAr, Color primaryColor) {
    final url = 'https://mohamedyasser37.github.io/qpet1/#/pet/$petId';
    final name = pet['animalName'] ?? '';
    final password = pet['editPassword'] ?? '';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Center(child: Text(isAr ? 'رمز الأليف' : 'Pet QR Code')),
        content: Column(
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
                    SizedBox(width: 180, height: 180, child: QrImageView(data: url, version: QrVersions.auto, eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.circle, color: primaryColor))),
                    const SizedBox(height: 10),
                    Text(name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: primaryColor)),
                  ],
                ),
              ),
            ),
            const Divider(),
            Text(isAr ? 'كلمة سر التعديل:' : 'Edit Password:', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            Text(password, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryColor, letterSpacing: 2)),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (c) => EditPetView(petId: petId, initialData: pet)));
            },
            icon: const Icon(Icons.edit, color: Colors.orange),
            label: Text(isAr ? 'تعديل' : 'Edit', style: const TextStyle(color: Colors.orange)),
          ),
          TextButton.icon(
            onPressed: () => _shareQrCode(name, password),
            icon: Icon(Icons.share, color: primaryColor),
            label: Text(isAr ? 'مشاركة' : 'Share', style: TextStyle(color: primaryColor)),
          ),
          TextButton(onPressed: () => Navigator.pop(context), child: Text(isAr ? 'إغلاق' : 'Close')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isAr = MyApp.of(context).locale.languageCode == 'ar';
    Color primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: Text(isAr ? 'السجلات والنظام' : 'System Records'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(icon: const Icon(Icons.people), text: isAr ? 'المستخدمين' : 'Users'),
            Tab(icon: const Icon(Icons.pets), text: isAr ? 'الحيوانات' : 'Pets'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildUsersList(isAr, primaryColor),
          _buildPetsList(isAr, primaryColor),
        ],
      ),
    );
  }

  Widget _buildUsersList(bool isAr, Color primaryColor) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return Center(child: Text(isAr ? 'لا يوجد مستخدمين' : 'No users found'));

        final users = snapshot.data!.docs;
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: users.length,
          separatorBuilder: (c, i) => const Divider(),
          itemBuilder: (context, index) {
            final userData = users[index].data() as Map<String, dynamic>;
            final roleText = userData['role'] == 'doctor' ? (isAr ? 'طبيب' : 'Doctor') : (isAr ? 'صاحب أليف' : 'Owner');
            
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: primaryColor.withOpacity(0.1),
                child: Icon(userData['role'] == 'doctor' ? Icons.medical_services : Icons.person, color: primaryColor),
              ),
              title: Text(userData['email'] ?? '---'),
              subtitle: Text('${isAr ? 'الرتبة:' : 'Role:'} $roleText'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 14),
              onTap: () => _showUserInfo(userData['email'] ?? '', userData['role'], isAr, primaryColor),
            );
          },
        );
      },
    );
  }

  Widget _buildPetsList(bool isAr, Color primaryColor) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('pets').orderBy('timestamp', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text(isAr ? 'حدث خطأ في تحميل البيانات' : 'Error loading data'));
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return Center(child: Text(isAr ? 'لا يوجد حيوانات حالياً' : 'No pets found'));

        final pets = snapshot.data!.docs;
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: pets.length,
          itemBuilder: (context, index) {
            final doc = pets[index];
            final pet = doc.data() as Map<String, dynamic>;
            String animalName = pet['animalName'] ?? (isAr ? 'بدون اسم' : 'Unnamed');
            String animalType = pet['animalType'] ?? (isAr ? 'غير محدد' : 'Unknown');
            String ownerName = pet['ownerName'] ?? (isAr ? 'غير معروف' : 'Unknown');

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: ListTile(
                onTap: () => _showPetQr(doc.id, pet, isAr, primaryColor),
                leading: Icon(Icons.pets, color: primaryColor, size: 30),
                title: Text(animalName, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${isAr ? 'النوع:' : 'Type:'} $animalType | ${isAr ? 'المالك:' : 'Owner:'} $ownerName'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(pet['ownerPhone'] ?? '', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                      onPressed: () => _confirmDeletePet(doc.id, pet, isAr, primaryColor),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _confirmDeletePet(String petId, Map<String, dynamic> data, bool isAr, Color color) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red),
            const SizedBox(width: 10),
            Text(isAr ? 'تأكيد الحذف' : 'Confirm Delete'),
          ],
        ),
        content: Text(
          isAr 
            ? 'هل أنت متأكد من حذف سجل الأليف "${data['animalName']}" نهائياً؟' 
            : 'Are you sure you want to permanently delete the record for "${data['animalName']}"?',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c), 
            child: Text(isAr ? 'إغلاق' : 'Close', style: const TextStyle(color: Colors.grey))
          ),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('pets').doc(petId).delete();
              if (mounted) {
                Navigator.pop(c);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(isAr ? 'تم حذف السجل بنجاح' : 'Record deleted successfully'),
                    backgroundColor: Colors.red,
                  )
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: Text(isAr ? 'حذف نهائي' : 'Delete Permanently'),
          ),
        ],
      ),
    );
  }

  void _showUserInfo(String email, String role, bool isAr, Color primaryColor) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(email, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor)),
            const SizedBox(height: 20),
            Text(role == 'doctor' ? (isAr ? 'صلاحيات كاملة' : 'Admin Access') : (isAr ? 'صلاحيات مستخدم' : 'User Access')),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 50)),
              child: Text(isAr ? 'إغلاق' : 'Close'),
            )
          ],
        ),
      ),
    );
  }
}
