import 'package:flutter/material.dart';
import 'package:whiteapp/features/profile/models/user_profile.dart';
import 'package:whiteapp/features/profile/services/profile_service.dart';
import 'package:whiteapp/core/services/token_storage.dart';
import 'package:whiteapp/features/auth/screens/login_screen.dart';
import 'package:whiteapp/core/widgets/abstract_background.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserProfile? _profile;
  bool _isLoading = true;
  bool _isEditing = false;
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _bioController = TextEditingController();
  final _locationController = TextEditingController();
  final _cleanDaysController = TextEditingController();
  final _dailyGoalController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await ProfileService.getProfile();
      setState(() {
        _profile = profile;
        _isLoading = false;
        _populateControllers();
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading profile: $e')),
      );
    }
  }

  void _populateControllers() {
    if (_profile != null) {
      _bioController.text = _profile!.bio ?? '';
      _locationController.text = _profile!.location ?? '';
      _cleanDaysController.text = _profile!.cleanDays.toString();
      _dailyGoalController.text = _profile!.dailyGoal.toString();
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final data = {
        'bio': _bioController.text,
        'location': _locationController.text,
        'clean_days': int.tryParse(_cleanDaysController.text) ?? 0,
        'daily_goal': int.tryParse(_dailyGoalController.text) ?? 0,
        // Add other fields as needed
      };

      final updatedProfile = await ProfileService.updateProfile(data);
      setState(() {
        _profile = updatedProfile;
        _isEditing = false;
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully')),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating profile: $e')),
      );
    }
  }

  Future<void> _logout() async {
    await TokenStorage.clearTokens();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil(
        LoginScreen.id,
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.save : Icons.edit),
            onPressed: _isEditing ? _saveProfile : () => setState(() => _isEditing = true),
          ),
        ],
      ),
      body: AbstractBackground(
        scrollProgress: 1.0,
        child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _profile == null
              ? const Center(child: Text('No profile data'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: CircleAvatar(
                            radius: 50,
                            backgroundImage: _profile!.avatar != null
                                ? NetworkImage(_profile!.avatar!)
                                : null,
                            child: _profile!.avatar == null
                                ? const Icon(Icons.person, size: 50)
                                : null,
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildWalletStats(context),
                        const SizedBox(height: 20),
                        _buildTextField('Bio', _bioController, maxLines: 3),
                        _buildTextField('Location', _locationController),
                        _buildTextField('Clean Days', _cleanDaysController, isNumber: true),
                        _buildTextField('Daily Goal', _dailyGoalController, isNumber: true),
                        // Add more fields here
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _logout,
                            icon: const Icon(Icons.logout),
                            label: const Text('Logout'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.withOpacity(0.8),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
      ),
    );
  }

  Widget _buildWalletStats(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(Icons.emoji_events, '${_profile!.trophies}', 'Trophies', Colors.amber),
              _buildStatItem(Icons.monetization_on, '${_profile!.gold}', 'Gold', Colors.orange),
              _buildStatItem(Icons.diamond, '${_profile!.gems}', 'Gems', Colors.cyan),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pushNamed(context, 'badge_shop_screen'),
                  child: const Text('Badge Shop'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pushNamed(context, 'donation_screen'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.cyan, foregroundColor: Colors.black),
                  child: const Text('Donate Gems'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildTextField(String label, TextEditingController controller,
      {int maxLines = 1, bool isNumber = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        enabled: _isEditing,
        maxLines: maxLines,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      ),
    );
  }
}
