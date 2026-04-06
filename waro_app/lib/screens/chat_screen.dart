// lib/screens/chat_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../services/pause_chat_service.dart';
import '../database/database_helper.dart';
import '../widgets/soundscape_widget.dart';
import 'pause_chat_screen.dart';

class ChatScreen extends StatefulWidget {
  final String? warungId;
  final String? contactId;
  final String? contactName;

  const ChatScreen({super.key, this.warungId, this.contactId, this.contactName});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;
  bool _isPaused = false;
  bool _showSoundscape = false;

  static const String _myId = 'me';
  static const String _myName = 'Saya';

  @override
  void initState() {
    super.initState();
    _loadMessages();
    if (widget.contactId != null) _checkPauseStatus();
  }

  Future<void> _loadMessages() async {
    if (kIsWeb) {
      setState(() {
        _messages = [];
        _isLoading = false;
      });
      return;
    }

    try {
      final db = await DatabaseHelper.instance.database;
      List<Map<String, dynamic>> messages;

      if (widget.warungId != null) {
        messages = await db.query(
          'messages',
          where: 'warung_id = ?',
          whereArgs: [widget.warungId],
          orderBy: 'sent_at ASC',
        );
      } else if (widget.contactId != null) {
        messages = await db.rawQuery('''
          SELECT * FROM messages 
          WHERE (sender_id = ? AND recipient_id = ?) OR (sender_id = ? AND recipient_id = ?)
          ORDER BY sent_at ASC
        ''', [_myId, widget.contactId, widget.contactId, _myId]);
      } else {
        messages = [];
      }

      setState(() => _messages = messages);
      _scrollToBottom();
    } catch (e) {
      debugPrint('Error loading messages: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _checkPauseStatus() async {
    if (widget.contactId == null || kIsWeb) return;
    final paused = await PauseChatService().isContactPaused(widget.contactId!);
    setState(() => _isPaused = paused);
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    // Cek pause
    if (widget.contactId != null && _isPaused) {
      _showPausedDialog(text.trim());
      return;
    }

    if (kIsWeb) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final msg = {
        'message_id': 'web_$now',
        'warung_id': widget.warungId,
        'recipient_id': widget.contactId,
        'sender_id': _myId,
        'sender_name': _myName,
        'content': text.trim(),
        'message_type': 'text',
        'sent_at': now,
        'sync_status': 'synced',
      };
      setState(() {
        _messages.add(msg);
      });
      _textController.clear();
      _scrollToBottom();
      return;
    }

    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final msgId = 'msg_$now';

    await db.insert('messages', {
      'message_id': msgId,
      'warung_id': widget.warungId,
      'recipient_id': widget.contactId,
      'sender_id': _myId,
      'sender_name': _myName,
      'content': text.trim(),
      'message_type': 'text',
      'sent_at': now,
      'sync_status': 'pending',
    });

    _textController.clear();
    HapticFeedback.lightImpact();
    await _loadMessages();
  }

  void _showPausedDialog(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.pause_circle, color: Colors.orange),
          SizedBox(width: 8),
          Text('Chat Sedang Dipause'),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${widget.contactName ?? "Kontak"} sedang dalam mode pause digital.'),
            const SizedBox(height: 8),
            Text(
              'Pesan akan disimpan dan terkirim setelah pause berakhir.',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await PauseChatService().storePendingMessage(
                contactId: widget.contactId!,
                senderId: _myId,
                senderName: _myName,
                message: message,
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Pesan disimpan, akan dikirim setelah pause berakhir'), backgroundColor: Colors.orange),
                );
              }
            },
            child: const Text('Simpan Tertunda'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              await PauseChatService().storePendingMessage(
                contactId: widget.contactId!,
                senderId: _myId,
                senderName: _myName,
                message: message,
                isUrgent: true,
              );
            },
            child: const Text('Kirim Darurat'),
          ),
        ],
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Jika tidak ada warungId/contactId = list chat
    if (widget.warungId == null && widget.contactId == null) {
      return _buildChatList(context);
    }
    return _buildChatRoom(context);
  }

  Widget _buildChatList(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('💬 Pesan'),
        actions: [
          IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          // Pause mode banner
          Container(
            width: double.infinity,
            color: Colors.orange[50],
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.pause_circle, color: Colors.orange, size: 18),
                const SizedBox(width: 8),
                const Text('1 kontak dalam mode pause', style: TextStyle(fontSize: 12)),
                const Spacer(),
                TextButton(
                  onPressed: () {},
                  child: const Text('Lihat', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: 3, // placeholder
              itemBuilder: (_, i) => _buildChatTile(i),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatTile(int i) {
    final names = ['Warung Malam Jumatan', 'Pak RT', 'Bima'];
    final subtitles = ['4 pesan baru • 14 jam lagi', '🎤 Suara lingkungan', 'pinjam pulsa chat 5?'];
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: const Color(0xFF2D7A4F).withOpacity(0.15),
        child: Icon(i == 0 ? Icons.store : Icons.person, color: const Color(0xFF2D7A4F)),
      ),
      title: Text(names[i], style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitles[i], style: const TextStyle(fontSize: 12)),
      trailing: Text('${i + 1}h lalu', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
      onTap: () {},
    );
  }

  Widget _buildChatRoom(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.contactName ?? 'Warung Chat',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            if (_isPaused)
              const Text('⏸ Sedang dipause', style: TextStyle(fontSize: 11, color: Colors.orange)),
          ],
        ),
        actions: [
          if (widget.contactId != null)
            IconButton(
              icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
              tooltip: _isPaused ? 'Akhiri Pause' : 'Pause Chat',
              onPressed: () async {
                if (_isPaused) {
                  await PauseChatService().unpauseContact(widget.contactId!);
                  setState(() => _isPaused = false);
                } else {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PauseChatScreen(
                        contactId: widget.contactId!,
                        contactName: widget.contactName ?? '',
                      ),
                    ),
                  );
                  if (result == true) setState(() => _isPaused = true);
                }
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // Pause banner
          if (_isPaused)
            Container(
              width: double.infinity,
              color: Colors.orange[100],
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.pause_circle, color: Colors.orange),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('Chat dalam mode pause. Pesan disimpan dan dikirim setelah selesai.', style: TextStyle(fontSize: 12))),
                  TextButton(
                    onPressed: () async {
                      await PauseChatService().unpauseContact(widget.contactId!);
                      setState(() => _isPaused = false);
                    },
                    child: const Text('Akhiri'),
                  ),
                ],
              ),
            ),

          // Pesan
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: _messages.length,
              itemBuilder: (_, i) => _buildMessageBubble(_messages[i]),
            ),
          ),

          // Soundscape widget
          if (_showSoundscape)
            SoundscapeRecorderWidget(
              onSoundscapeRecorded: (path) {
                setState(() => _showSoundscape = false);
                debugPrint('Soundscape dikirim: $path');
              },
            ),

          // Input area
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg) {
    final isMe = msg['sender_id'] == _myId;
    final isSystem = msg['sender_id'] == 'system';
    final type = msg['message_type'] ?? 'text';

    if (isSystem) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            msg['content'] ?? '',
            style: TextStyle(fontSize: 11, color: Colors.grey[700]),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFF2D7A4F) : Colors.white,
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomRight: isMe ? const Radius.circular(4) : null,
            bottomLeft: !isMe ? const Radius.circular(4) : null,
          ),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMe && widget.warungId != null)
              Text(
                msg['sender_name'] ?? '',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2D7A4F)),
              ),
            if (type == 'soundscape')
              Row(children: [
                const Icon(Icons.graphic_eq, size: 16),
                const SizedBox(width: 8),
                Text('🎵 Suara Lingkungan (${msg['soundscape_duration'] ?? 10}s)',
                    style: TextStyle(color: isMe ? Colors.white70 : Colors.grey[700], fontSize: 13)),
              ])
            else
              Text(
                msg['content'] ?? '',
                style: TextStyle(color: isMe ? Colors.white : Colors.black87, fontSize: 14),
              ),
            const SizedBox(height: 4),
            Text(
              _formatTime(msg['sent_at']),
              style: TextStyle(fontSize: 10, color: isMe ? Colors.white60 : Colors.grey[400]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, -2))],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.graphic_eq),
            color: const Color(0xFF2D7A4F),
            onPressed: () => setState(() => _showSoundscape = !_showSoundscape),
            tooltip: 'Kirim Suara Lingkungan',
          ),
          Expanded(
            child: TextField(
              controller: _textController,
              decoration: InputDecoration(
                hintText: _isPaused ? 'Chat sedang dipause...' : 'Tulis pesan...',
                hintStyle: const TextStyle(fontSize: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                enabled: !_isLoading,
              ),
              onSubmitted: _sendMessage,
              textInputAction: TextInputAction.send,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.send_rounded),
            color: const Color(0xFF2D7A4F),
            onPressed: () => _sendMessage(_textController.text),
          ),
        ],
      ),
    );
  }

  String _formatTime(dynamic timestamp) {
    if (timestamp == null) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp as int);
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
