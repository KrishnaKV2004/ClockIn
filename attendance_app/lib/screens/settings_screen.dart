import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/profile_service.dart';
import '../services/supabase_service.dart';
import 'login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profileService = Provider.of<ProfileService>(context, listen: false);
    final user = SupabaseService.client.auth.currentUser;
    
    _emailController.text = user?.email ?? '';
    
    try {
      final profile = await profileService.getProfile();
      if (profile != null && mounted) {
        setState(() {
          _nameController.text = profile['full_name'] ?? '';
        });
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    final profileService = Provider.of<ProfileService>(context, listen: false);
    
    try {
      await profileService.updateProfile(fullName: _nameController.text.trim());
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('PROFILE SYNCHRONIZED', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
            backgroundColor: Colors.black,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            margin: const EdgeInsets.all(24),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e', style: const TextStyle(color: Colors.white)),
            backgroundColor: Colors.black,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(letterSpacing: 0, fontSize: 18, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : Padding(
              padding: const EdgeInsets.all(40.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Update Profile',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: -0.5),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Keep your professional identity up to date',
                    style: TextStyle(color: Colors.black38, fontSize: 13),
                  ),
                  const SizedBox(height: 48),
                  _buildInput(
                    controller: _nameController,
                    hint: 'Full Name',
                    icon: Icons.person_outline_rounded,
                  ),
                  const SizedBox(height: 24),
                  _buildInput(
                    controller: _emailController,
                    hint: 'Email Address',
                    icon: Icons.alternate_email_rounded,
                    enabled: false,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Email is managed by administrator',
                    style: TextStyle(color: Colors.black12, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    height: 64,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        elevation: 0,
                      ),
                      child: _isSaving
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text(
                              'SAVE CHANGES',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 2),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: TextButton(
                      onPressed: () async {
                        await SupabaseService.client.auth.signOut();
                        if (mounted) {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(builder: (_) => const LoginScreen()),
                            (route) => false,
                          );
                        }
                      },
                      child: const Text(
                        'SIGN OUT',
                        style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildInput({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool enabled = true,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      child: TextField(
        controller: controller,
        enabled: enabled,
        style: TextStyle(
          color: enabled ? Colors.black : Colors.black26,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.black26, fontSize: 14),
          icon: Icon(icon, color: Colors.black45, size: 20),
        ),
      ),
    );
  }
}
