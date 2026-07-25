import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/database/schemas/message.dart';
import '../../../core/services/providers.dart';
import 'widgets/chat_bubble.dart';
import 'widgets/swipe_to_reply.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String peerId;
  final String nickname;

  const ChatScreen({
    super.key,
    required this.peerId,
    required this.nickname,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  Message? _replyingToMessage;

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty && _replyingToMessage == null) return;

    final router = ref.read(meshRouterStateProvider).valueOrNull;
    if (router == null) return;

    try {
      _textController.clear();
      final replyId = _replyingToMessage?.id;
      setState(() => _replyingToMessage = null);

      await router.sendMessage(
        widget.peerId,
        text,
        replyToMessageId: replyId,
      );

      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send: $e')),
        );
      }
    }
  }

  Future<void> _pickAndSendFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );

      if (result == null || result.files.single.path == null) return;

      final router = ref.read(meshRouterStateProvider).valueOrNull;
      if (router == null) return;

      final filePath = result.files.single.path!;
      
      // Determine if image or general file
      final ext = filePath.split('.').last.toLowerCase();
      final isImage = ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Chunking and sending file: ${result.files.single.name}...')),
      );

      await router.sendFile(
        widget.peerId,
        filePath,
        mediaType: isImage ? 'image' : 'file',
      );

      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send file: $e')),
        );
      }
    }
  }

  void _showReactionSheet(BuildContext context, Message msg) {
    final theme = Theme.of(context);
    final emojis = ['👍', '❤️', '😂', '😮', '😢', '🙏'];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: emojis.map((emoji) {
              return InkWell(
                onTap: () async {
                  final db = ref.read(databaseServiceProvider);
                  msg.reactions = emoji;
                  await db.saveMessage(msg);
                  
                  // Also send reaction packet to peer
                  final router = ref.read(meshRouterStateProvider).valueOrNull;
                  if (router != null) {
                    await router.sendMessage(widget.peerId, emoji); // Basic ping reaction fallback
                  }

                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                },
                child: Text(
                  emoji,
                  style: const TextStyle(fontSize: 32),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final messagesAsync = ref.watch(messagesStreamProvider(widget.peerId));
    final chunkProgress = ref.watch(chunkProgressProvider).valueOrNull ?? {};

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: theme.colorScheme.primary.withOpacity(0.2),
              child: Text(
                widget.nickname.isNotEmpty ? widget.nickname[0].toUpperCase() : '?',
                style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.nickname, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const Text(
                  'End-to-End Encrypted',
                  style: TextStyle(fontSize: 10, color: Colors.white70),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.security, color: Colors.greenAccent),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Row(
                    children: [
                      Icon(Icons.verified_user, color: Colors.green),
                      SizedBox(width: 8),
                      Text('E2EE Handshake Active'),
                    ],
                  ),
                  content: const Text(
                    'All text and file transmissions in this chat are encrypted using AES-256-GCM. '
                    'A digital signature using Elliptic Curve P-256 is appended to every packet for authentication and tampering prevention.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('OK'),
                    )
                  ],
                ),
              );
            },
          )
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.chatBackgroundDark : AppTheme.chatBackgroundLight,
        ),
        child: Column(
          children: [
            // Messages List View
            Expanded(
              child: messagesAsync.when(
                data: (messages) {
                  if (messages.isEmpty) {
                    return Center(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.symmetric(horizontal: 32),
                        decoration: BoxDecoration(
                          color: theme.cardColor.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'No messages yet. Send a message to start communicating offline!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    );
                  }

                  // Schedule scroll to bottom once built
                  WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

                  return ListView.builder(
                    controller: _scrollController,
                    itemCount: messages.length,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      final isMe = msg.senderId != widget.peerId;

                      // Check if message is a reply to another message
                      String? replyText;
                      if (msg.replyToMessageId != null) {
                        final repliedMsg = messages.firstWhere(
                          (m) => m.id == msg.replyToMessageId,
                          orElse: () => Message()..text = 'Original Message Deleted',
                        );
                        replyText = repliedMsg.text.isNotEmpty ? repliedMsg.text : 'Media Attachment';
                      }

                      return SwipeToReply(
                        onReply: () {
                          setState(() {
                            _replyingToMessage = msg;
                          });
                        },
                        child: ChatBubble(
                          message: msg,
                          isMe: isMe,
                          replyToText: replyText,
                          onLongPress: () => _showReactionSheet(context, msg),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(child: Text('Error: $err')),
              ),
            ),

            // File Chunk Assembly Progress Banner
            if (chunkProgress.isNotEmpty)
              ...chunkProgress.entries.map((entry) {
                final double percent = entry.value * 100;
                return Container(
                  color: theme.colorScheme.primary.withOpacity(0.15),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Receiving file fragments... ${percent.toStringAsFixed(0)}%',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                );
              }),

            // Reply Context Preview Widget
            if (_replyingToMessage != null)
              Container(
                color: theme.cardColor,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.reply, color: Colors.grey, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Replying to ${_replyingToMessage!.senderId == widget.peerId ? widget.nickname : 'Myself'}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          Text(
                            _replyingToMessage!.text.isNotEmpty 
                                ? _replyingToMessage!.text 
                                : 'Media attachment',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => setState(() => _replyingToMessage = null),
                    ),
                  ],
                ),
              ),

            // Chat Input Box
            SafeArea(
              child: Container(
                color: theme.cardColor,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  children: [
                    // Attach media button
                    IconButton(
                      icon: const Icon(Icons.attach_file, color: Colors.grey),
                      onPressed: _pickAndSendFile,
                    ),
                    
                    // Input TextField
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey[850] : Colors.grey[100],
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: TextField(
                          controller: _textController,
                          minLines: 1,
                          maxLines: 5,
                          decoration: const InputDecoration(
                            hintText: 'Message',
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),

                    // Send Floating Button
                    GestureDetector(
                      onTap: _sendMessage,
                      child: CircleAvatar(
                        radius: 22,
                        backgroundColor: theme.colorScheme.primary,
                        child: const Icon(
                          Icons.send,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
