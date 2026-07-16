import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:whiteapp/core/widgets/abstract_background.dart';
import 'package:whiteapp/features/recovery/services/hero_service.dart';

class HeroOnboardingScreen extends StatefulWidget {
  static const String id = 'hero_onboarding_screen';

  const HeroOnboardingScreen({super.key});

  @override
  State<HeroOnboardingScreen> createState() => _HeroOnboardingScreenState();
}

class _HeroOnboardingScreenState extends State<HeroOnboardingScreen> {
  int _currentStep = 0;
  bool _isLoading = false;
  String? _errorMessage;

  // Step 1 Controllers
  final TextEditingController _storyController = TextEditingController();
  final TextEditingController _aliasController = TextEditingController();
  String _selectedCategory = 'pornography';

  // Step 2 Controllers
  final TextEditingController _signatureController = TextEditingController();
  bool _hasReadTerms = false;
  final ScrollController _termsScrollController = ScrollController();

  // Step 3 Controllers
  List<dynamic> _availableSlots = [];
  int? _selectedSlotId;
  DateTime? _selectedSlotTime;

  // Step 4 Controllers
  String _selectedTshirtSize = 'L';
  final TextEditingController _recipientController = TextEditingController();
  final TextEditingController _address1Controller = TextEditingController();
  final TextEditingController _address2Controller = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _stateController = TextEditingController();
  final TextEditingController _zipController = TextEditingController();
  final TextEditingController _countryController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchSlots();
    _termsScrollController.addListener(() {
      if (_termsScrollController.position.pixels >=
          _termsScrollController.position.maxScrollExtent - 20) {
        if (!_hasReadTerms) {
          setState(() {
            _hasReadTerms = true;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _storyController.dispose();
    _aliasController.dispose();
    _signatureController.dispose();
    _termsScrollController.dispose();
    _recipientController.dispose();
    _address1Controller.dispose();
    _address2Controller.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _zipController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  Future<void> _fetchSlots() async {
    try {
      final slots = await HeroService.getAvailableSlots();
      setState(() {
        _availableSlots = slots;
      });
    } catch (e) {
      debugPrint("Error loading slots: $e");
    }
  }

  void _nextStep() {
    if (_currentStep == 0) {
      // Validate Story summary
      if (_aliasController.text.trim().isEmpty) {
        setState(() => _errorMessage = "Please enter your privacy alias name");
        return;
      }
      if (_storyController.text.trim().length < 50) {
        setState(() => _errorMessage = "Story summary must be at least 50 characters.");
        return;
      }
    } else if (_currentStep == 1) {
      // Validate Consent
      if (!_hasReadTerms) {
        setState(() => _errorMessage = "Please scroll to read all terms & conditions");
        return;
      }
      if (_signatureController.text.trim().isEmpty) {
        setState(() => _errorMessage = "Type your full name to sign agreement");
        return;
      }
    } else if (_currentStep == 2) {
      // Validate slot selection
      if (_selectedSlotId == null) {
        setState(() => _errorMessage = "Please choose a live session time-slot");
        return;
      }
    }

    setState(() {
      _currentStep++;
      _errorMessage = null;
    });
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
        _errorMessage = null;
      });
    }
  }

  Future<void> _submitAll() async {
    // Validate Shipping Form
    if (_recipientController.text.trim().isEmpty ||
        _address1Controller.text.trim().isEmpty ||
        _cityController.text.trim().isEmpty ||
        _stateController.text.trim().isEmpty ||
        _zipController.text.trim().isEmpty ||
        _countryController.text.trim().isEmpty) {
      setState(() => _errorMessage = "Please fill in all shipping details");
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. Submit narrative story summary
      await HeroService.submitStory(
        storySummary: _storyController.text.trim(),
        programCategory: _selectedCategory,
        alias: _aliasController.text.trim(),
      );

      // 2. Sign electronic consent
      await HeroService.signConsent();

      // 3. Book the Live session time-slot
      await HeroService.bookSlot(_selectedSlotId!);

      // 4. Submit merchandising & reward logistics
      await HeroService.submitShipping(
        tshirtSize: _selectedTshirtSize,
        recipientName: _recipientController.text.trim(),
        addressLine1: _address1Controller.text.trim(),
        addressLine2: _address2Controller.text.trim(),
        city: _cityController.text.trim(),
        state: _stateController.text.trim(),
        postalCode: _zipController.text.trim(),
        country: _countryController.text.trim(),
      );

      // Successfully completed onboarding! Show celebration overlay
      setState(() {
        _isLoading = false;
        _currentStep = 4; // Step 4 = Success celebratory overlay
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll("Exception: ", "");
      });
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
              // Header section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Row(
                  children: [
                    if (_currentStep < 4)
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                        onPressed: _currentStep > 0 ? _previousStep : () => Navigator.pop(context),
                      ),
                    const SizedBox(width: 8),
                    Text(
                      'White Hero Onboarding',
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

              // Linear step indicator
              if (_currentStep < 4) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Row(
                    children: List.generate(4, (index) {
                      final isActive = index <= _currentStep;
                      return Expanded(
                        child: Container(
                          height: 4,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: isActive
                                ? Theme.of(context).colorScheme.secondary
                                : Colors.white24,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'Step ${_currentStep + 1} of 4',
                      style: GoogleFonts.outfit(color: Colors.white60, fontSize: 12),
                    ),
                  ),
                ),
              ],

              // Main wizard screens
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_errorMessage != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded, color: Colors.redAccent),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (_currentStep == 0) _buildStorySubmission(),
                      if (_currentStep == 1) _buildTermsConsent(),
                      if (_currentStep == 2) _buildLiveSlotsScheduling(),
                      if (_currentStep == 3) _buildShippingRewards(),
                      if (_currentStep == 4) _buildSuccessCelebration(),
                    ],
                  ),
                ),
              ),

              // Navigation action buttons
              if (_currentStep < 4)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading
                          ? null
                          : (_currentStep == 3 ? _submitAll : _nextStep),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                        elevation: 4,
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              _currentStep == 3 ? 'Finish & Claim Reward' : 'Continue',
                              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStorySubmission() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your Recovery Summary',
          style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 8),
        Text(
          'Submit a brief overview of your recovery journey. This summary will be showcased on your hero profile to inspire others.',
          style: GoogleFonts.outfit(fontSize: 14, color: Colors.white70),
        ),
        const SizedBox(height: 24),
        Text(
          'Privacy Alias Name',
          style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white70),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _aliasController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'e.g. BraveExplorer',
            hintStyle: const TextStyle(color: Colors.white30),
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Primary Program Focus',
          style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white70),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ['pornography', 'drugs', 'depression', 'anxiety', 'other'].map((cat) {
            final isSelected = _selectedCategory == cat;
            return ChoiceChip(
              label: Text(cat.toUpperCase()),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) setState(() => _selectedCategory = cat);
              },
              selectedColor: Theme.of(context).primaryColor,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              backgroundColor: Colors.white.withOpacity(0.05),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        Text(
          'Narrative Summary',
          style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white70),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _storyController,
          maxLines: 8,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Share how you stayed resilient, the tools you used, and what kept you moving forward (Minimum 50 characters)...',
            hintStyle: const TextStyle(color: Colors.white30),
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }

  Widget _buildTermsConsent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Live Stream Consent',
          style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 8),
        Text(
          'Please read and sign the session guidelines and broadcasting terms.',
          style: GoogleFonts.outfit(fontSize: 14, color: Colors.white70),
        ),
        const SizedBox(height: 20),
        Container(
          height: 260,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white12),
          ),
          child: Scrollbar(
            controller: _termsScrollController,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _termsScrollController,
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'WHITE HEROES BROADCAST AGREEMENT\n\n'
                '1. Recording & Archiving\n'
                'By signing this agreement, you consent to the audio and video recording of your co-hosted live sharing session. These recordings will be stored in our VOD (Video on Demand) library to assist, encourage, and inspire other members of the community.\n\n'
                '2. Respect Guidelines\n'
                'You agree to respect the identity, safety, and background of other community members. Strong language, slurs, explicit terms, or promotional material are strictly prohibited during the live broadcast.\n\n'
                '3. Confidentiality & Safety\n'
                'We use your chosen Alias to display your name. Do not reveal private information, home address, social security details, or identity parameters of third-parties during the event.\n\n'
                '4. Liability Release\n'
                'The organization reserves the right to unpublish, trim, remove, or flag any video broadcast, comments, or reaction counts that violate our community policies at any given time.\n\n'
                'By scrolling to the bottom and typing your name in the text field below, you acknowledge and agree to all terms.',
                style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13, height: 1.6),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Checkbox(
              value: _hasReadTerms,
              onChanged: (val) {
                if (val == true) {
                  setState(() => _hasReadTerms = true);
                }
              },
            ),
            Expanded(
              child: Text(
                'I have read and agree to all Terms and Conditions.',
                style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          'Electronic Signature (Type full name to sign)',
          style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white70),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _signatureController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'e.g. Brave Explorer Signature',
            hintStyle: const TextStyle(color: Colors.white30),
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }

  Widget _buildLiveSlotsScheduling() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Session Date & Time',
          style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 8),
        Text(
          'Choose one of our open live slot sessions to speak with a recovery counselor.',
          style: GoogleFonts.outfit(fontSize: 14, color: Colors.white70),
        ),
        const SizedBox(height: 20),
        if (_availableSlots.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Column(
                children: [
                  const Icon(Icons.event_busy_rounded, size: 48, color: Colors.white24),
                  const SizedBox(height: 12),
                  Text(
                    'No slots currently available. Please check back later or contact support.',
                    style: GoogleFonts.outfit(color: Colors.white54, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _availableSlots.length,
            itemBuilder: (context, index) {
              final slot = _availableSlots[index];
              final slotId = slot['id'] as int;
              final time = DateTime.parse(slot['scheduled_time']);
              final duration = slot['duration_minutes'] ?? 60;
              final isSelected = _selectedSlotId == slotId;

              // Format date cleanly
              final dateStr = '${time.day}/${time.month}/${time.year}';
              final timeStr = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: isSelected ? Theme.of(context).primaryColor.withOpacity(0.2) : Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? Theme.of(context).primaryColor : Colors.white12,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: ListTile(
                  onTap: () {
                    setState(() {
                      _selectedSlotId = slotId;
                      _selectedSlotTime = time;
                    });
                  },
                  leading: Icon(
                    Icons.event_available_rounded,
                    color: isSelected ? Theme.of(context).primaryColor : Colors.white70,
                  ),
                  title: Text(
                    'Date: $dateStr at $timeStr',
                    style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Duration: $duration minutes',
                    style: GoogleFonts.outfit(color: Colors.white70, fontSize: 12),
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle_rounded, color: Colors.greenAccent)
                      : null,
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildShippingRewards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Claim Your Hero Reward',
          style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 8),
        Text(
          'To celebrate your milestone, we will ship you a premium, custom-branded White Hero T-Shirt. Select your size and enter your shipping details.',
          style: GoogleFonts.outfit(fontSize: 14, color: Colors.white70),
        ),
        const SizedBox(height: 20),
        Text(
          'Garment Size Selection',
          style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white70),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: ['S', 'M', 'L', 'XL', 'XXL'].map((size) {
            final isSelected = _selectedTshirtSize == size;
            return InkWell(
              onTap: () => setState(() => _selectedTshirtSize = size),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isSelected ? Theme.of(context).colorScheme.secondary : Colors.white.withOpacity(0.05),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? Theme.of(context).colorScheme.secondary : Colors.white24,
                  ),
                ),
                child: Center(
                  child: Text(
                    size,
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
        Text(
          'Recipient Name',
          style: GoogleFonts.outfit(fontSize: 13, color: Colors.white70),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _recipientController,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Full legal name',
            hintStyle: const TextStyle(color: Colors.white24),
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Address Line 1',
          style: GoogleFonts.outfit(fontSize: 13, color: Colors.white70),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _address1Controller,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Street address, P.O. box',
            hintStyle: const TextStyle(color: Colors.white24),
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Address Line 2',
          style: GoogleFonts.outfit(fontSize: 13, color: Colors.white70),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _address2Controller,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Apartment, suite, unit (optional)',
            hintStyle: const TextStyle(color: Colors.white24),
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('City', style: GoogleFonts.outfit(fontSize: 13, color: Colors.white70)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _cityController,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('State / Region', style: GoogleFonts.outfit(fontSize: 13, color: Colors.white70)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _stateController,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ZIP / Postal Code', style: GoogleFonts.outfit(fontSize: 13, color: Colors.white70)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _zipController,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Country', style: GoogleFonts.outfit(fontSize: 13, color: Colors.white70)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _countryController,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSuccessCelebration() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.greenAccent.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.stars_rounded,
              size: 96,
              color: Colors.greenAccent,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Milestone Booked!',
            style: GoogleFonts.outfit(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'Congratulations! Your live session has been confirmed and scheduled. Your White Hero shirt (Size $_selectedTshirtSize) is now queued for delivery.',
              style: GoogleFonts.outfit(color: Colors.white70, fontSize: 15, height: 1.5),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.greenAccent,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              ),
              child: Text(
                'Return to Dashboard',
                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
