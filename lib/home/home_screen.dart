import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:vet/home/qr_scanner_view.dart';
import 'package:vet/home/add_animal_view.dart';
import 'package:vet/home/products_view.dart';
import 'package:vet/home/add_product_view.dart';
import 'package:vet/home/orders_list_view.dart';
import 'package:vet/home/admin_reports_view.dart';
import 'package:vet/home/settings_view.dart';
import 'package:vet/main.dart';
import 'edit_pet_view.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String userRole = 'loading';
  String userName = '';
  String? userPetId;
  Map<String, dynamic>? petData;
  int userCount = 0;
  int petCount = 0;
  int notificationCount = 0;
  final GlobalKey _appQrKey = GlobalKey();
  DateTime? _lastBackPressTime;
  StreamSubscription? _notificationSubscription;

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final data = doc.data();
      final role = data?['role'] ?? 'owner';
      final name = data?['name'] ?? user.email?.split('@').first ?? '';
      final petId = data?['petId'];
      
      if (mounted) {
        setState(() {
          userRole = role;
          userName = name;
          userPetId = petId;
        });
      }

      if (petId != null) {
        final petDoc = await FirebaseFirestore.instance.collection('pets').doc(petId).get();
        if (mounted) setState(() => petData = petDoc.data());
      }
      
      _setupNotificationListener(user.uid, role);
      if (role == 'doctor') _fetchCounts();
    }
  }

  void _fetchCounts() async {
    try {
      final u = await FirebaseFirestore.instance.collection('users').get();
      final p = await FirebaseFirestore.instance.collection('pets').get();
      if (mounted) setState(() { userCount = u.docs.length; petCount = p.docs.length; });
    } catch (e) {}
  }

  void _setupNotificationListener(String userId, String role) {
    _notificationSubscription?.cancel();
    if (role == 'doctor') {
      _notificationSubscription = FirebaseFirestore.instance
          .collection('orders').where('status', isEqualTo: 'pending').snapshots().listen((snapshot) {
        if (mounted && FirebaseAuth.instance.currentUser != null) {
          setState(() => notificationCount = snapshot.docs.length);
        }
      });
    } else {
      _notificationSubscription = FirebaseFirestore.instance
          .collection('orders').where('userId', isEqualTo: userId).where('seenByOwner', isEqualTo: false).snapshots().listen((snapshot) {
        if (mounted && FirebaseAuth.instance.currentUser != null) {
          setState(() => notificationCount = snapshot.docs.length);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isAr = MyApp.of(context).locale.languageCode == 'ar';
    Color primaryColor = Theme.of(context).primaryColor;
    int selectedIndex = MyApp.of(context).selectedIndex;

    if (userRole == 'loading') return const Scaffold(body: Center(child: CircularProgressIndicator()));

    Widget mainContent;
    if (selectedIndex == 1 && userRole == 'doctor') {
      mainContent = const AdminReportsView();
    } else if (selectedIndex == 2) {
      mainContent = const SettingsView();
    } else {
      mainContent = Stack(
        children: [
          Positioned(top: -50, right: -50, child: CircleAvatar(radius: 120, backgroundColor: primaryColor.withOpacity(0.05))),
          Positioned(top: 200, left: -30, child: CircleAvatar(radius: 60, backgroundColor: primaryColor.withOpacity(0.03))),
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(16, 50, 16, 10), child: _buildHeader(isAr, primaryColor))),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _buildWelcomeSection(isAr, primaryColor),
                      const SizedBox(height: 25),
                      if (selectedIndex == 0) _buildHomeTab(isAr, primaryColor),
                      if (selectedIndex == 1 && userRole == 'owner') _buildPetTab(isAr, primaryColor),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        final now = DateTime.now();
        if (_lastBackPressTime == null || now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
          _lastBackPressTime = now;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isAr ? 'اضغط مرة أخرى للخروج' : 'Press back again to exit')));
        } else { exit(0); }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FB),
        body: Stack(children: [mainContent, _buildFloatingBottomBar(primaryColor, isAr)]),
      ),
    );
  }

  Widget _buildHomeTab(bool isAr, Color primaryColor) {
    return Column(children: [
      _buildMainActionCard(isAr ? 'ماسح الـ QR' : 'QR Scanner', isAr ? 'افحص كود أليفك الآن' : 'Scan your pet code now', Icons.qr_code_scanner_rounded, primaryColor, () => Navigator.push(context, MaterialPageRoute(builder: (c) => const QrScannerView())).then((_) => _fetchInitialData())),
      const SizedBox(height: 5),
      if (userRole == 'doctor') ...[
        _buildSectionLabel(isAr ? 'الإحصائيات السريعة' : 'Quick Stats', isAr),
        Row(children: [_buildStatBox(isAr ? 'المستخدمين' : 'Users', userCount, Icons.people_outline, Colors.blue), const SizedBox(width: 15), _buildStatBox(isAr ? 'الحيوانات' : 'Pets', petCount, Icons.pets_outlined, Colors.orange)]),
        const SizedBox(height: 10),
        GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 2, mainAxisSpacing: 15, crossAxisSpacing: 15, childAspectRatio: 1.3, children: [_buildGridCard(isAr ? 'إضافة أليف' : 'Add Pet', Icons.add_circle_outline, Colors.teal, () => Navigator.push(context, MaterialPageRoute(builder: (c) => const AddAnimalView()))), _buildGridCard(isAr ? 'إضافة منتج' : 'Add Product', Icons.add_shopping_cart_outlined, Colors.indigo, () => Navigator.push(context, MaterialPageRoute(builder: (c) => const AddProductView())))]),
      ],
      _buildSectionLabel(isAr ? 'خدمات QPet' : 'QPet Services', isAr),
      _buildListCard(isAr ? 'متجر المستلزمات' : 'Pet Shop', isAr ? 'تسوق منتجاتنا المتميزة' : 'Shop premium products', Icons.storefront_outlined, Colors.purple, () => Navigator.push(context, MaterialPageRoute(builder: (c) => const ProductsView()))),
      const SizedBox(height: 15),
      _buildListCard(isAr ? 'طلباتي' : 'My Orders', isAr ? 'تابع حالة مشترياتك' : 'Track your orders', Icons.local_shipping_outlined, const Color(0xFFFF4D6D), () => Navigator.push(context, MaterialPageRoute(builder: (c) => const OrdersListView())), badge: notificationCount),
    ]);
  }

  Widget _buildPetTab(bool isAr, Color color) {
    return Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [_buildSectionLabel(isAr ? 'بيانات أليفي' : 'My Pet Data', isAr), if (petData != null) IconButton(icon: const Icon(Icons.edit_document, color: Colors.orange, size: 24), onPressed: () => _verifyPasswordAndEdit(userPetId!, petData!, isAr))]),
      if (petData != null) Container(width: double.infinity, padding: const EdgeInsets.all(25), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)]), child: Column(children: [CircleAvatar(radius: 40, backgroundColor: color.withOpacity(0.1), child: Icon(Icons.pets_rounded, size: 40, color: color)), const SizedBox(height: 20), Text(petData!['animalName'] ?? '', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)), Text(petData!['animalType'] ?? '', style: const TextStyle(color: Colors.grey)), const Divider(height: 40), _petInfoRow(Icons.person_outline, isAr ? 'المالك:' : 'Owner:', petData!['ownerName']), _petInfoRow(Icons.phone_outlined, isAr ? 'الهاتف:' : 'Phone:', petData!['ownerPhone'])]))
      else Center(child: Column(children: [const SizedBox(height: 50), Icon(Icons.search_off_rounded, size: 60, color: Colors.grey.shade300), const SizedBox(height: 20), Text(isAr ? 'لم تقم بمسح رمز أليفك بعد' : 'No pet scanned yet', style: const TextStyle(color: Colors.grey)), TextButton(onPressed: () => MyApp.of(context).setSelectedIndex(0), child: Text(isAr ? 'اذهب للمسح الآن' : 'Scan Now'))])),
    ]);
  }

  Widget _petInfoRow(IconData icon, String label, String? value) => Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(children: [Icon(icon, size: 20, color: Colors.grey), const SizedBox(width: 10), Text(label, style: const TextStyle(color: Colors.grey)), const Spacer(), Text(value ?? '---', style: const TextStyle(fontWeight: FontWeight.bold))]));
  Widget _buildWelcomeSection(bool isAr, Color color) => Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 4), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(isAr ? 'أهلاً بك،' : 'Welcome,', style: const TextStyle(color: Colors.grey, fontSize: 16)), Text(userName, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold))]));
  Widget _buildHeader(bool isAr, Color color) => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Stack(children: [IconButton(icon: Icon(Icons.notifications_none_outlined, color: color, size: 28), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const OrdersListView()))), if (notificationCount > 0) Positioned(right: 8, top: 8, child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle), constraints: const BoxConstraints(minWidth: 16, minHeight: 16), child: Text('$notificationCount', style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold), textAlign: TextAlign.center)))]), Text('QPet', style: TextStyle(color: color, fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: 1.5)), IconButton(icon: const Icon(Icons.share_outlined, size: 24, color: Colors.grey), onPressed: _showDownloadQr)]);
  Widget _buildSectionLabel(String text, bool isAr) => Align(alignment: isAr ? Alignment.centerRight : Alignment.centerLeft, child: Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87))));
  Widget _buildMainActionCard(String title, String sub, IconData icon, Color color, VoidCallback onTap) => GestureDetector(onTap: onTap, child: Container(width: double.infinity, padding: const EdgeInsets.all(25), decoration: BoxDecoration(gradient: LinearGradient(colors: [color, color.withOpacity(0.8)]), borderRadius: BorderRadius.circular(30), boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))]), child: Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)), const SizedBox(height: 5), Text(sub, style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13))])), Icon(icon, color: Colors.white, size: 35)])));
  Widget _buildStatBox(String label, int count, IconData icon, Color color) => Expanded(child: Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 10)]), child: Column(children: [Icon(icon, color: color, size: 24), const SizedBox(height: 8), Text('$count', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey))])));
  Widget _buildGridCard(String title, IconData icon, Color color, VoidCallback onTap, {int badge = 0}) => GestureDetector(onTap: onTap, child: Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)]), child: Stack(children: [Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 24)), const SizedBox(height: 10), Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))])), if (badge > 0) Positioned(top: 15, right: 15, child: CircleAvatar(radius: 10, backgroundColor: const Color(0xFFFF4D6D), child: Text('$badge', style: const TextStyle(color: Colors.white, fontSize: 10))))])));
  Widget _buildListCard(String title, String sub, IconData icon, Color color, VoidCallback onTap, {int badge = 0}) => GestureDetector(onTap: onTap, child: Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)]), child: Row(children: [Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(15)), child: Icon(icon, color: color)), const SizedBox(width: 15), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), Text(sub, style: const TextStyle(color: Colors.grey, fontSize: 12))])), if (badge > 0) CircleAvatar(radius: 10, backgroundColor: const Color(0xFFFF4D6D), child: Text('$badge', style: const TextStyle(color: Colors.white, fontSize: 10))), const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey)])));

  Widget _buildFloatingBottomBar(Color color, bool isAr) {
    return Positioned(bottom: 20, left: 15, right: 15, child: Container(height: 75, decoration: BoxDecoration(color: const Color(0xFF2D3142), borderRadius: BorderRadius.circular(25), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))]), child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
      _navItem(Icons.home_filled, isAr ? 'الرئيسية' : 'Home', 0, color, isAr),
      _navItem(Icons.pets_outlined, userRole == 'doctor' ? (isAr ? 'السجلات' : 'Records') : (isAr ? 'أليفي' : 'My Pet'), 1, color, isAr),
      _navItem(Icons.settings_outlined, isAr ? 'الإعدادات' : 'Settings', 2, color, isAr),
    ])));
  }

  Widget _navItem(IconData icon, String label, int index, Color activeColor, bool isAr) {
    bool isSelected = MyApp.of(context).selectedIndex == index;
    return Expanded(child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => MyApp.of(context).setSelectedIndex(index), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, color: isSelected ? activeColor : const Color(0xFF9EA5B1), size: 24), const SizedBox(height: 4), Text(label, style: TextStyle(color: isSelected ? activeColor : const Color(0xFF9EA5B1), fontSize: 10, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal))])));
  }

  void _verifyPasswordAndEdit(String petId, Map<String, dynamic> data, bool isAr) {
    final passController = TextEditingController();
    showDialog(context: context, builder: (c) => AlertDialog(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), title: Text(isAr ? 'أدخل كلمة سر التعديل' : 'Enter Edit Password'), content: TextField(controller: passController, decoration: InputDecoration(hintText: isAr ? 'كلمة السر' : 'Password', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))), autofocus: true), actions: [TextButton(onPressed: () => Navigator.pop(c), child: Text(isAr ? 'إلغاء' : 'Cancel')), ElevatedButton(onPressed: () { if (passController.text == data['editPassword']) { Navigator.pop(c); Navigator.push(context, MaterialPageRoute(builder: (context) => EditPetView(petId: petId, initialData: data))).then((value) { if (value == true) _fetchInitialData(); }); } else { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isAr ? 'كلمة السر خاطئة!' : 'Wrong Password!'), backgroundColor: Colors.red)); } }, child: Text(isAr ? 'تأكيد' : 'Confirm'))]));
  }

  void _showDownloadQr() {
    const downloadUrl = 'https://drive.google.com/file/d/1D1zcqoLgvFiJjJ54vQrYEKWtFQWFlGav/view?usp=sharing';
    showDialog(context: context, builder: (context) => AlertDialog(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)), title: const Center(child: Text('QPet App')), content: SizedBox(width: double.maxFinite, child: Column(mainAxisSize: MainAxisSize.min, children: [RepaintBoundary(key: _appQrKey, child: Container(color: Colors.white, padding: const EdgeInsets.all(10), child: QrImageView(data: downloadUrl, size: 200, eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.circle, color: Colors.teal)))), const SizedBox(height: 20), ElevatedButton.icon(onPressed: _shareAppQr, icon: const Icon(Icons.share), label: const Text('مشاركة الرابط'), style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))]))));
  }

  Future<void> _shareAppQr() async {
    try {
      RenderRepaintBoundary boundary = _appQrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final directory = await getTemporaryDirectory();
      final imagePath = await File('${directory.path}/app_qr.png').create();
      await imagePath.writeAsBytes(byteData!.buffer.asUint8List());
      await Share.shareXFiles([XFile(imagePath.path)], text: 'حمل تطبيق QPet من هنا');
    } catch (e) {}
  }
}
