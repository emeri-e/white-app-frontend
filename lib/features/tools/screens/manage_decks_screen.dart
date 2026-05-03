import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:whiteapp/features/tools/models/flash_card.dart';
import 'package:whiteapp/features/tools/services/tools_service.dart';

class ManageDecksScreen extends StatefulWidget {
  static const String id = 'manage_decks_screen';

  const ManageDecksScreen({super.key});

  @override
  State<ManageDecksScreen> createState() => _ManageDecksScreenState();
}

class _ManageDecksScreenState extends State<ManageDecksScreen> {
  bool _isLoading = true;
  List<FlashCardDeck> _decks = [];
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadDecks();
  }

  Future<void> _loadDecks() async {
    setState(() => _isLoading = true);
    try {
      final decks = await ToolsService.getFlashCardDecks();
      setState(() {
        // Only show custom decks the user can edit if that was the intent. 
        // For simplicity, we show all, but disable edit for isDefault.
        _decks = decks;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _showCreateDeckModal() async {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    
    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 24, right: 24, top: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Create Custom Deck', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 20),
            TextField(
              controller: titleController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Title', labelStyle: TextStyle(color: Colors.white54)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Description', labelStyle: TextStyle(color: Colors.white54)),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.trim().isEmpty) return;
                Navigator.pop(context);
                setState(() => _isLoading = true);
                try {
                  await ToolsService.createUserDeck(titleController.text.trim(), descController.text.trim());
                  _loadDecks();
                } catch (e) {
                  setState(() => _isLoading = false);
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              child: const Text('Create'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddCardModal(FlashCardDeck deck) async {
    if (deck.isDefault) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot edit default decks.')));
      return;
    }

    final questionController = TextEditingController();
    XFile? selectedImage;
    
    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 24, right: 24, top: 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Add Card', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 20),
                
                GestureDetector(
                  onTap: () async {
                    final img = await _picker.pickImage(source: ImageSource.gallery);
                    if (img != null) {
                      setModalState(() => selectedImage = img);
                    }
                  },
                  child: Container(
                    height: 150,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: selectedImage == null ? Colors.white24 : Colors.pinkAccent),
                    ),
                    child: Center(
                      child: selectedImage == null
                          ? const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_photo_alternate, color: Colors.white38, size: 40),
                                SizedBox(height: 8),
                                Text('Tap to select image', style: TextStyle(color: Colors.white38)),
                              ],
                            )
                          : const Text('Image selected', style: TextStyle(color: Colors.pinkAccent, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                TextField(
                  controller: questionController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Prompt / Question', labelStyle: TextStyle(color: Colors.white54)),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () async {
                    if (questionController.text.trim().isEmpty || selectedImage == null) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select an image and enter a prompt.')));
                      return;
                    }
                    Navigator.pop(context);
                    setState(() => _isLoading = true);
                    try {
                      await ToolsService.addCardToDeck(deck.id, questionController.text.trim(), selectedImage!.path);
                      _loadDecks();
                    } catch (e) {
                      setState(() => _isLoading = false);
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                  },
                  child: const Text('Save Card'),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Manage Decks', style: GoogleFonts.outfit(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: _showCreateDeckModal,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _decks.length,
              itemBuilder: (context, index) {
                final deck = _decks[index];
                return Card(
                  color: const Color(0xFF1E293B),
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: ExpansionTile(
                    title: Text(deck.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    subtitle: Text(deck.isDefault ? "Default Deck" : "Custom Deck", style: const TextStyle(color: Colors.white54)),
                    iconColor: Colors.white,
                    collapsedIconColor: Colors.white54,
                    children: [
                      if (!deck.isDefault)
                        ListTile(
                          leading: const Icon(Icons.add_circle, color: Colors.pinkAccent),
                          title: const Text('Add Card', style: TextStyle(color: Colors.pinkAccent)),
                          onTap: () => _showAddCardModal(deck),
                        ),
                      ...deck.cards.map((card) => ListTile(
                        leading: const Icon(Icons.image, color: Colors.white38),
                        title: Text(card.questionText, style: const TextStyle(color: Colors.white70)),
                      )),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
