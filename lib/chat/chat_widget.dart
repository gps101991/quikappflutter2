import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter/gestures.dart';
import 'chat_message.dart';
import 'chat_service.dart';

class ChatWidget extends StatefulWidget {
  final InAppWebViewController webViewController;
  final String currentUrl;
  final Function(bool) onVisibilityChanged;

  const ChatWidget({
    super.key,
    required this.webViewController,
    required this.currentUrl,
    required this.onVisibilityChanged,
  });

  @override
  State<ChatWidget> createState() => _ChatWidgetState();
}

class _ChatWidgetState extends State<ChatWidget> {
  late final ChatService _chatService;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _chatService = ChatService(widget.currentUrl);
    _chatService.chatStream.listen((_) {
      _scrollToBottom();
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _chatService.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  Future<void> _handleSend() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _isLoading) return;

    _messageController.clear();
    setState(() => _isLoading = true);

    try {
      await _chatService.processUserMessage(message);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleLinkTap(String url) async {
    try {
      await widget.webViewController.loadUrl(
        urlRequest: URLRequest(url: WebUri(url))
      );
      if (mounted) {
        widget.onVisibilityChanged(false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading URL: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
        ),
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _buildChatList(),
            ),
            _buildInputArea(),
          ],
        ),
      ),
    );
  }
  String _getCleanHost(Uri uri) {
    final host = uri.host;
    return host.startsWith('www.') ? host.substring(4) : host;
  }
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          const Icon(Icons.chat, color: Colors.white),
          const SizedBox(width: 8),
           Expanded(
            child: Text(
              '${_getCleanHost(Uri.parse(widget.currentUrl))} Assistant',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white),
            onPressed: () async {
              await _chatService.clearHistory();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Chat history cleared')),
                );
              }
            },
            tooltip: 'Clear Chat',
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => widget.onVisibilityChanged(false),
            tooltip: 'Close Chat',
          ),
        ],
      ),
    );
  }

  Widget _buildChatList() {
    return StreamBuilder<List<ChatMessage>>(
      stream: _chatService.chatStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}'),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Text('No messages yet. Start a conversation!'),
          );
        }

        final messages = snapshot.data!;
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
        
        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final message = messages[index];
            return _buildMessageBubble(message);
          },
        );
      },
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isUser = message.isUser;
    final bubbleColor = isUser 
        ? Theme.of(context).primaryColor.withOpacity(0.1)
        : Colors.grey.shade100;
    final textColor = isUser
        ? Theme.of(context).primaryColor
        : Colors.black87;
    final alignment = isUser
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.7,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText.rich(
                  TextSpan(
                    children: _parseMessageText(message.text),
                  ),
                  style: TextStyle(
                    color: textColor,
                    fontSize: 16,
                  ),
                ),
                if (message.links != null && message.links!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ...message.links!.map((link) => 
                    TextButton(
                      onPressed: () => _handleLinkTap(link['url']!),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        alignment: Alignment.centerLeft,
                      ),
                      child: Text(
                        link['title'] ?? link['url']!,
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                ],
                if (message.links != null && message.links!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: message.links!.map((link) =>
                      ElevatedButton(
                        onPressed: () => _handleLinkTap(link['url']!),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                        ),
                        child: const Text('View More'),
                      ),
                    ).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<InlineSpan> _parseMessageText(String text) {
    final spans = <InlineSpan>[];
    final linkPattern = RegExp(r'\[(.*?)\]\((.*?)\)');
    final boldPattern = RegExp(r'\*\*(.*?)\*\*');
    
    var currentIndex = 0;
    
    while (currentIndex < text.length) {
      // Try to find the next markdown element
      final linkMatch = linkPattern.firstMatch(text.substring(currentIndex));
      final boldMatch = boldPattern.firstMatch(text.substring(currentIndex));
      
      // Find which comes first
      final linkStart = linkMatch?.start ?? text.length;
      final boldStart = boldMatch?.start ?? text.length;
      
      if (linkStart < boldStart) {
        // Add text before the link
        if (linkStart > 0) {
          spans.add(TextSpan(
            text: text.substring(currentIndex, currentIndex + linkStart),
          ));
        }
        
        // Add the link
        spans.add(TextSpan(
          text: linkMatch![1],
          style: TextStyle(
            color: Theme.of(context).primaryColor,
            decoration: TextDecoration.underline,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () => _handleLinkTap(linkMatch[2]!),
        ));
        
        currentIndex += linkMatch.end;
      } else if (boldStart < text.length) {
        // Add text before the bold
        if (boldStart > 0) {
          spans.add(TextSpan(
            text: text.substring(currentIndex, currentIndex + boldStart),
          ));
        }
        
        // Add the bold text
        spans.add(TextSpan(
          text: boldMatch![1],
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ));
        
        currentIndex += boldMatch.end;
      } else {
        // Add remaining text
        spans.add(TextSpan(
          text: text.substring(currentIndex),
        ));
        break;
      }
    }
    
    return spans;
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(16),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Type your message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              onSubmitted: (_) => _handleSend(),
            ),
          ),
          const SizedBox(width: 8),
          FloatingActionButton(
            onPressed: _isLoading ? null : _handleSend,
            mini: true,
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.send),
          ),
        ],
      ),
    );
  }
} 