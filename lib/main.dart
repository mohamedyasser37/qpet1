import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase/supabase.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'home/splash_screen.dart';

late SupabaseClient supabase;
SharedPreferences? _prefs;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyAqRR1J4HNTQ1oNMhpsn6y89Hi10O9P17w",
        appId: "1:786560188458:web:9004e7227233baf5a2c353",
        messagingSenderId: "786560188458",
        projectId: "vet-app-80a7a",
        storageBucket: "vet-app-80a7a.firebasestorage.app",
      ),
    );
  } else {
    await Firebase.initializeApp();
  }

  _prefs = await SharedPreferences.getInstance();

  supabase = SupabaseClient(
    'https://uwhkufxuixhdusjojhfw.supabase.co',
    'sb_publishable_EDi7VysIXSiZhnpjJjYOGQ_Vgop7WUd',
  );

  String language = _prefs?.getString('language') ?? 'ar';
  int colorValue = _prefs?.getInt('themeColor') ?? Colors.teal.value;

  String? initialPetId;
  if (kIsWeb) {
    final uri = Uri.base;
    if (uri.fragment.contains('/pet/')) {
      initialPetId = uri.fragment.split('/pet/').last;
    } else if (uri.path.contains('/pet/')) {
      initialPetId = uri.path.split('/pet/').last;
    }
    if (initialPetId != null && initialPetId!.contains('?')) {
      initialPetId = initialPetId!.split('?').first;
    }
  }

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
  late Locale locale;
  late Color themeColor;

  @override
  void initState() {
    super.initState();
    locale = widget.initialLocale;
    themeColor = widget.initialColor;
  }

  void setLocale(Locale newLocale) => setState(() => locale = newLocale);
  void setThemeColor(Color color) => setState(() => themeColor = color);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'QPet',
      locale: locale,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ar', ''), Locale('en', '')],
      theme: ThemeData(
        primaryColor: themeColor,
        colorScheme: ColorScheme.fromSeed(seedColor: themeColor, primary: themeColor),
        useMaterial3: true,
      ),
      home: kIsWeb 
          ? (widget.startPetId != null 
              ? PublicPetProfilePage(petId: widget.startPetId!) 
              : const WebForbiddenPage())
          : const SplashScreen(),
      onGenerateRoute: kIsWeb ? (settings) => MaterialPageRoute(
        builder: (_) => widget.startPetId != null 
            ? PublicPetProfilePage(petId: widget.startPetId!) 
            : const WebForbiddenPage()
      ) : null,
    );
  }
}

class WebForbiddenPage extends StatelessWidget {
  const WebForbiddenPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.qr_code_scanner, size: 80, color: Colors.grey),
            const SizedBox(height: 20),
            Text(
              "يرجى مسح رمز الـ QR الخاص بالأليف للوصول للبيانات",
              style: TextStyle(color: Colors.grey, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              "Please scan the pet's QR code to access data",
              style: TextStyle(color: Colors.grey, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class PublicPetProfilePage extends StatelessWidget {
  final String petId;
  const PublicPetProfilePage({super.key, required this.petId});

  @override
  Widget build(BuildContext context) {
    bool isAr = Localizations.localeOf(context).languageCode == 'ar';
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('pets').doc(petId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text(isAr ? 'خطأ في التحميل' : 'Error Loading'));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || !snapshot.data!.exists) return Center(child: Text(isAr ? 'الأليف غير موجود (ID: $petId)' : 'Pet Not Found (ID: $petId)'));

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final color = Theme.of(context).primaryColor;
          final String? ownerUid = data['ownerUid'];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 600),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20)]),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      width: double.infinity,
                      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: const BorderRadius.vertical(top: Radius.circular(30))),
                      child: Icon(Icons.pets, color: color, size: 100),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Text(data['animalName'] ?? '', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          _info(isAr ? 'النوع' : 'Type', data['animalType'], Icons.category, color),
                          _info(isAr ? 'الجنس' : 'Gender', data['gender'], Icons.transgender, color),
                          _info(isAr ? 'معقم / مخصي' : 'Neutered/Spayed', data['sterilizationStatus'], Icons.content_cut, color),
                          
                          const Divider(height: 40),
                          _info(isAr ? 'المالك' : 'Owner', data['ownerName'], Icons.person, color),
                          
                          // --- قسم السوشيال ميديا تحت اسم المالك مباشرة ---
                          if (ownerUid != null)
                            StreamBuilder<DocumentSnapshot>(
                              stream: FirebaseFirestore.instance.collection('users').doc(ownerUid).snapshots(),
                              builder: (context, userSnapshot) {
                                if (!userSnapshot.hasData || !userSnapshot.data!.exists) return const SizedBox.shrink();
                                final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                                
                                bool hasFacebook = userData['facebook'] != null && userData['facebook'].toString().isNotEmpty;
                                bool hasTelegram = userData['telegram'] != null && userData['telegram'].toString().isNotEmpty;
                                bool hasWhatsapp = userData['whatsapp'] != null && userData['whatsapp'].toString().isNotEmpty;

                                if (!hasFacebook && !hasTelegram && !hasWhatsapp) return const SizedBox.shrink();

                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 15),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (hasFacebook) _socialIcon('facebook', userData['facebook'], Colors.blue),
                                      if (hasFacebook && (hasTelegram || hasWhatsapp)) const SizedBox(width: 20),
                                      if (hasTelegram) _socialIcon('telegram', userData['telegram'], Colors.lightBlue),
                                      if (hasTelegram && hasWhatsapp) const SizedBox(width: 20),
                                      if (hasWhatsapp) _socialIcon('whatsapp', userData['whatsapp'], Colors.green),
                                    ],
                                  ),
                                );
                              },
                            ),

                          _info(isAr ? 'رقم التواصل' : 'Contact', data['ownerPhone'], Icons.phone, color),
                          const SizedBox(height: 15),
                          if (data['ownerPhone'] != null && data['ownerPhone'].toString().isNotEmpty) 
                            ElevatedButton.icon(
                              onPressed: () => _launchAnyUrl('tel:${data['ownerPhone']}'),
                              icon: const Icon(Icons.call),
                              label: Text(isAr ? 'اتصل بالمالك الآن' : 'Call Owner Now'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green, 
                                foregroundColor: Colors.white, 
                                minimumSize: const Size(double.infinity, 55), 
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                              ),
                            ),
                          
                          const Divider(height: 40),
                          Align(alignment: isAr ? Alignment.centerRight : Alignment.centerLeft, child: Text(isAr ? 'السجل الطبي' : 'Medical Record', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
                          const SizedBox(height: 15),
                          _medInfo(isAr ? 'الوزن' : 'Weight', '${data['weight'] ?? '--'} kg'),
                          _medInfo(isAr ? 'العمر' : 'Age', data['age']),
                          
                          if (data['deworming_list'] != null && (data['deworming_list'] as List).isNotEmpty) ...[
                            const SizedBox(height: 20),
                            Align(alignment: isAr ? Alignment.centerRight : Alignment.centerLeft, child: Text(isAr ? 'أحدث جرعات الديدان:' : 'Latest Deworming Doses:', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.brown))),
                            const SizedBox(height: 10),
                            ...(data['deworming_list'] as List).reversed.take(2).map((e) => _medInfo(e['name'] ?? '', e['date'] ?? '')),
                          ],

                          if (data['chronic_diseases_list'] != null && (data['chronic_diseases_list'] as List).isNotEmpty) ...[
                            const SizedBox(height: 20),
                            Align(alignment: isAr ? Alignment.centerRight : Alignment.centerLeft, child: Text(isAr ? 'تنبيهات صحية:' : 'Health Alerts:', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
                            const SizedBox(height: 10),
                            ...(data['chronic_diseases_list'] as List).map((e) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(children: [const Icon(Icons.warning, color: Colors.red, size: 16), const SizedBox(width: 8), Text(e.toString(), style: const TextStyle(color: Colors.red))]),
                            )),
                          ],
                          
                          const SizedBox(height: 40),
                          const Text('QPet Team - Smart ID System', style: TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _launchAnyUrl(String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Widget _info(String l, String? v, IconData i, Color c) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8), 
    child: Row(children: [Icon(i, size: 22, color: c), const SizedBox(width: 12), Text(l), const Spacer(), Text(v ?? '--', style: const TextStyle(fontWeight: FontWeight.bold))])
  );

  Widget _medInfo(String l, String? v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4), 
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l, style: const TextStyle(color: Colors.grey)), Text(v ?? '--', style: const TextStyle(fontWeight: FontWeight.bold))])
  );

  Widget _socialIcon(String platform, String value, Color color) {
    IconData? icon;
    String fullUrl;
    String val = value.trim();
    Color iconColor = color;
    bool isWhatsApp = platform == 'whatsapp';

    if (platform == 'facebook') {
      icon = Icons.facebook;
      fullUrl = val.startsWith('http') ? val : 'https://www.facebook.com/$val';
    } else if (platform == 'telegram') {
      icon = Icons.telegram;
      if (val.startsWith('@')) val = val.substring(1);
      fullUrl = val.startsWith('http') ? val : 'https://t.me/$val';
    } else {
      iconColor = Colors.green; // لون واتساب الأخضر
      String phone = val.replaceAll(RegExp(r'[^0-9]'), '');
      fullUrl = 'https://wa.me/$phone';
    }

    return Material(
      color: Colors.transparent,
      child: IconButton(
        onPressed: () => _launchAnyUrl(fullUrl),
        icon: CircleAvatar(
          radius: 22, 
          backgroundColor: iconColor.withOpacity(0.1), 
          child: isWhatsApp 
            ? SvgPicture.asset('assets/WhatsApp.svg', width: 26, height: 26)
            : Icon(icon, color: iconColor, size: 26)
        ),
      ),
    );
  }
}
