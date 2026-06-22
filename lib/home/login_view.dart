import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vet/home/qr_scanner_view.dart';
import 'package:vet/main.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _nameController = TextEditingController(); // المتحكم الجديد للاسم
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool isLoading = false;
  bool isLogin = true;
  String selectedRole = 'owner';

  Future<void> _submit(bool isAr) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => isLoading = true);
    try {
      if (isLogin) {
        await _auth.signInWithEmailAndPassword(
          email: _emailController.text.trim(), 
          password: _passwordController.text.trim()
        );
      } else {
        UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
          email: _emailController.text.trim(), 
          password: _passwordController.text.trim()
        );
        // حفظ الاسم والدور في Firestore
        await _firestore.collection('users').doc(userCredential.user!.uid).set({
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim(), 
          'role': selectedRole, 
          'createdAt': FieldValue.serverTimestamp()
        });
      }
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? (isAr ? 'خطأ' : 'Error'))));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isAr = MyApp.of(context).locale.languageCode == 'ar';
    Color primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [primaryColor.withOpacity(0.8), primaryColor.withOpacity(0.1)])),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.pets, size: 80, color: primaryColor),
                      const SizedBox(height: 16),
                      Text(isLogin ? (isAr ? 'تسجيل الدخول' : 'Login') : (isAr ? 'إنشاء حساب' : 'Sign Up'), style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: primaryColor)),
                      const SizedBox(height: 32),
                      if (!isLogin) ...[
                        Text(isAr ? 'اختر نوع الحساب:' : 'Select account type:', style: const TextStyle(fontWeight: FontWeight.bold)),
                        Row(children: [
                          Expanded(child: RadioListTile<String>(title: Text(isAr ? 'صاحب أليف' : 'Owner', style: const TextStyle(fontSize: 10)), value: 'owner', groupValue: selectedRole, onChanged: (v) => setState(() => selectedRole = v!))),
                          Expanded(child: RadioListTile<String>(title: Text(isAr ? 'طبيب' : 'Doctor', style: const TextStyle(fontSize: 10)), value: 'doctor', groupValue: selectedRole, onChanged: (v) => setState(() => selectedRole = v!))),
                        ]),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _nameController, 
                          decoration: InputDecoration(
                            labelText: isAr ? 'الاسم الكامل' : 'Full Name', 
                            prefixIcon: Icon(Icons.person, color: primaryColor),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          validator: (v) => v!.isEmpty ? (isAr ? 'برجاء إدخال الاسم' : 'Please enter your name') : null,
                        ),
                        const SizedBox(height: 16),
                      ],
                      TextFormField(
                        controller: _emailController, 
                        decoration: InputDecoration(
                          labelText: isAr ? 'البريد الإلكتروني' : 'Email', 
                          prefixIcon: Icon(Icons.email, color: primaryColor),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (v) => v!.isEmpty || !v.contains('@') ? (isAr ? 'بريد غير صالح' : 'Invalid Email') : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController, 
                        obscureText: true, 
                        decoration: InputDecoration(
                          labelText: isAr ? 'كلمة المرور' : 'Password', 
                          prefixIcon: Icon(Icons.lock, color: primaryColor),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (v) => v!.length < 6 ? (isAr ? 'كلمة المرور قصيرة' : 'Password too short') : null,
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : () => _submit(isAr),
                          style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          child: isLoading ? const CircularProgressIndicator(color: Colors.white) : Text(isLogin ? (isAr ? 'دخول' : 'Login') : (isAr ? 'تسجيل' : 'Register')),
                        ),
                      ),
                      TextButton(onPressed: () => setState(() => isLogin = !isLogin), child: Text(isLogin ? (isAr ? 'ليس لديك حساب؟ سجل الآن' : 'No account? Sign Up') : (isAr ? 'لديك حساب بالفعل؟ سجل دخولك' : 'Have an account? Login'))),
                      const Divider(),
                      TextButton.icon(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const QrScannerView())),
                        icon: const Icon(Icons.qr_code_scanner, color: Colors.orange),
                        label: Text(isAr ? 'دخول سريع كزائر' : 'Guest Quick Access', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
