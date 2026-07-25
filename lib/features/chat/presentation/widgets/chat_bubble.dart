import 'package:flutter/material.dart';
import '../../../../core/services/database/schemas/message.dart';
import '../../../../core/theme/app_theme.dart';
import 'package:intl/intl.dart';

class ChatBubble extends StatelessWidget {
  final Message message;
  final bool isMe;
  final String? replyToText;
  final VoidCallback? onLongPress;

  const ChatBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.replyToText,
    this.onLongPress,
  });

  Widget _buildStatusIcon(BuildContext context) {
    if (message.isRead) {
      return const Icon(Icons.done_all, size: 16, color: Colors.blue);
    }
    if (message.isDelivered) {
      return const Icon(Icons.done_all, size: 16, color: Colors.grey);
    }
    if (message.isSent) {
      return const Icon(Icons.done, size: 16, color: Colors.grey);
    }
    return const Icon(Icons.access_time, size: 14, color: Colors.grey);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final Color bg = isMe
        ? (isDark ? AppTheme.bubbleSentDark : AppTheme.bubbleSentLight)
        : (isDark ? AppTheme.bubbleReceivedDark : AppTheme.bubbleReceivedLight);

    final Color fg = isDark ? Colors.white : Colors.black87;
    final timeStr = DateFormat('jm').format(message.timestamp);

    return InkWell(
      onLongPress: onLongPress,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
        child: Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Column(
            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              // Bubble content container
              Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isMe ? 16 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 16),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    )
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Reply block if present
                    if (replyToText != null)
                      Container(
                        margin: const EdgeInsets.bottom(6),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(8),
                          border: Border(
                            left: BorderSide(
                              color: theme.colorScheme.primary,
                              width: 4,
                            ),
                          ),
                        ),
                        child: Text(
                          replyToText!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey[300] : Colors.grey[700],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),

                    // Media image if exists
                    if (message.mediaPath != null)
                      Container(
                        margin: const EdgeInsets.bottom(6),
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: message.mediaType == 'image'
                            ? Image.network(
                                message.mediaPath!,
                                errorBuilder: (_, __, ___) => Container(
                                  padding: const EdgeInsets.all(12),
                                  color: Colors.grey[350],
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.image_not_supported, color: Colors.grey),
                                      const SizedBox(width: 8),
                                      Text('Media unavailable', style: TextStyle(color: Colors.grey[700])),
                                    ],
                                  ),
                                ),
                              )
                            : Container(
                                padding: const EdgeInsets.all(16),
                                color: Colors.black.withOpacity(0.1),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.attach_file, color: Colors.blue),
                                    const SizedBox(width: 8),
                                    Text(
                                      message.mediaPath!.split('/').last,
                                      style: TextStyle(color: fg),
                                    ),
                                  ],
                                ),
                              ),
                      ),

                    // Text Content
                    if (message.text.isNotEmpty)
                      Text(
                        message.text,
                        style: TextStyle(
                          fontSize: 16,
                          color: fg,
                        ),
                      ),
                    
                    const SizedBox(height: 4),

                    // Timestamp and checkmarks row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          timeStr,
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark ? Colors.white60 : Colors.black45,
                          ),
                        ),
                        if (isMe) ...[
                          const SizedBox(width: 4),
                          _buildStatusIcon(context),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Reactions overlay row
              if (message.reactions != null && message.reactions!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2, left: 6, right: 6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[800] : Colors.grey[200],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark ? Colors.grey[750]! : Colors.white,
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      message.reactions!,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
