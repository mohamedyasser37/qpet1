import 'dart:io';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:vet/main.dart';
import 'profile_edit_view.dart';

import 'login_view.dart';

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

  Map<String, dynamic>? userData;
  String? userRole;
  String? userName;
  String? userEmail;
  String? profileImageUrl;
  bool isUploading = false;

  // إعدادات Cloudinary - يجب استبدال هذه القيم ببيانات حسابك
  final cloudinary = CloudinaryPublic('dpgb9n7y1', 'qpet-app', cache: false);

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
          userData = doc.data();
          userEmail = user.email;
          userRole = userData?['role'];
          userName = userData?['name'] ?? user.email?.split('@').first;
          profileImageUrl = userData?['profileImage'];
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
        
        // رفع الصورة على Cloudinary
        final response = await cloudinary.uploadFile(
          CloudinaryFile.fromFile(image.path, 
            resourceType: CloudinaryResourceType.Image,
            folder: 'profile_pictures'
          ),
        );

        final url = response.secureUrl;

        // تحديث الرابط في فيربيز
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'profileImage': url,
        });

        if (mounted) {
          _fetchUserData();
          setState(() {
            isUploading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تحديث الصورة الشخصية')));
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حدث خطأ أثناء الرفع: $e')));
      }
    }
  }

  Future<void> _launchSocial(String platform, String? value) async {
    if (value == null || value.isEmpty) return;
    
    Uri url;
    if (platform == 'whatsapp') {
      url = Uri.parse('https://wa.me/$value');
    } else {
      url = Uri.parse(value);
    }

    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر فتح الرابط')));
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isAr = MyApp.of(context).locale.languageCode == 'ar';
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
            _buildSectionHeader(isAr ? 'الدعم' : 'Support'),
            _buildSettingsGroup([
              _settingsItem(isAr ? 'تواصل مع العيادة' : 'Contact Clinic', null, primaryColor, () => _launchSocial('whatsapp', '+201212729878'), isWhatsApp: true),
            ]),
            const SizedBox(height: 25),
          ],

          _buildSectionHeader(isAr ? 'إعدادات التطبيق' : 'App Settings'),
          _buildSettingsGroup([
            _settingsItem(isAr ? 'اللغة' : 'Language', Icons.language, primaryColor, () => _showLanguageDialog(isAr)),
            _settingsItem(isAr ? 'المظهر (اللون)' : 'Appearance', Icons.palette_outlined, primaryColor, () => _showColorPicker(isAr)),
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
            onPressed: () async { 
              Navigator.pop(context); 
              await FirebaseAuth.instance.signOut();
              if (mounted) {
                Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginView()),
                  (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF4D6D), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: Text(isAr ? 'تأكيد' : 'Confirm'),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard(bool isAr, Color color) {
    return InkWell(
      onTap: () {
        if (userData != null) {
          Navigator.push(context, MaterialPageRoute(builder: (c) => ProfileEditView(userData: userData!))).then((updated) {
            if (updated == true) _fetchUserData();
          });
        }
      },
      borderRadius: BorderRadius.circular(30),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20)],
        ),
        child: Column(
          children: [
            Row(
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
                Icon(Icons.edit_outlined, color: Colors.grey.shade400),
              ],
            ),
            if (userData != null && (userData?['facebook'] != null || userData?['telegram'] != null || userData?['whatsapp'] != null)) ...[
              const Divider(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (userData?['facebook'] != null && userData!['facebook'].toString().isNotEmpty)
                    _socialIcon(Icons.facebook, Colors.blue, () => _launchSocial('facebook', userData!['facebook'])),
                  if (userData?['telegram'] != null && userData!['telegram'].toString().isNotEmpty)
                    _socialIcon(Icons.telegram, Colors.lightBlue, () => _launchSocial('telegram', userData!['telegram'])),
                  if (userData?['whatsapp'] != null && userData!['whatsapp'].toString().isNotEmpty)
                    _socialIcon(null, Colors.green, () => _launchSocial('whatsapp', userData!['whatsapp']), isWhatsApp: true),
                ],
              )
            ]
          ],
        ),
      ),
    );
  }

  Widget _socialIcon(IconData? icon, Color color, VoidCallback onTap, {bool isWhatsApp = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: IconButton(
        icon: isWhatsApp 
          ? SvgPicture.asset('assets/WhatsApp.svg', width: 28, height: 28)
          : Icon(icon, color: color, size: 28),
        onPressed: onTap,
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

  Widget _settingsItem(String title, IconData? icon, Color color, VoidCallback onTap, {bool isWhatsApp = false}) {
    return ListTile(
      onTap: onTap,
      leading: Icon(Icons.arrow_back_ios_new, size: 14, color: Colors.grey.shade400),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(width: 15),
          isWhatsApp 
            ? SvgPicture.asset('assets/WhatsApp.svg', width: 22, height: 22)
            : Icon(icon, color: Colors.black87, size: 22),
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

  void _showColorPicker(bool isAr) {
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
