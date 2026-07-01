import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:vet/main.dart';
import 'package:vet/home/products_view.dart';

class AddProductView extends StatefulWidget {
  final Product? product;
  const AddProductView({super.key, this.product});
  @override
  State<AddProductView> createState() => _AddProductViewState();
}

class _AddProductViewState extends State<AddProductView> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descController;
  late TextEditingController _priceController;
  late TextEditingController _shippingPriceController;
  late TextEditingController _categoryController;
  
  List<String> selectedColors = [];
  List<File> _newImages = []; // لتخزين الصور الجديدة المختارة من المعرض
  List<String> _existingUrls = []; // لتخزين روابط الصور الموجودة أصلاً (في حالة التعديل)
  bool isSaving = false;

  final Map<String, Color> colorMap = {
    'أسود': Colors.black, 'Black': Colors.black, 'أبيض': Colors.white, 'White': Colors.white, 'أحمر': Colors.red, 'Red': Colors.red, 'أزرق': Colors.blue, 'Blue': Colors.blue, 'أخضر': Colors.green, 'Green': Colors.green, 'أصفر': Colors.yellow, 'Yellow': Colors.yellow, 'بني': Colors.brown, 'Brown': Colors.brown, 'رمادي': Colors.grey, 'Grey': Colors.grey, 'وردي': Colors.pink, 'Pink': Colors.pink, 'بنفسجي': Colors.purple, 'Purple': Colors.purple, 'برتقالي': Colors.orange, 'Orange': Colors.orange,
  };

  final cloudinary = CloudinaryPublic('dt4tjargq', 'ml_default10', cache: false);

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product?.name ?? '');
    _descController = TextEditingController(text: widget.product?.description ?? '');
    _priceController = TextEditingController(text: widget.product?.price.toString() ?? '');
    _shippingPriceController = TextEditingController(text: '0');
    _categoryController = TextEditingController(text: widget.product?.category ?? '');
    selectedColors = widget.product?.colors != null ? List<String>.from(widget.product!.colors) : [];
    _existingUrls = widget.product?.imageUrls != null ? List<String>.from(widget.product!.imageUrls) : (widget.product?.imageUrl != null ? [widget.product!.imageUrl] : []);
    
    if (widget.product == null) {
      _fetchDefaultShipping();
    } else {
      _shippingPriceController.text = widget.product!.shippingPrice.toString();
    }
  }

  Future<void> _fetchDefaultShipping() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('config').doc('contact_info').get();
      if (doc.exists && mounted) {
        setState(() {
          _shippingPriceController.text = (doc.data()?['defaultShippingPrice'] ?? 0).toString();
        });
      }
    } catch (e) {}
  }

  Future<void> _pickImages() async {
    if (_newImages.length + _existingUrls.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الحد الأقصى 3 صور فقط')));
      return;
    }
    final ImagePicker picker = ImagePicker();
    final List<XFile> images = await picker.pickMultiImage(imageQuality: 50);
    if (images.isNotEmpty) {
      setState(() {
        _newImages.addAll(images.take(3 - (_newImages.length + _existingUrls.length)).map((e) => File(e.path)));
      });
    }
  }

  Future<List<String>> _uploadAllImages() async {
    List<String> uploadedUrls = [..._existingUrls];
    for (var file in _newImages) {
      try {
        final response = await cloudinary.uploadFile(CloudinaryFile.fromFile(file.path, resourceType: CloudinaryResourceType.Image, folder: 'products'));
        uploadedUrls.add(response.secureUrl);
      } catch (e) { debugPrint("Upload Error: $e"); }
    }
    return uploadedUrls;
  }

  @override
  Widget build(BuildContext context) {
    bool isAr = MyApp.of(context).locale.languageCode == 'ar';
    Color themeBg = Theme.of(context).scaffoldBackgroundColor;
    bool isDark = themeBg.value == const Color(0xFF2D2D2D).value;
    Color primaryColor = Theme.of(context).primaryColor;
    Color gold = const Color(0xFFC5A059);
    Color textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: themeBg,
      appBar: AppBar(title: Text(widget.product == null ? (isAr ? 'إضافة منتج' : 'Add Product') : (isAr ? 'تعديل المنتج' : 'Edit Product'), style: const TextStyle(color: Colors.white)), backgroundColor: primaryColor, iconTheme: const IconThemeData(color: Colors.white)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(isAr ? 'صور المنتج (حتى 3 صور):' : 'Product Images (Max 3):', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
              const SizedBox(height: 12),
              SizedBox(
                height: 120,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    // عرض الصور الموجودة مسبقاً (في حالة التعديل)
                    ..._existingUrls.map((url) => _imagePreview(url, isRemote: true)),
                    // عرض الصور الجديدة المختارة
                    ..._newImages.map((file) => _imagePreview(file.path, isRemote: false)),
                    // زر الإضافة
                    if (_newImages.length + _existingUrls.length < 3)
                      GestureDetector(
                        onTap: _pickImages,
                        child: Container(width: 100, margin: const EdgeInsets.only(right: 10), decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.05) : primaryColor.withOpacity(0.05), borderRadius: BorderRadius.circular(15), border: Border.all(color: isDark ? gold.withOpacity(0.3) : primaryColor.withOpacity(0.3))), child: Icon(Icons.add_a_photo_outlined, color: isDark ? gold : primaryColor)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              _buildField(_nameController, isAr ? 'اسم المنتج' : 'Product Name', Icons.shopping_bag_outlined, isDark, primaryColor, gold, isAr),
              const SizedBox(height: 16),
              _buildField(_categoryController, isAr ? 'الفئة' : 'Category', Icons.category_outlined, isDark, primaryColor, gold, isAr),
              const SizedBox(height: 25),
              Text(isAr ? 'الألوان المتاحة:' : 'Available Colors:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: (isAr ? ['أسود', 'أبيض', 'أحمر', 'أزرق', 'أخضر', 'أصفر', 'بني', 'رمادي', 'وردي', 'بنفسجي', 'برتقالي'] : ['Black', 'White', 'Red', 'Blue', 'Green', 'Yellow', 'Brown', 'Grey', 'Pink', 'Purple', 'Orange']).map((color) { final isSelected = selectedColors.contains(color); final displayColor = colorMap[color] ?? Colors.transparent; return FilterChip(label: Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 12, height: 12, decoration: BoxDecoration(color: displayColor, shape: BoxShape.circle, border: Border.all(color: isDark ? Colors.white24 : Colors.grey.withOpacity(0.5), width: 0.5))), const SizedBox(width: 6), Text(color, style: TextStyle(color: isSelected ? Colors.white : textColor, fontSize: 12))]), selected: isSelected, onSelected: (bool s) { setState(() { if (s) selectedColors.add(color); else selectedColors.remove(color); }); }, selectedColor: isDark ? gold : primaryColor, checkmarkColor: Colors.white, backgroundColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100); }).toList()),
              const SizedBox(height: 25),
              _buildField(_descController, isAr ? 'الوصف' : 'Description', Icons.description_outlined, isDark, primaryColor, gold, isAr, maxLines: 3),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildField(_priceController, isAr ? 'السعر' : 'Price', Icons.attach_money_outlined, isDark, primaryColor, gold, isAr, keyboardType: TextInputType.number)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildField(_shippingPriceController, isAr ? 'سعر الشحن (ثابت)' : 'Shipping (Fixed)', Icons.local_shipping_outlined, isDark, primaryColor, gold, isAr, readOnly: true)),
                ],
              ),
              const SizedBox(height: 40),
              ElevatedButton(onPressed: isSaving ? null : _save, style: ElevatedButton.styleFrom(backgroundColor: isDark ? gold : primaryColor, foregroundColor: isDark ? Colors.black87 : Colors.white, minimumSize: const Size(double.infinity, 55), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))), child: isSaving ? const CircularProgressIndicator(color: Colors.white) : Text(isAr ? 'حفظ المنتج' : 'Save Product', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _imagePreview(String path, {required bool isRemote}) {
    return Stack(
      children: [
        Container(width: 100, height: 100, margin: const EdgeInsets.only(right: 10), decoration: BoxDecoration(borderRadius: BorderRadius.circular(15), image: DecorationImage(image: isRemote ? NetworkImage(path) : FileImage(File(path)) as ImageProvider, fit: BoxFit.cover))),
        Positioned(right: 5, top: 0, child: GestureDetector(onTap: () { setState(() { if (isRemote) _existingUrls.remove(path); else _newImages.removeWhere((f) => f.path == path); }); }, child: const CircleAvatar(radius: 12, backgroundColor: Colors.red, child: Icon(Icons.close, size: 14, color: Colors.white)))),
      ],
    );
  }

  Widget _buildField(TextEditingController controller, String label, IconData icon, bool isDark, Color p, Color g, bool isAr, {int maxLines = 1, TextInputType? keyboardType, bool readOnly = false}) {
    return TextFormField(
      controller: controller, 
      maxLines: maxLines, 
      keyboardType: keyboardType, 
      readOnly: readOnly,
      style: TextStyle(color: isDark ? Colors.white : Colors.black87), 
      decoration: InputDecoration(
        labelText: label, 
        labelStyle: const TextStyle(color: Colors.grey), 
        prefixIcon: Icon(icon, color: isDark ? g : p), 
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade300)), 
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: isDark ? g : p, width: 1.5)), 
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)), 
        fillColor: readOnly ? (isDark ? Colors.black26 : Colors.grey.shade100) : (isDark ? Colors.white.withOpacity(0.02) : Colors.transparent), 
        filled: true
      ), 
      validator: (val) => (val == null || val.isEmpty) ? (isAr ? 'مطلوب' : 'Required') : null
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || (_newImages.isEmpty && _existingUrls.isEmpty)) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('برجاء ملء البيانات واختيار صورة واحدة على الأقل'))); return; }
    setState(() => isSaving = true);
    try {
      final allUrls = await _uploadAllImages();
      
      // جلب سعر الشحن الموحد الحالي لضمان الدقة عند الحفظ
      int currentShipping = 0;
      final configDoc = await FirebaseFirestore.instance.collection('config').doc('contact_info').get();
      if (configDoc.exists) {
        currentShipping = (configDoc.data()?['defaultShippingPrice'] ?? 0).toInt();
      }

      final data = {
        'name': _nameController.text.trim(), 'description': _descController.text.trim(), 
        'price': double.parse(_priceController.text.trim()), 
        'shippingPrice': currentShipping,
        'imageUrl': allUrls.first, 
        'imageUrls': allUrls,
        'category': _categoryController.text.trim(), 'colors': selectedColors, 'updatedAt': FieldValue.serverTimestamp()
      };
      if (widget.product == null) { data['createdAt'] = FieldValue.serverTimestamp(); await FirebaseFirestore.instance.collection('products').add(data); }
      else { await FirebaseFirestore.instance.collection('products').doc(widget.product!.id).update(data); }
      if (mounted) Navigator.pop(context);
    } catch (e) { setState(() => isSaving = false); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'))); }
  }
}
