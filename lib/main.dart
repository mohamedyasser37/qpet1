import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase/supabase.dart';
import 'package:vet/home/home_screen.dart';
import 'package:vet/home/login_view.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

late SupabaseClient supabase;

void main() async {
  // 1. ضمان تشغيل واجهة فلاتر
  WidgetsFlutterBinding.ensureInitialized();
  
  // 2. محاولة تهيئة الخدمات مع تسجيل الأخطاء
  try {
    await Firebase.initializeApp();
    print("✅ Firebase initialized");
  } catch (e) {
    print("❌ Firebase error: $e");
  }

  try {
    supabase = SupabaseClient(
      'https://uwhkufxuixhdusjojhfw.supabase.co',
      'sb_publishable_EDi7VysIXSiZhnpjJjYOGQ_Vgop7WUd',
    );
    print("✅ Supabase initialized");
  } catch (e) {
    print("❌ Supabase error: $e");
  }
  
  // 3. تحميل الإعدادات
  String language = 'ar';
  int colorValue = Colors.teal.value;
  try {
    final prefs = await SharedPreferences.getInstance();
    language = prefs.getString('language') ?? 'ar';
    colorValue = prefs.getInt('themeColor') ?? Colors.teal.value;
  } catch (e) {
    print("❌ SharedPreferences error: $e");
  }

  // 4. فحص الرابط (للويب)
  String? initialPetId;
  if (kIsWeb) {
    final uri = Uri.base;
    if (uri.fragment.contains('/pet/')) {
      initialPetId = uri.fragment.split('/pet/').last;
    }
  }

  // 5. تشغيل التطبيق النهائي
  runApp(MyApp(
    initialLocale: Locale(language),
    initialColor: Color(colorValue),
    startPetId: initialPetId,
  ));
}

class MyApp extends StatefulWidget {
  final Locale initialLocale;
  final Color initialColor;
  final String? startPetId;

  const MyApp({super.key, required this.initialLocale, required this.initialColor, this.startPetId});

  @override
  State<MyApp> createState() => _MyAppState();

  static _MyAppState of(BuildContext context) =>
      context.findAncestorStateOfType<_MyAppState>()!;
}

class _MyAppState extends State<MyApp> {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  late Locale locale;
  late Color themeColor;
  int selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    locale = widget.initialLocale;
    themeColor = widget.initialColor;
    
    if (widget.startPetId != null) {
      Future.delayed(Duration.zero, () => _showPetDataDialog(widget.startPetId!));
    }
  }

  void setLocale(Locale newLocale) => setState(() => locale = newLocale);
  void setThemeColor(Color color) => setState(() => themeColor = color);
  void setSelectedIndex(int index) => setState(() => selectedIndex = index);

  Future<void> _showPetDataDialog(String petId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('pets').doc(petId).get();
      if (doc.exists && navigatorKey.currentContext != null) {
        showModalBottomSheet(
          context: navigatorKey.currentContext!,
          isScrollControlled: true,
          isDismissible: false,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
          builder: (context) => PublicPetDetailWidget(data: doc.data()!),
        );
      }
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'QPet',
      locale: locale,
      theme: ThemeData(
        primaryColor: themeColor,
        colorScheme: ColorScheme.fromSeed(seedColor: themeColor, primary: themeColor),
        useMaterial3: true,
      ),
      // تم تعديل الـ builder لضمان عدم ظهور شاشة بيضاء
      builder: (context, child) {
        return Directionality(
          textDirection: locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr,
          child: child ?? const Scaffold(body: Center(child: CircularProgressIndicator())),
        );
      },
      home: StreamBuilder<fb_auth.User?>(
        stream: fb_auth.FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (snapshot.hasData) {
            return const HomeScreen();
          }
          return const LoginView();
        },
      ),
    );
  }
}

class PublicPetDetailWidget extends StatelessWidget {
  final Map<String, dynamic> data;
  const PublicPetDetailWidget({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    bool isAr = MyApp.of(context).locale.languageCode == 'ar';
    Color primaryColor = Theme.of(context).primaryColor;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Icon(Icons.pets, color: Colors.orange, size: 60),
          const SizedBox(height: 20),
          Text(isAr ? 'تم العثور على أليف!' : 'Pet Found!', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const Divider(height: 30),
          _buildRow(isAr ? 'الاسم:' : 'Name:', data['animalName']),
          _buildRow(isAr ? 'النوع:' : 'Type:', data['animalType']),
          const SizedBox(height: 20),
          Text(isAr ? 'تواصل مع صاحب الأليف:' : 'Contact Owner:', style: const TextStyle(color: Colors.grey)),
          Text(data['ownerPhone'] ?? '', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: primaryColor)),
          const Spacer(),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: primaryColor, foregroundColor: Colors.white),
            child: Text(isAr ? 'إغلاق' : 'Close'),
          )
        ],
      ),
    );
  }

  Widget _buildRow(String l, String? v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l), Text(v ?? '?', style: const TextStyle(fontWeight: FontWeight.bold))]),
  );
}
