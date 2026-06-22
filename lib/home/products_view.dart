import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:vet/home/add_product_view.dart';
import 'package:vet/main.dart';

class Product {
  final String id;
  final String name;
  final String description;
  final double price;
  final String imageUrl;
  final String category;

  Product({required this.id, required this.name, required this.description, required this.price, required this.imageUrl, required this.category});

  factory Product.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map;
    return Product(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      price: (data['price'] ?? 0).toDouble(),
      imageUrl: data['imageUrl'] ?? 'https://images.unsplash.com/photo-1514888286974-6c03e2ca1dba?q=80&w=1000',
      category: data['category'] ?? 'عام',
    );
  }
}

class ProductsView extends StatefulWidget {
  const ProductsView({super.key});

  @override
  State<ProductsView> createState() => _ProductsViewState();
}

class _ProductsViewState extends State<ProductsView> {
  String? userRole;

  @override
  void initState() {
    super.initState();
    _checkRole();
  }

  Future<void> _checkRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      setState(() => userRole = doc.data()?['role']);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isAr = MyApp.of(context).locale.languageCode == 'ar';
    Color primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: Text(isAr ? 'متجر المستلزمات' : 'Pet Shop'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('products').orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return Center(child: Text(isAr ? 'لا توجد منتجات حالياً' : 'No products found'));

          final products = snapshot.data!.docs.map((doc) => Product.fromFirestore(doc)).toList();

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.65,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: products.length,
            itemBuilder: (context, index) => _buildProductCard(context, products[index], isAr, primaryColor),
          );
        },
      ),
    );
  }

  String _translateCat(String category, bool isAr) {
    Map<String, String> m = {
      'طعام': 'Food',
      'إكسسوارات': 'Accessories',
      'أسرة': 'Beds',
      'ألعاب': 'Toys',
      'أدوية': 'Medicine'
    };
    if (isAr) return category;
    return m[category] ?? category;
  }

  Widget _buildProductCard(BuildContext context, Product product, bool isAr, Color primaryColor) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [BoxShadow(color: primaryColor.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 8))],
        border: Border.all(color: primaryColor.withOpacity(0.05)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Image.network(
                      product.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) => Center(child: Icon(Icons.broken_image, color: primaryColor)),
                    ),
                  ),
                  Positioned(
                    top: 10, left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: primaryColor, borderRadius: BorderRadius.circular(10)),
                      child: Text(_translateCat(product.category, isAr), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  if (userRole == 'doctor')
                    Positioned(
                      top: 5, right: 5,
                      child: PopupMenuButton<String>(
                        icon: const CircleAvatar(backgroundColor: Colors.white, radius: 15, child: Icon(Icons.more_vert, color: Colors.black, size: 18)),
                        onSelected: (val) {
                          if (val == 'edit') Navigator.push(context, MaterialPageRoute(builder: (c) => AddProductView(product: product)));
                          else if (val == 'delete') _confirmDelete(product.id, isAr);
                        },
                        itemBuilder: (c) => [
                          PopupMenuItem(value: 'edit', child: Text(isAr ? 'تعديل' : 'Edit')),
                          PopupMenuItem(value: 'delete', child: Text(isAr ? 'حذف' : 'Delete', style: const TextStyle(color: Colors.red))),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${product.price}', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 18)),
                      Text(isAr ? 'ج.م' : 'EGP', style: TextStyle(color: primaryColor, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => ProductDetailView(product: product))),
                      style: ElevatedButton.styleFrom(backgroundColor: primaryColor.withOpacity(0.1), foregroundColor: primaryColor, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: Text(isAr ? 'التفاصيل' : 'Details', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(String id, bool isAr) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(isAr ? 'حذف المنتج' : 'Delete Product'),
        content: Text(isAr ? 'هل أنت متأكد؟' : 'Are you sure?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(isAr ? 'إلغاء' : 'Cancel')),
          TextButton(onPressed: () { FirebaseFirestore.instance.collection('products').doc(id).delete(); Navigator.pop(c); }, child: Text(isAr ? 'حذف' : 'Delete', style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
  }
}

class ProductDetailView extends StatefulWidget {
  final Product product;
  const ProductDetailView({super.key, required this.product});

  @override
  State<ProductDetailView> createState() => _ProductDetailViewState();
}

class _ProductDetailViewState extends State<ProductDetailView> {
  final _phoneController = TextEditingController();
  final _nameController = TextEditingController();
  bool isOrdering = false;
  String? _userRole;

  @override
  void initState() {
    super.initState();
    _fetchUserRole();
  }

  Future<void> _fetchUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (mounted) {
        setState(() => _userRole = doc.data()?['role']);
      }
    }
  }

  Future<void> _placeOrder(bool isAr, Color primaryColor) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isAr ? 'يجب تسجيل الدخول' : 'Please login')));
      return;
    }

    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(isAr ? 'إتمام الطلب' : 'Complete Order'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _nameController, decoration: InputDecoration(labelText: isAr ? 'الاسم' : 'Name', prefixIcon: const Icon(Icons.person))),
            const SizedBox(height: 10),
            TextField(controller: _phoneController, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: isAr ? 'الهاتف' : 'Phone', prefixIcon: const Icon(Icons.phone))),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(isAr ? 'إلغاء' : 'Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (_nameController.text.isEmpty || _phoneController.text.isEmpty) return;
              Navigator.pop(c);
              setState(() => isOrdering = true);
              try {
                await FirebaseFirestore.instance.collection('orders').add({
                  'productId': widget.product.id, 'productName': widget.product.name, 'productPrice': widget.product.price,
                  'userId': user.uid, 'userName': _nameController.text, 'userPhone': _phoneController.text,
                  'status': 'pending', 'seenByOwner': true, 'createdAt': FieldValue.serverTimestamp(),
                });
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isAr ? 'تم الإرسال بنجاح' : 'Sent successfully')));
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
              } finally {
                if (mounted) setState(() => isOrdering = false);
              }
            },
            child: Text(isAr ? 'تأكيد' : 'Confirm'),
          ),
        ],
      ),
    );
  }

  String _translateCat(String category, bool isAr) {
    Map<String, String> m = {
      'طعام': 'Food',
      'إكسسوارات': 'Accessories',
      'أسرة': 'Beds',
      'ألعاب': 'Toys',
      'أدوية': 'Medicine'
    };
    if (isAr) return category;
    return m[category] ?? category;
  }

  @override
  Widget build(BuildContext context) {
    bool isAr = MyApp.of(context).locale.languageCode == 'ar';
    Color primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: Colors.white, // توحيد لون الخلفية
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 400, 
            pinned: true, 
            backgroundColor: primaryColor, 
            flexibleSpace: FlexibleSpaceBar(
              background: Image.network(widget.product.imageUrl, fit: BoxFit.cover)
            )
          ),
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(24),
              color: Colors.white, // ضمان أن لون الحاوية أبيض
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Chip(label: Text(_translateCat(widget.product.category, isAr)), backgroundColor: primaryColor.withOpacity(0.1)),
                    Text('${widget.product.price} ${isAr ? 'ج.م' : 'EGP'}', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: primaryColor)),
                  ]),
                  const SizedBox(height: 25),
                  Text(widget.product.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  Text(isAr ? 'الوصف' : 'Description', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Text(widget.product.description, style: TextStyle(fontSize: 16, color: Colors.grey.shade700, height: 1.6)),
                  // مساحة إضافية في الأسفل فقط للمستخدم العادي لكي لا يغطي الزر على النص
                  SizedBox(height: _userRole == 'owner' ? 120 : 40), 
                ],
              ),
            ),
          ),
        ],
      ),
      // لا نعرض الـ bottomSheet (الذي قد يترك مساحة لونية) إلا للمستخدم العادي
      bottomSheet: _userRole == 'owner' 
        ? Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white, 
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]
            ),
            child: SizedBox(
              width: double.infinity, height: 55,
              child: ElevatedButton.icon(
                onPressed: isOrdering ? null : () => _placeOrder(isAr, primaryColor),
                icon: isOrdering ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.shopping_bag_outlined),
                label: Text(isOrdering ? (isAr ? 'جاري الطلب...' : 'Ordering...') : (isAr ? 'اطلب الآن' : 'Order Now'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
              ),
            ),
          )
        : null,
    );
  }
}
