import 'package:flutter/material.dart';
import 'package:whiteapp/core/services/offline_manager.dart';
import 'package:whiteapp/features/recovery/widgets/media_display_widget.dart';

class OfflineDownloadsScreen extends StatefulWidget {
  const OfflineDownloadsScreen({Key? key}) : super(key: key);

  @override
  State<OfflineDownloadsScreen> createState() => _OfflineDownloadsScreenState();
}

class _OfflineDownloadsScreenState extends State<OfflineDownloadsScreen> {
  List<Map<String, dynamic>> _offlineMedia = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDownloads();
  }

  Future<void> _loadDownloads() async {
    final media = await OfflineManager.getOfflineMedia();
    if (mounted) {
      setState(() {
        _offlineMedia = media;
        _isLoading = false;
      });
    }
  }

  Future<void> _removeDownload(Map<String, dynamic> media) async {
    await OfflineManager.removeFromOffline(media);
    _loadDownloads();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Removed successfully')),
    );
  }

  void _playMedia(Map<String, dynamic> media) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Offline Player')),
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: MediaDisplayWidget(
                media: media,
                onMediaCompleted: (id) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Offline Content Completed!')),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Downloads'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _offlineMedia.isEmpty
              ? const Center(
                  child: Text(
                    'No downloaded content found.\nNavigate to media and tap "Save" to watch offline.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54, fontSize: 16),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _offlineMedia.length,
                  itemBuilder: (context, index) {
                    final item = _offlineMedia[index];
                    return Card(
                      color: Colors.blueGrey.shade900,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: Icon(
                          item['media_type'] == 'video' ? Icons.videocam : Icons.insert_drive_file,
                          color: Theme.of(context).primaryColor,
                          size: 32,
                        ),
                        title: Text(
                          item['title'] ?? 'Unknown Media',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        subtitle: Text(
                          "${item['media_type']?.toString().toUpperCase()} • Offline",
                          style: const TextStyle(color: Colors.greenAccent),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                          onPressed: () => _removeDownload(item),
                        ),
                        onTap: () => _playMedia(item),
                      ),
                    );
                  },
                ),
    );
  }
}
