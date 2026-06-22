import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
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
  File? _selectedImage;
  String? _existingImageUrl;
  String selectedCategory = 'طعام';
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product?.name ?? '');
    _descController = TextEditingController(text: widget.product?.description ?? '');
    _priceController = TextEditingController(text: widget.product?.price.toString() ?? '');
    _existingImageUrl = widget.product?.imageUrl;
    selectedCategory = widget.product?.category ?? 'طعام';
  }

  Future<void> _pickImage(Color primaryColor) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (image != null) setState(() => _selectedImage = File(image.path));
  }

  Future<String?> _uploadImage() async {
    if (_selectedImage == null) return _existingImageUrl;
    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      await supabase.storage.from('images').upload(fileName, _selectedImage!);
      return supabase.storage.from('images').getPublicUrl(fileName);
    } catch (e) { return null; }
  }

  @override
  Widget build(BuildContext context) {
    bool isAr = MyApp.of(context).locale.languageCode == 'ar';
    Color primaryColor = Theme.of(context).primaryColor;
    final List<String> categories = isAr ? ['طعام', 'إكسسوارات', 'أسرة', 'ألعاب', 'أدوية'] : ['Food', 'Accessories', 'Beds', 'Toys', 'Medicine'];

    return Scaffold(
      appBar: AppBar(title: Text(widget.product == null ? (isAr ? 'إضافة منتج' : 'Add Product') : (isAr ? 'تعديل المنتج' : 'Edit Product')), backgroundColor: primaryColor, foregroundColor: Colors.white),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              GestureDetector(
                onTap: () => _pickImage(primaryColor),
                child: Container(
                  height: 180, width: double.infinity,
                  decoration: BoxDecoration(color: primaryColor.withOpacity(0.05), borderRadius: BorderRadius.circular(15), border: Border.all(color: primaryColor.withOpacity(0.3))),
                  child: _selectedImage != null ? ClipRRect(borderRadius: BorderRadius.circular(15), child: Image.file(_selectedImage!, fit: BoxFit.cover)) : (_existingImageUrl != null ? ClipRRect(borderRadius: BorderRadius.circular(15), child: Image.network(_existingImageUrl!, fit: BoxFit.cover)) : Icon(Icons.add_a_photo, size: 50, color: primaryColor)),
                ),
              ),
              const SizedBox(height: 24),
              _buildField(_nameController, isAr ? 'اسم المنتج' : 'Product Name', Icons.shopping_bag, primaryColor, isAr),
              const SizedBox(height: 16),
              _buildField(_descController, isAr ? 'الوصف' : 'Description', Icons.description, primaryColor, isAr, maxLines: 3),
              const SizedBox(height: 16),
              _buildField(_priceController, isAr ? 'السعر' : 'Price', Icons.attach_money, primaryColor, isAr, keyboardType: TextInputType.number),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: isAr ? selectedCategory : _translateCat(selectedCategory),
                decoration: InputDecoration(labelText: isAr ? 'الفئة' : 'Category', prefixIcon: Icon(Icons.category, color: primaryColor), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (val) => setState(() => selectedCategory = isAr ? val! : _reverseTranslateCat(val!)),
              ),
              const SizedBox(height: 32),
              ElevatedButton(onPressed: isSaving ? null : _save, style: ElevatedButton.styleFrom(backgroundColor: primaryColor, minimumSize: const Size(double.infinity, 55), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))), child: isSaving ? const CircularProgressIndicator(color: Colors.white) : Text(isAr ? 'حفظ' : 'Save', style: const TextStyle(color: Colors.white, fontSize: 18))),
            ],
          ),
        ),
      ),
    );
  }

  String _translateCat(String c) { Map<String, String> m = {'طعام': 'Food', 'إكسسوارات': 'Accessories', 'أسرة': 'Beds', 'ألعاب': 'Toys', 'أدوية': 'Medicine'}; return m[c] ?? c; }
  String _reverseTranslateCat(String c) { Map<String, String> m = {'Food': 'طعام', 'Accessories': 'إكسسوارات', 'Beds': 'أسرة', 'Toys': 'ألعاب', 'Medicine': 'أدوية'}; return m[c] ?? c; }

  Widget _buildField(TextEditingController controller, String label, IconData icon, Color color, bool isAr, {int maxLines = 1, TextInputType? keyboardType}) {
    return TextFormField(controller: controller, maxLines: maxLines, keyboardType: keyboardType, decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon, color: color), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))), validator: (val) => val!.isEmpty ? (isAr ? 'مطلوب' : 'Required') : null);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || (_selectedImage == null && _existingImageUrl == null)) return;
    setState(() => isSaving = true);
    try {
      final url = await _uploadImage();
      if (url == null) throw 'Upload Error';
      final data = {'name': _nameController.text.trim(), 'description': _descController.text.trim(), 'price': double.parse(_priceController.text.trim()), 'imageUrl': url, 'category': selectedCategory, 'updatedAt': FieldValue.serverTimestamp()};
      if (widget.product == null) { data['createdAt'] = FieldValue.serverTimestamp(); await FirebaseFirestore.instance.collection('products').add(data); }
      else { await FirebaseFirestore.instance.collection('products').doc(widget.product!.id).update(data); }
      if (mounted) Navigator.pop(context);
    } catch (e) { setState(() => isSaving = false); }
  }
}
