import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vet/home/login_view.dart';
import 'package:vet/main.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:vet/home/home_screen.dart';

class OnboardingView extends StatefulWidget {
  const OnboardingView({super.key});

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingItem> _items = [
    OnboardingItem(
      titleAr: 'متجر QPet المتكامل',
      titleEn: 'QPet All-in-One Shop',
      descAr: 'تسوق أفضل المنتجات والمستلزمات لأليفك بسهولة وأمان.',
      descEn: 'Shop the best products and supplies for your pet easily and safely.',
      image: 'assets/onboarding1.jpg',
    ),
    OnboardingItem(
      titleAr: 'عناية فائقة بأليفك',
      titleEn: 'Premium Pet Care',
      descAr: 'نوفر لك كل ما يحتاجه أليفك من أطعمة وإكسسوارات وعناية طبية.',
      descEn: 'We provide everything your pet needs from food, accessories, and medical care.',
      image: 'assets/onboarding2.jpg',
    ),
    OnboardingItem(
      titleAr: 'هوية رقمية ذكية',
      titleEn: 'Smart Digital Identity',
      descAr: 'أنشئ بروفايل رقمي لأليفك مع كود QR لسهولة التعرف عليه والوصول لبياناته.',
      descEn: 'Create a digital profile for your pet with a QR code for easy identification.',
      image: 'assets/onboarding3.jpg',
    ),
  ];

  void _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    if (mounted) {
      final user = FirebaseAuth.instance.currentUser;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => user != null ? const HomeScreen() : const LoginView()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isAr = MyApp.of(context).locale.languageCode == 'ar';
    Color primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemCount: _items.length,
                itemBuilder: (context, index) {
                  return SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 60),
                        Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Image.asset(_items[index].image, height: 300),
                        ),
                        const SizedBox(height: 20),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            isAr ? _items[index].titleAr : _items[index].titleEn,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 15),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 40),
                          child: Text(
                            isAr ? _items[index].descAr : _items[index].descEn,
                            style: const TextStyle(fontSize: 16, color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _items.length,
                      (index) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentPage == index ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentPage == index ? primaryColor : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_currentPage == _items.length - 1) {
                          _finishOnboarding();
                        } else {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeInOut,
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                      child: Text(
                        _currentPage == _items.length - 1
                            ? (isAr ? 'ابدأ الآن' : 'Get Started')
                            : (isAr ? 'التالي' : 'Next'),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _finishOnboarding,
                    child: Text(
                      isAr ? 'تخطي' : 'Skip',
                      style: TextStyle(color: Colors.grey.shade600),
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
}

class OnboardingItem {
  final String titleAr;
  final String titleEn;
  final String descAr;
  final String descEn;
  final String image;

  OnboardingItem({
    required this.titleAr,
    required this.titleEn,
    required this.descAr,
    required this.descEn,
    required this.image,
  });
}
