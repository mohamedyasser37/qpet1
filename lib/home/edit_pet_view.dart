import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vet/main.dart';

class EditPetView extends StatefulWidget {
  final String petId;
  final Map<String, dynamic> initialData;

  const EditPetView({super.key, required this.petId, required this.initialData});

  @override
  State<EditPetView> createState() => _EditPetViewState();
}

class _EditPetViewState extends State<EditPetView> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _typeController;
  late TextEditingController _ownerNameController;
  late TextEditingController _ownerPhoneController;
  bool isUpdating = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialData['animalName']);
    _typeController = TextEditingController(text: widget.initialData['animalType']);
    _ownerNameController = TextEditingController(text: widget.initialData['ownerName']);
    _ownerPhoneController = TextEditingController(text: widget.initialData['ownerPhone']);
  }

  Future<void> _updatePet(bool isAr) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => isUpdating = true);
    try {
      await FirebaseFirestore.instance.collection('pets').doc(widget.petId).update({
        'animalName': _nameController.text.trim(),
        'animalType': _typeController.text.trim(),
        'ownerName': _ownerNameController.text.trim(),
        'ownerPhone': _ownerPhoneController.text.trim(),
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isAr ? 'تم التحديث بنجاح' : 'Updated Successfully')));
        Navigator.pop(context, true);
      }
    } catch (e) { setState(() => isUpdating = false); }
  }

  @override
  Widget build(BuildContext context) {
    bool isAr = MyApp.of(context).locale.languageCode == 'ar';
    Color primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(title: Text(isAr ? 'تعديل بيانات الأليف' : 'Edit Pet Data'), backgroundColor: primaryColor, foregroundColor: Colors.white),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Icon(Icons.edit_note, size: 80, color: primaryColor),
              const SizedBox(height: 30),
              _buildField(_nameController, isAr ? 'اسم الحيوان' : 'Pet Name', Icons.pets, primaryColor, isAr),
              const SizedBox(height: 16),
              _buildField(_typeController, isAr ? 'نوع الحيوان' : 'Animal Type', Icons.category, primaryColor, isAr),
              const SizedBox(height: 16),
              _buildField(_ownerNameController, isAr ? 'اسم الصاحب' : 'Owner Name', Icons.person, primaryColor, isAr),
              const SizedBox(height: 16),
              _buildField(_ownerPhoneController, isAr ? 'رقم الهاتف' : 'Phone Number', Icons.phone, primaryColor, isAr, keyboardType: TextInputType.phone),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: isUpdating ? null : () => _updatePet(isAr),
                style: ElevatedButton.styleFrom(backgroundColor: primaryColor, minimumSize: const Size(double.infinity, 55), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                child: isUpdating ? const CircularProgressIndicator(color: Colors.white) : Text(isAr ? 'تحديث البيانات' : 'Update Data', style: const TextStyle(color: Colors.white, fontSize: 18)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController controller, String label, IconData icon, Color color, bool isAr, {TextInputType? keyboardType}) {
    return TextFormField(controller: controller, keyboardType: keyboardType, decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon, color: color), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))), validator: (val) => val!.isEmpty ? (isAr ? 'مطلوب' : 'Required') : null);
  }
}
