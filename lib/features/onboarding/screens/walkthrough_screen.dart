import 'package:flutter/material.dart';
import 'package:whiteapp/core/widgets/abstract_background.dart';
import 'package:whiteapp/core/widgets/glass_text_field.dart';
import 'package:whiteapp/features/home/screens/home_screen.dart';
import 'package:whiteapp/features/recovery/services/recovery_service.dart';
import 'package:whiteapp/core/services/api_service.dart';

class WalkthroughScreen extends StatefulWidget {
  static const String id = 'walkthrough_screen';
  const WalkthroughScreen({super.key});

  @override
  State<WalkthroughScreen> createState() => _WalkthroughScreenState();
}

class _WalkthroughScreenState extends State<WalkthroughScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _usernameController = TextEditingController();
  int? _selectedProgramId;
  List<dynamic> _programs = [];
  bool _isLoadingPrograms = true;

  @override
  void initState() {
    super.initState();
    _loadPrograms();
  }

  Future<void> _loadPrograms() async {
    try {
      final programs = await RecoveryService.getPrograms();
      setState(() {
        _programs = programs;
        _isLoadingPrograms = false;
      });
    } catch (e) {
      setState(() => _isLoadingPrograms = false);
      // Handle error silently or show retry
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AbstractBackground(
        scrollProgress: 1.0,
        child: SafeArea(
          child: Column(
            children: [
              // Progress Indicator
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: Row(
                  children: [
                    _buildProgressDot(0),
                    const SizedBox(width: 8),
                    _buildProgressDot(1),
                  ],
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(), // Disable swipe
                  onPageChanged: (index) => setState(() => _currentPage = index),
                  children: [
                    _buildStep1(),
                    _buildStep2(),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (_currentPage > 0)
                      TextButton(
                        onPressed: () {
                          _pageController.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                        child: const Text(
                          'Back',
                          style: TextStyle(color: Colors.white70, fontSize: 16),
                        ),
                      )
                    else
                      const SizedBox.shrink(),
                    ElevatedButton(
                      onPressed: _handleNext,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: Text(
                        _currentPage == 1 ? 'Finish' : 'Next',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressDot(int index) {
    return Expanded(
      child: Container(
        height: 4,
        decoration: BoxDecoration(
          color: _currentPage >= index ? Theme.of(context).primaryColor : Colors.white24,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildStep1() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Let\'s get to know you',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Text(
              'What should we call you? This will be displayed on your profile.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white70,
                    fontSize: 18,
                  ),
            ),
            const SizedBox(height: 32),
            GlassTextField(
              hintText: 'First Name',
              icon: Icons.person_outline,
              controller: _firstNameController,
            ),
            const SizedBox(height: 16),
            GlassTextField(
              hintText: 'Last Name',
              icon: Icons.person_outline,
              controller: _lastNameController,
            ),
            const SizedBox(height: 16),
            GlassTextField(
              hintText: 'Username',
              icon: Icons.alternate_email,
              controller: _usernameController,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep2() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Choose your path',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          Text(
            'Select a therapeutic program to start your recovery journey.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white70,
                  fontSize: 18,
                ),
          ),
          const SizedBox(height: 32),
          Expanded(
            child: _isLoadingPrograms
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _programs.length,
                    itemBuilder: (context, index) {
                      final program = _programs[index];
                      final isSelected = _selectedProgramId == program['id'];
                      return GestureDetector(
                        onTap: () => setState(() => _selectedProgramId = program['id']),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Theme.of(context).primaryColor.withOpacity(0.2)
                                : Colors.white.withOpacity(0.05),
                            border: Border.all(
                              color: isSelected
                                  ? Theme.of(context).primaryColor
                                  : Colors.white10,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.healing, // Placeholder icon
                                  color: isSelected
                                      ? Theme.of(context).primaryColor
                                      : Colors.white70,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      program['title'] ?? 'Program Title',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      program['description'] ?? 'Description',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 14,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                Icon(
                                  Icons.check_circle,
                                  color: Theme.of(context).primaryColor,
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleNext() async {
    if (_currentPage == 0) {
      if (_firstNameController.text.isEmpty || _lastNameController.text.isEmpty || _usernameController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill in all fields')),
        );
        return;
      }
      
      // Save user details
      try {
        await ApiService.updateProfile({
          'user': {
            'first_name': _firstNameController.text,
            'last_name': _lastNameController.text,
            'username': _usernameController.text,
          }
        });
        
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save profile: $e')),
        );
      }
    } else {
      if (_selectedProgramId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a program')),
        );
        return;
      }
      
      try {
        // Enroll in program
        // Assuming RecoveryService has an enroll method or we use a generic POST
        // We need to implement enrollInProgram in RecoveryService or use ApiService directly
        // Checking RecoveryService... it has getUserEnrollments but maybe not enroll.
        // I'll use ApiService for now or add it to RecoveryService.
        // Let's assume I'll add it to RecoveryService.
        await RecoveryService.enrollInProgram(_selectedProgramId!);
        
        Navigator.pushReplacementNamed(context, HomeScreen.id);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to enroll: $e')),
        );
      }
    }
  }
}
