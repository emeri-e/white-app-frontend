import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:whiteapp/features/tools/models/flash_card.dart';
import 'package:whiteapp/features/tools/services/tools_service.dart';
import 'package:whiteapp/features/tools/widgets/flash_card_widget.dart';
import 'package:whiteapp/features/tools/screens/manage_decks_screen.dart';

class FlashCardsScreen extends StatefulWidget {
  static const String id = 'flash_cards_screen';

  const FlashCardsScreen({super.key});

  @override
  State<FlashCardsScreen> createState() => _FlashCardsScreenState();
}

class _FlashCardsScreenState extends State<FlashCardsScreen> {
  bool _isLoading = true;
  List<FlashCardDeck> _decks = [];
  FlashCardDeck? _selectedDeck;
  
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  bool _isCompleted = false;
  DateTime? _sessionStart;

  @override
  void initState() {
    super.initState();
    _loadDecks();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadDecks() async {
    setState(() => _isLoading = true);
    try {
      final decks = await ToolsService.getFlashCardDecks();
      setState(() {
        _decks = decks;
        if (_decks.isNotEmpty) {
          _selectedDeck = _decks.first;
          _sessionStart = DateTime.now();
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load decks: $e')),
        );
      }
    }
  }

  void _onDeckSelected(FlashCardDeck deck) {
    setState(() {
      _selectedDeck = deck;
      _currentIndex = 0;
      _isCompleted = false;
      _sessionStart = DateTime.now();
    });
    if (_pageController.hasClients) {
      _pageController.jumpToPage(0);
    }
  }

  Future<void> _submitResponse(String responseText) async {
    HapticFeedback.mediumImpact();
    if (_selectedDeck == null) return;
    
    final currentCard = _selectedDeck!.cards[_currentIndex];
    
    try {
      await ToolsService.submitCardResponse(
        cardId: currentCard.id,
        responseText: responseText,
      );
      
      // Advance to next card or complete
      if (_currentIndex < _selectedDeck!.cards.length - 1) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else {
        _completeSession();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save response: $e')),
        );
      }
    }
  }

  Future<void> _completeSession() async {
    HapticFeedback.heavyImpact();
    setState(() {
      _isCompleted = true;
    });

    if (_selectedDeck != null && _sessionStart != null) {
      final duration = DateTime.now().difference(_sessionStart!).inSeconds;
      try {
        await ToolsService.logToolUsage(
          toolType: 'flashcards',
          toolConfigId: _selectedDeck!.id,
          durationSeconds: duration,
          completed: true,
        );
      } catch (e) {
        debugPrint("Error logging flashcard usage: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Interactive Cards',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white54),
            onPressed: () {
              Navigator.pushNamed(context, ManageDecksScreen.id).then((_) => _loadDecks());
            },
            tooltip: 'Manage Custom Decks',
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : _decks.isEmpty
                ? _buildEmptyState()
                : Column(
                    children: [
                      const SizedBox(height: 10),
                      _buildDeckSelector(),
                      const SizedBox(height: 10),
                      
                      Expanded(
                        child: _selectedDeck!.cards.isEmpty
                            ? Center(
                                child: Text(
                                  "This deck has no cards.",
                                  style: GoogleFonts.outfit(color: Colors.white54),
                                ),
                              )
                            : _isCompleted
                                ? _buildCompletionState()
                                : _buildCardStack(),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.style, size: 80, color: Colors.white24),
          const SizedBox(height: 16),
          Text(
            "No decks available.",
            style: GoogleFonts.outfit(fontSize: 18, color: Colors.white54),
          ),
        ],
      ),
    );
  }

  Widget _buildDeckSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: _decks.map((deck) {
          final isSelected = _selectedDeck?.id == deck.id;
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ChoiceChip(
              label: Text(
                deck.title,
                style: GoogleFonts.outfit(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              selected: isSelected,
              selectedColor: Colors.pinkAccent.withOpacity(0.3),
              backgroundColor: Colors.white.withOpacity(0.1),
              onSelected: (selected) {
                if (selected) {
                  _onDeckSelected(deck);
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCardStack() {
    final cards = _selectedDeck!.cards;
    
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Card ${_currentIndex + 1} of ${cards.length}',
                style: GoogleFonts.outfit(color: Colors.white54, fontWeight: FontWeight.bold),
              ),
              // Optional: Skip button
              TextButton(
                onPressed: () {
                  if (_currentIndex < cards.length - 1) {
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  } else {
                    _completeSession();
                  }
                },
                child: Text('Skip', style: GoogleFonts.outfit(color: Colors.white38)),
              ),
            ],
          ),
        ),
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            physics: const BouncingScrollPhysics(),
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
            },
            itemCount: cards.length,
            itemBuilder: (context, index) {
              return FlashCardWidget(
                card: cards[index],
                onSubmit: _submitResponse,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCompletionState() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.pinkAccent.withOpacity(0.1),
            ),
            child: const Icon(Icons.check_circle_outline, size: 80, color: Colors.pinkAccent),
          ),
          const SizedBox(height: 40),
          Text(
            "Deck Completed",
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "Thank you for taking the time to reflect. Your responses have been saved.",
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 18,
              color: Colors.white70,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 48),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.1),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: Text('Done', style: GoogleFonts.outfit(fontSize: 18)),
          ),
        ],
      ),
    );
  }
}
