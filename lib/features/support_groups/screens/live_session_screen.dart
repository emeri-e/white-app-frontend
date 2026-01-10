import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:whiteapp/features/support_groups/models/support_group.dart';
import 'package:whiteapp/features/support_groups/services/support_group_service.dart';
import 'package:whiteapp/features/support_groups/widgets/group_timeline.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

class LiveSessionScreen extends StatefulWidget {
  final SupportGroup group;

  const LiveSessionScreen({Key? key, required this.group}) : super(key: key);

  @override
  State<LiveSessionScreen> createState() => _LiveSessionScreenState();
}

class _LiveSessionScreenState extends State<LiveSessionScreen> {
  Room? _room;
  EventsListener<RoomEvent>? _listener;
  bool _isConnecting = true;
  String? _error;
  String? _googleMeetLink;
  VideoTrack? _hostVideoTrack;
  bool _isMuted = true;

  @override
  void initState() {
    super.initState();
    _connectToRoom();
  }

  @override
  void dispose() {
    _listener?.dispose();
    _room?.disconnect();
    _room?.dispose();
    super.dispose();
  }

  Future<void> _connectToRoom() async {
    try {
      // Request permissions
      await Permission.microphone.request();
      // If host, request camera too (logic omitted for brevity, assuming participant)

      // Get token
      final data = await SupportGroupService.getLiveKitToken(widget.group.id);
      
      if (data['google_meet_link'] != null) {
        setState(() {
          _googleMeetLink = data['google_meet_link'];
          _isConnecting = false;
        });
        return;
      }

      final token = data['token'];
      final url = 'wss://your-livekit-server.com'; // Should be in Env or response

      // Connect
      _room = Room();
      _listener = _room!.createListener();

      _setupListeners();

      await _room!.connect(url, token);
      
      // Publish microphone (muted by default)
      await _room!.localParticipant?.setMicrophoneEnabled(false);

      setState(() => _isConnecting = false);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isConnecting = false;
      });
    }
  }

  void _setupListeners() {
    _listener!
      ..on<TrackSubscribedEvent>((event) {
        if (event.track is VideoTrack) {
          setState(() => _hostVideoTrack = event.track as VideoTrack);
        }
      })
      ..on<TrackUnsubscribedEvent>((event) {
        if (event.track is VideoTrack) {
          setState(() => _hostVideoTrack = null);
        }
      });
  }

  void _toggleMute() async {
    if (_room?.localParticipant == null) return;
    
    final newMutedState = !_isMuted;
    await _room!.localParticipant!.setMicrophoneEnabled(!newMutedState);
    setState(() => _isMuted = newMutedState);
  }

  void _leaveSession() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.group.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app, color: Colors.red),
            onPressed: _leaveSession,
          ),
        ],
      ),
      body: Column(
        children: [
          // Video Area (Host)
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              color: Colors.black,
              child: _googleMeetLink != null
                  ? Center(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.video_call),
                        label: const Text('Join Google Meet'),
                        onPressed: () => launchUrl(
                          Uri.parse(_googleMeetLink!),
                          mode: LaunchMode.externalApplication,
                        ),
                      ),
                    )
                  : _hostVideoTrack != null
                      ? VideoTrackRenderer(_hostVideoTrack!)
                      : const Center(
                          child: Text(
                            'Waiting for host video...',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
            ),
          ),

          // Controls
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            color: Colors.grey[200],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(_isMuted ? Icons.mic_off : Icons.mic),
                  color: _isMuted ? Colors.red : Colors.green,
                  onPressed: _toggleMute,
                ),
                const SizedBox(width: 16),
                const Text('Audio Only Participant'),
              ],
            ),
          ),

          // Timeline
          Expanded(
            child: GroupTimeline(groupId: widget.group.id),
          ),
        ],
      ),
    );
  }
}
