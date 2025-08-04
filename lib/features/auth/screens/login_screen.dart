import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/login_controller.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final LoginController controller = Get.put(LoginController());

    return Scaffold(
      backgroundColor: const Color(0xFFF9F6F9),
      body: Stack(
        children: [
          // Base background
          Container(color: const Color(0xFFF6F6F6)),

          // Main background image
          Image.asset(
            'assets/images/bgimage.png',
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),

          // Centered frosted glass login card
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Obx(
                () => ClipRRect(
                  borderRadius: BorderRadius.circular(30),

                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(25),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: const Color.fromARGB(164, 255, 255, 255),
                        ),
                      ),
                      child: Stack(
                        children: [
                          // Droplet texture overlay inside the card

                          // Login content
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Sign In',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 20),
                              TextField(
                                controller: controller.emailController,
                                decoration: InputDecoration(
                                  prefixIcon: const Icon(Icons.email_outlined),
                                  labelText: 'Email address',
                                  filled: true,
                                  fillColor: Colors.white.withOpacity(0.8),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                                keyboardType: TextInputType.emailAddress,
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: controller.passwordController,
                                decoration: InputDecoration(
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  labelText: 'Password',
                                  filled: true,
                                  // ignore: deprecated_member_use
                                  fillColor: Colors.white.withOpacity(0.8),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                                obscureText: true,
                              ),
                              const SizedBox(height: 10),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () {},
                                  child: const Text('Forgot password?'),
                                ),
                              ),
                              const SizedBox(height: 16),
                              controller.isLoading.value
                                  ? const CircularProgressIndicator()
                                  : ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.black87,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 40,
                                          vertical: 16,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                      ),
                                      onPressed: () => controller.login(),
                                      child: const Text('Sign In'),
                                    ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
