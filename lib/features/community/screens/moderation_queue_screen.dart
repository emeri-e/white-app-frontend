import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:whiteapp/features/community/controllers/community_controller.dart';
import 'package:whiteapp/features/community/widgets/post_card.dart';
import 'package:whiteapp/core/widgets/abstract_background.dart';

class ModerationQueueScreen extends StatefulWidget {
  const ModerationQueueScreen({Key? key}) : super(key: key);

  @override
  State<ModerationQueueScreen> createState() => _ModerationQueueScreenState();
}

class _ModerationQueueScreenState extends State<ModerationQueueScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<CommunityController>(context, listen: false).fetchPendingPosts();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'Moderation Queue',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: AbstractBackground(
        child: Consumer<CommunityController>(
          builder: (context, controller, child) {
            if (controller.isLoading && controller.pendingPosts.isEmpty) {
              return const Center(child: CircularProgressIndicator(color: Colors.blueAccent));
            }

            if (controller.pendingPosts.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_outline_rounded, size: 64, color: Colors.greenAccent.withOpacity(0.5)),
                    const SizedBox(height: 16),
                    Text(
                      'All clear!',
                      style: GoogleFonts.outfit(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No posts pending moderation.',
                      style: GoogleFonts.outfit(color: Colors.white70),
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () => controller.fetchPendingPosts(),
              color: Colors.blueAccent,
              backgroundColor: const Color(0xFF1E293B),
              child: ListView.builder(
                padding: const EdgeInsets.only(top: kToolbarHeight + 40, bottom: 20),
                itemCount: controller.pendingPosts.length,
                itemBuilder: (context, index) {
                  return PostCard(post: controller.pendingPosts[index]);
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
