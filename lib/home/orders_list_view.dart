import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:vet/main.dart';

class OrdersListView extends StatefulWidget {
  const OrdersListView({super.key});

  @override
  State<OrdersListView> createState() => _OrdersListViewState();
}

class _OrdersListViewState extends State<OrdersListView> {
  String? userRole;
  final currentUser = FirebaseAuth.instance.currentUser;
  bool _isMarkingSeen = false;

  @override
  void initState() {
    super.initState();
    _fetchRole();
  }

  Future<void> _fetchRole() async {
    if (currentUser != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).get();
      if (mounted) {
        setState(() => userRole = doc.data()?['role'] ?? 'owner');
      }
    }
  }

  void _markAsSeen() async {
    if (userRole != 'owner' || currentUser == null) return;

    // جلب المعرفات التي تحتاج تحديث فقط لتجنب الحلقات اللانهائية
    final snapshot = await FirebaseFirestore.instance
        .collection('orders')
        .where('userId', isEqualTo: currentUser!.uid)
        .where('seenByOwner', isEqualTo: false)
        .get();

    if (snapshot.docs.isNotEmpty) {
      final batch = FirebaseFirestore.instance.batch();
      for (var doc in snapshot.docs) {
        batch.update(doc.reference, {'seenByOwner': true});
      }
      // تنفيذ التحديث في الخلفية دون انتظار لكي لا تتعطل الواجهة
      batch.commit().catchError((e) => debugPrint('Error marking as seen: $e'));
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isAr = MyApp.of(context).locale.languageCode == 'ar';
    Color primaryColor = Theme.of(context).primaryColor;

    if (userRole == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    // استعلام مستقر
    Query query = FirebaseFirestore.instance.collection('orders');
    if (userRole == 'owner') {
      query = query.where('userId', isEqualTo: currentUser!.uid);
    }
    // ملاحظة: الترتيب يتم برمجياً هنا لتجنب الحاجة لعمل Index يدوي في فايربيز
    
    return Scaffold(
      appBar: AppBar(
        title: Text(userRole == 'doctor' ? (isAr ? 'إدارة الطلبات' : 'Order Management') : (isAr ? 'طلباتي' : 'My Orders')),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: query.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            debugPrint('Firestore Error: ${snapshot.error}');
            return Center(child: Text(isAr ? 'حدث خطأ في جلب البيانات' : 'Error fetching data'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          
          var docs = snapshot.data!.docs;
          if (docs.isEmpty) return Center(child: Text(isAr ? 'لا توجد طلبات' : 'No orders'));

          // ترتيب البيانات برمجياً (الأحدث أولاً)
          final sortedOrders = docs.toList()
            ..sort((a, b) {
              final aTime = (a.data() as Map)['createdAt'] as Timestamp?;
              final bTime = (b.data() as Map)['createdAt'] as Timestamp?;
              if (aTime == null) return 1;
              if (bTime == null) return -1;
              return bTime.compareTo(aTime);
            });

          // تصفير الإشعارات عند ظهور البيانات
          if (userRole == 'owner') {
            _markAsSeen();
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sortedOrders.length,
            itemBuilder: (context, index) {
              final order = sortedOrders[index].data() as Map<String, dynamic>;
              return _buildOrderCard(context, sortedOrders[index].id, order, isAr, primaryColor);
            },
          );
        },
      ),
    );
  }

  Widget _buildOrderCard(BuildContext context, String orderId, Map<String, dynamic> order, bool isAr, Color primaryColor) {
    Color statusColor = Colors.orange;
    String statusText = isAr ? 'قيد الانتظار' : 'Pending';
    if (order['status'] == 'accepted') { statusColor = Colors.green; statusText = isAr ? 'مقبول' : 'Accepted'; }
    else if (order['status'] == 'rejected') { statusColor = Colors.red; statusText = isAr ? 'مرفوض' : 'Rejected'; }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(order['productName'] ?? '---', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: Text(statusText, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
            const Divider(height: 24),
            _infoRow(Icons.person, '${isAr ? 'العميل:' : 'Client:'} ${order['userName']}'),
            _infoRow(Icons.phone, '${isAr ? 'الهاتف:' : 'Phone:'} ${order['userPhone']}'),
            _infoRow(Icons.attach_money, '${isAr ? 'السعر:' : 'Price:'} ${order['productPrice']} ${isAr ? 'ج.م' : 'EGP'}'),
            
            if (userRole == 'doctor' && order['status'] == 'pending') ...[
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: ElevatedButton(onPressed: () => _updateStatus(orderId, 'accepted'), style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white), child: Text(isAr ? 'قبول' : 'Accept'))),
                  const SizedBox(width: 12),
                  Expanded(child: OutlinedButton(onPressed: () => _updateStatus(orderId, 'rejected'), style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)), child: Text(isAr ? 'رفض' : 'Reject'))),
                ],
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [Icon(icon, size: 16, color: Colors.grey), const SizedBox(width: 8), Text(text)]));

  void _updateStatus(String id, String status) {
    FirebaseFirestore.instance.collection('orders').doc(id).update({'status': status, 'seenByOwner': false});
  }
}
