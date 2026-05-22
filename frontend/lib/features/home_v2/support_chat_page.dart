import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../core/i18n.dart';
import '../../core/ui_tokens.dart';
import '../../models/support_models.dart';
import '../../services/auth_service.dart';

class SupportPage extends StatefulWidget {
  const SupportPage({
    super.key,
    required this.auth,
    required this.role,
  });

  final AuthService auth;
  final String role;

  @override
  State<SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends State<SupportPage> {
  static const _refreshInterval = Duration(seconds: 4);

  bool _loading = true;
  bool _refreshing = false;
  String? _error;
  List<_SupportDialog> _dialogs = const [];
  Timer? _refreshTimer;

  bool get _isClient => widget.role == 'client';

  @override
  void initState() {
    super.initState();
    if (_isClient) return;
    _loadDialogs(showLoader: true);
    _refreshTimer = Timer.periodic(
      _refreshInterval,
      (_) => _loadDialogs(showLoader: false),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadDialogs({required bool showLoader}) async {
    if (_refreshing) return;
    _refreshing = true;
    if (showLoader) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final messages = await widget.auth.fetchSupportMessages();
      if (!mounted) return;
      setState(() => _dialogs = _buildDialogs(messages));
    } catch (e) {
      if (!mounted) return;
      if (showLoader) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      _refreshing = false;
      if (mounted) setState(() => _loading = false);
    }
  }

  List<_SupportDialog> _buildDialogs(List<SupportMessage> messages) {
    final Map<String, List<SupportMessage>> grouped = {};
    for (final message in messages) {
      grouped.putIfAbsent(message.clientUserId, () => []);
      grouped[message.clientUserId]!.add(message);
    }

    final dialogs = <_SupportDialog>[];
    grouped.forEach((clientId, items) {
      final hasClientMessage =
          items.any((m) => m.senderRole.toLowerCase() == 'client');
      if (!hasClientMessage) return;
      items.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      final last = items.last;
      dialogs.add(
        _SupportDialog(
          clientUserId: clientId,
          clientFio: last.clientFio,
          lastMessage: last.messageText,
          lastAt: last.createdAt,
        ),
      );
    });

    dialogs.sort((a, b) => b.lastAt.compareTo(a.lastAt));
    return dialogs;
  }

  @override
  Widget build(BuildContext context) {
    if (_isClient) {
      return SupportThreadPage(
        auth: widget.auth,
        role: widget.role,
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(I18n.t('Поддержка', 'Поддержка', 'Support', tt: 'Ярдәм', ba: 'Ярҙам'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                )
              : _dialogs.isEmpty
                  ? Center(
                      child: Text(
                        I18n.t('Диалогов пока нет', 'Диалогъёс али ӧвӧл', 'No dialogs yet', tt: 'Әлегә диалоглар юк', ba: 'Әлегә диалогтар юҡ'),
                        style: TextStyle(color: UiTokens.muted(context)),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                      itemCount: _dialogs.length,
                      itemBuilder: (context, index) {
                        final dialog = _dialogs[index];
                        return InkWell(
                          onTap: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => SupportThreadPage(
                                  auth: widget.auth,
                                  role: widget.role,
                                  clientUserId: dialog.clientUserId,
                                  clientFio: dialog.clientFio,
                                ),
                              ),
                            );
                            if (mounted) {
                              _loadDialogs(showLoader: false);
                            }
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: UiTokens.card(context),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: UiTokens.cardShadow(context),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 22,
                                  backgroundColor: UiTokens.surface(context),
                                  child: Icon(Icons.person_outline,
                                      color: UiTokens.muted(context)),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        dialog.clientFio.isEmpty
                                            ? I18n.t('Клиент', 'Клиент', 'Client', tt: 'Клиент', ba: 'Клиент')
                                            : dialog.clientFio,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: UiTokens.foreground(context),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        dialog.lastMessage,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            color: UiTokens.muted(context)),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  _formatDate(dialog.lastAt),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: UiTokens.muted(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }

  String _formatDate(String value) {
    try {
      final dt = DateTime.parse(value).toLocal();
      return formatDateRu(dt.toIso8601String());
    } catch (_) {
      return value;
    }
  }
}

class SupportThreadPage extends StatefulWidget {
  const SupportThreadPage({
    super.key,
    required this.auth,
    required this.role,
    this.clientUserId,
    this.clientFio,
  });

  final AuthService auth;
  final String role;
  final String? clientUserId;
  final String? clientFio;

  @override
  State<SupportThreadPage> createState() => _SupportThreadPageState();
}

class _SupportThreadPageState extends State<SupportThreadPage> {
  static const _refreshInterval = Duration(seconds: 3);

  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  List<SupportMessage> _messages = const [];
  bool _loading = true;
  bool _refreshing = false;
  String? _error;
  Timer? _refreshTimer;

  bool get _isClient => widget.role == 'client';

  @override
  void initState() {
    super.initState();
    _loadMessages(showLoader: true);
    _refreshTimer = Timer.periodic(
      _refreshInterval,
      (_) => _loadMessages(showLoader: false),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages({required bool showLoader}) async {
    if (_refreshing) return;
    _refreshing = true;
    if (showLoader) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final items = await widget.auth
          .fetchSupportMessages(clientUserId: widget.clientUserId);
      if (!mounted) return;
      final hadNewMessages = !_sameMessages(_messages, items);
      if (hadNewMessages) {
        setState(() => _messages = items);
        _scrollToBottom();
      }
      if (!_isClient && widget.clientUserId != null && widget.clientUserId!.isNotEmpty) {
        await widget.auth.markSupportChatRead(widget.clientUserId!);
      }
    } catch (e) {
      if (!mounted) return;
      if (showLoader) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      _refreshing = false;
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _sameMessages(List<SupportMessage> a, List<SupportMessage> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i += 1) {
      if (a[i].id != b[i].id ||
          a[i].messageText != b[i].messageText ||
          a[i].isReadByAdmin != b[i].isReadByAdmin) {
        return false;
      }
    }
    return true;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    if (!_isClient && (widget.clientUserId == null || widget.clientUserId!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(I18n.t('Выберите клиента', 'Клиентез бырйы', 'Choose a client', tt: 'Клиентны сайлагыз', ba: 'Клиентты һайлағыҙ'))),
      );
      return;
    }
    try {
      final message = await widget.auth.sendSupportMessage(
        messageText: text,
        clientUserId: _isClient ? null : widget.clientUserId,
      );
      if (!mounted) return;
      setState(() {
        _messages = [..._messages, message];
        _messageController.clear();
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isClient
            ? I18n.t('Поддержка', 'Поддержка', 'Support', tt: 'Ярдәм', ba: 'Ярҙам')
            : (widget.clientFio ?? I18n.t('Поддержка', 'Поддержка', 'Support', tt: 'Ярдәм', ba: 'Ярҙам'))),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          final isMine = _isClient
                              ? message.senderRole == 'client'
                              : message.senderRole != 'client';
                          final bubbleColor = isMine
                              ? UiTokens.accent.withOpacity(0.15)
                              : UiTokens.card(context);
                          return Align(
                            alignment: isMine
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: bubbleColor,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                message.messageText,
                                style: TextStyle(
                                  color: UiTokens.foreground(context),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: I18n.t('Введите сообщение...', 'Гожтэт гожты...', 'Enter message...', tt: 'Хәбәр кертегез...', ba: 'Хәбәр яҙығыҙ...'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _sendMessage,
                    icon: const Icon(Icons.send),
                    color: UiTokens.accent,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SupportDialog {
  const _SupportDialog({
    required this.clientUserId,
    required this.clientFio,
    required this.lastMessage,
    required this.lastAt,
  });

  final String clientUserId;
  final String clientFio;
  final String lastMessage;
  final String lastAt;
}
