import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:vet/main.dart';

class ProfileEditView extends StatefulWidget {
  final Map<String, dynamic> userData;
  const ProfileEditView({super.key, required this.userData});

  @override
  State<ProfileEditView> createState() => _ProfileEditViewState();
}

class _ProfileEditViewState extends State<ProfileEditView> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _fbController;
  late TextEditingController _tgController;
  late TextEditingController _waController;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.userData['name'] ?? '');
    _fbController = TextEditingController(text: widget.userData['facebook'] ?? '');
    _tgController = TextEditingController(text: widget.userData['telegram'] ?? '');
    _waController = TextEditingController(text: widget.userData['whatsapp'] ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _fbController.dispose();
    _tgController.dispose();
    _waController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isSaving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'name': _nameController.text.trim(),
          'facebook': _fbController.text.trim(),
          'telegram': _tgController.text.trim(),
          'whatsapp': _waController.text.trim(),
        });
        if (mounted) {
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isAr = MyApp.of(context).locale.languageCode == 'ar';
    Color primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: Text(isAr ? 'تعديل الملف الشخصي' : 'Edit Profile'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle(isAr ? 'المعلومات الأساسية' : 'Basic Info', Icons.person_outline, primaryColor),
              _buildField(_nameController, isAr ? 'الاسم بالكامل' : 'Full Name', Icons.person, primaryColor),
              const SizedBox(height: 25),
              
              _buildSectionTitle(isAr ? 'وسائل التواصل الاجتماعي' : 'Social Media', Icons.share, primaryColor),
              
              _buildSocialField(_fbController, 'Facebook', 'https://facebook.com/yourprofile', Icons.facebook, Colors.blue),
              const SizedBox(height: 15),
              _buildSocialField(_tgController, 'Telegram', 'https://t.me/username', Icons.telegram, Colors.lightBlue),
              const SizedBox(height: 15),
              _buildSocialField(_waController, 'WhatsApp', '0123456789', Icons.phone, Colors.green),
              
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: isSaving ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  minimumSize: const Size(double.infinity, 55),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                ),
                child: isSaving 
                  ? const CircularProgressIndicator(color: Colors.white) 
                  : Text(isAr ? 'حفظ التعديلات' : 'Save Changes', 
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, Color color) => Padding(
    padding: const EdgeInsets.only(bottom: 15), 
    child: Row(children: [Icon(icon, color: color), const SizedBox(width: 10), Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color))])
  );

  Widget _buildField(TextEditingController controller, String label, IconData icon, Color color) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: color),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      validator: (v) => v!.isEmpty ? 'Required' : null,
    );
  }

  Widget _buildSocialField(TextEditingController controller, String label, String hint, IconData icon, Color color) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: color),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
