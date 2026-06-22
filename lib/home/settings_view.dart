import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase/supabase.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vet/main.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  final List<Color> themeColors = [
    Colors.teal,
    Colors.blue,
    Colors.purple,
    Colors.deepOrange,
    Colors.indigo,
    Colors.brown,
  ];

  String? userRole;
  String? userName;
  String? userEmail;
  String? profileImageUrl;
  bool isUploading = false;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (mounted) {
        setState(() {
          userEmail = user.email;
          userRole = doc.data()?['role'];
          userName = doc.data()?['name'] ?? user.email?.split('@').first;
          profileImageUrl = doc.data()?['profileImage'];
        });
      }
    }
  }

  Future<void> _pickProfileImage() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
      
      if (image != null) {
        setState(() => isUploading = true);
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) return;
        
        final fileName = 'profile_${user.uid}.jpg';
        final file = File(image.path);

        // استخدام المتغير العالمي من main.dart
        await supabase.storage.from('images').upload(
          fileName, 
          file,
          fileOptions: const FileOptions(upsert: true),
        );

        final url = "${supabase.storage.from('images').getPublicUrl(fileName)}?v=${DateTime.now().millisecondsSinceEpoch}";

        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'profileImage': url,
        });

        if (mounted) {
          setState(() {
            profileImageUrl = url;
            isUploading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تحديث الصورة الشخصية')));
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حدث خطأ: $e')));
      }
    }
  }

  Future<void> _launchWhatsApp() async {
    const phoneNumber = '+201212729878'; 
    final url = Uri.parse('https://wa.me/$phoneNumber');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر فتح واتساب')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = MyApp.of(context);
    bool isAr = appState.locale.languageCode == 'ar';
    Color primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: Text(isAr ? 'الإعدادات' : 'Settings'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildProfileCard(isAr, primaryColor),
          const SizedBox(height: 30),

          if (userRole == 'owner') ...[
            _buildSectionHeader(isAr ? 'الحساب' : 'Account'),
            _buildSettingsGroup([
              _settingsItem(isAr ? 'تواصل معنا' : 'Contact Us', Icons.chat_outlined, primaryColor, _launchWhatsApp),
            ]),
            const SizedBox(height: 25),
          ],

          _buildSectionHeader(isAr ? 'إعدادات التطبيق' : 'App Settings'),
          _buildSettingsGroup([
            _settingsItem(isAr ? 'اللغة' : 'Language', Icons.language, primaryColor, () => _showLanguageDialog(isAr)),
            _settingsItem(isAr ? 'المظهر (اللون)' : 'Appearance', Icons.palette_outlined, primaryColor, () => _showColorPicker(isAr, appState)),
          ]),

          const SizedBox(height: 30),
          _buildSectionHeader(isAr ? 'الحساب' : 'Account'),
          _buildSettingsGroup([
            ListTile(
              onTap: () => _showLogoutDialog(isAr),
              leading: const Icon(Icons.logout, color: Color(0xFFFF4D6D)),
              title: Text(
                isAr ? 'تسجيل الخروج' : 'Logout',
                style: const TextStyle(color: Color(0xFFFF4D6D), fontWeight: FontWeight.bold),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  void _showLogoutDialog(bool isAr) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        title: Text(isAr ? 'تسجيل الخروج' : 'Logout'),
        content: Text(isAr ? 'هل أنت متأكد من رغبتك في تسجيل الخروج؟' : 'Are you sure you want to logout?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(isAr ? 'إلغاء' : 'Cancel')),
          ElevatedButton(
            onPressed: () { 
              Navigator.pop(context); 
              FirebaseAuth.instance.signOut();
              MyApp.of(context).setSelectedIndex(0); 
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF4D6D), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: Text(isAr ? 'تأكيد' : 'Confirm'),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard(bool isAr, Color color) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20)],
      ),
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: color.withOpacity(0.1),
                backgroundImage: (profileImageUrl != null && profileImageUrl!.isNotEmpty) ? NetworkImage(profileImageUrl!) : null,
                child: (profileImageUrl == null || profileImageUrl!.isEmpty) ? Icon(Icons.person, size: 40, color: color) : null,
              ),
              if (isUploading)
                const Positioned.fill(child: CircularProgressIndicator()),
              Positioned(
                bottom: 0,
                right: 0,
                child: InkWell(
                  onTap: _pickProfileImage,
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: color,
                    child: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(userName ?? '---', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text(userEmail ?? '---', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: Text(
                    userRole == 'doctor' ? (isAr ? 'طبيب' : 'Doctor') : (isAr ? 'صاحب أليف' : 'Owner'),
                    style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 12, right: 8),
      child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
    );
  }

  Widget _buildSettingsGroup(List<Widget> items) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)]),
      child: Column(children: items),
    );
  }

  Widget _settingsItem(String title, IconData icon, Color color, VoidCallback onTap) {
    return ListTile(
      onTap: onTap,
      leading: Icon(Icons.arrow_back_ios_new, size: 14, color: Colors.grey.shade400),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(width: 15),
          Icon(icon, color: Colors.black87, size: 22),
        ],
      ),
    );
  }

  void _showLanguageDialog(bool isAr) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (c) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: const Text('العربية', textAlign: TextAlign.center), onTap: () { _updateLanguage('ar'); Navigator.pop(c); }),
            const Divider(),
            ListTile(title: const Text('English', textAlign: TextAlign.center), onTap: () { _updateLanguage('en'); Navigator.pop(c); }),
          ],
        ),
      ),
    );
  }

  void _showColorPicker(bool isAr, dynamic appState) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (c) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(isAr ? 'اختر لون التطبيق' : 'Choose App Color', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Wrap(
              spacing: 15,
              children: themeColors.map((color) => GestureDetector(
                onTap: () { _updateThemeColor(color); Navigator.pop(c); },
                child: CircleAvatar(backgroundColor: color, radius: 25),
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateLanguage(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', code);
    if (mounted) {
      MyApp.of(context).setLocale(Locale(code));
      setState(() {}); 
    }
  }

  Future<void> _updateThemeColor(Color color) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('themeColor', color.value);
    if (mounted) {
      MyApp.of(context).setThemeColor(color);
      setState(() {});
    }
  }
}
