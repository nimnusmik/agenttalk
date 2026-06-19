import 'package:flutter/material.dart';

import 'chat_controller.dart';
import 'models.dart';

/// 카톡 느낌 채팅 화면: 말풍선 + 입력중 + 읽음 + 통통 튀는 마이크로인터랙션.
/// 상단에 현재 감정/무드를 표기해 LLM→감정 흐름을 눈으로 확인(스프라이트 전 임시).
class ChatScreen extends StatefulWidget {
  final ChatController controller;
  const ChatScreen({super.key, required this.controller});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChange);
  }

  void _onChange() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChange);
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send() {
    final t = _input.text;
    _input.clear();
    widget.controller.send(t);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return Scaffold(
      backgroundColor: const Color(0xFFB2C7DA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFB2C7DA),
        elevation: 0,
        titleSpacing: 0,
        title: ListenableBuilder(
          listenable: c,
          builder: (_, __) => Row(
            children: [
              const CircleAvatar(
                backgroundColor: Colors.white,
                child: Text('🍓'),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('노아',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                  Text(
                    '${c.avatarEmotion.name} · mood ${c.moodScore}',
                    style: const TextStyle(fontSize: 11, color: Colors.black54),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListenableBuilder(
              listenable: c,
              builder: (_, __) {
                final count = c.messages.length + (c.typing ? 1 : 0);
                return ListView.builder(
                  controller: _scroll,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  itemCount: count,
                  itemBuilder: (_, i) {
                    if (i >= c.messages.length) return const _TypingBubble();
                    final msg = c.messages[i];
                    final groupStart = i == 0 ||
                        c.messages[i - 1].sender != msg.sender;
                    return _MessageRow(msg: msg, showAvatar: groupStart);
                  },
                );
              },
            ),
          ),
          _InputBar(controller: _input, onSend: _send),
        ],
      ),
    );
  }
}

class _MessageRow extends StatelessWidget {
  final ChatMessage msg;
  final bool showAvatar;
  const _MessageRow({required this.msg, required this.showAvatar});

  @override
  Widget build(BuildContext context) {
    final isMe = msg.isMe;
    final bubble = _Bouncy(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 260),
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFFFEE500) : Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(msg.text, style: const TextStyle(fontSize: 15, height: 1.3)),
      ),
    );

    if (isMe) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!msg.read)
            const Padding(
              padding: EdgeInsets.only(right: 4, bottom: 6),
              child: Text('1',
                  style: TextStyle(
                      color: Color(0xFFF9D71C),
                      fontSize: 11,
                      fontWeight: FontWeight.bold)),
            ),
          bubble,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 42,
          child: showAvatar
              ? const CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.white,
                  child: Text('🍓', style: TextStyle(fontSize: 16)),
                )
              : null,
        ),
        Flexible(child: bubble),
      ],
    );
  }
}

/// 스프링 오버슈트로 톡! 튀어 들어오는 등장 (통통).
class _Bouncy extends StatelessWidget {
  final Widget child;
  const _Bouncy({required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutBack,
      child: child,
      builder: (_, t, child) => Transform.scale(
        scale: 0.85 + 0.15 * t,
        alignment: Alignment.bottomCenter,
        child: Opacity(opacity: t.clamp(0.0, 1.0), child: child),
      ),
    );
  }
}

class _TypingBubble extends StatefulWidget {
  const _TypingBubble();
  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _a =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
        ..repeat();

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(
          width: 42,
          child: CircleAvatar(
            radius: 16,
            backgroundColor: Colors.white,
            child: Text('🍓', style: TextStyle(fontSize: 16)),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: AnimatedBuilder(
            animation: _a,
            builder: (_, __) => Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                final v = (((_a.value + i / 3) % 1.0) - 0.5).abs() * 2; // 0..1
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color.lerp(Colors.black26, Colors.black54, 1 - v),
                  ),
                );
              }),
            ),
          ),
        ),
      ],
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  const _InputBar({required this.controller, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: '메시지 입력',
                  filled: true,
                  fillColor: const Color(0xFFF1F1F1),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            _SendButton(onTap: onSend),
          ],
        ),
      ),
    );
  }
}

/// 누르면 말랑 눌렸다 스프링으로 복귀 (squash).
class _SendButton extends StatefulWidget {
  final VoidCallback onTap;
  const _SendButton({required this.onTap});
  @override
  State<_SendButton> createState() => _SendButtonState();
}

class _SendButtonState extends State<_SendButton> {
  double _scale = 1;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.82),
      onTapUp: (_) {
        setState(() => _scale = 1);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _scale = 1),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 90),
        child: Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(
            color: Color(0xFFFEE500),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.send_rounded, size: 20, color: Colors.black87),
        ),
      ),
    );
  }
}
