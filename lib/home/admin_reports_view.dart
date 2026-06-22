import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vet/main.dart';

class AdminReportsView extends StatefulWidget {
  const AdminReportsView({super.key});

  @override
  State<AdminReportsView> createState() => _AdminReportsViewState();
}

class _AdminReportsViewState extends State<AdminReportsView> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return Center(child: Text(isAr ? 'لا يوجد حيوانات' : 'No pets found'));

        final pets = snapshot.data!.docs;
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: pets.length,
          itemBuilder: (context, index) {
            final doc = pets[index];
            final pet = doc.data() as Map<String, dynamic>;
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: ListTile(
                leading: Icon(Icons.pets, color: primaryColor, size: 30),
                title: Text(pet['animalName'] ?? '---', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${isAr ? 'النوع:' : 'Type:'} ${pet['animalType']} | ${isAr ? 'المالك:' : 'Owner:'} ${pet['ownerName']}'),
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
    final passController = TextEditingController();
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(isAr ? 'حذف السجل' : 'Delete Record'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(isAr 
              ? 'هل أنت متأكد من حذف بيانات ${data['animalName']}؟ لا يمكن التراجع عن هذا الإجراء.' 
              : 'Are you sure you want to delete ${data['animalName']}? This cannot be undone.',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: passController,
              decoration: InputDecoration(
                hintText: isAr ? 'أدخل كلمة سر التعديل للتأكيد' : 'Enter edit password to confirm',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(isAr ? 'إلغاء' : 'Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (passController.text == data['editPassword']) {
                await FirebaseFirestore.instance.collection('pets').doc(petId).delete();
                Navigator.pop(c);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(isAr ? 'تم حذف السجل بنجاح' : 'Record deleted successfully'),
                    backgroundColor: Colors.red,
                  )
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(isAr ? 'كلمة السر خاطئة!' : 'Wrong password!'), backgroundColor: Colors.red),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(isAr ? 'حذف نهائي' : 'Delete permanently'),
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
