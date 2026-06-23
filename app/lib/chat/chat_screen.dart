import 'package:flutter/material.dart';

import 'chat_controller.dart';
import 'models.dart';
import 'noa_room.dart';

/// 노아의 방 (Direction 01) 채팅 화면.
/// 상단: 노아가 돌아다니는 방 무대(대화 시작 시 슬림 헤더로 줄어듦).
/// 하단: 딸기우유 톤 말풍선 채팅(둥근 시트로 방과 자연스럽게 연결).
/// 데스크톱(웹)에서는 폰 폭(max 480)으로 가운데 정렬.
class ChatScreen extends StatefulWidget {
  final ChatController controller;
  const ChatScreen({super.key, required this.controller});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _inputFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChange);
    // 입력창 포커스 = "노아야 봐줘" → 보내기 전에 이미 쳐다봄.
    _inputFocus.addListener(() {
      if (_inputFocus.hasFocus) widget.controller.lookAtMe();
    });
    // 진입하면 노아가 먼저 한마디.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.openingGreeting();
    });
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
    _inputFocus.dispose();
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
    final size = MediaQuery.of(context).size;
    final bigH = (size.height * 0.46).clamp(300.0, 430.0);
    final slimH = (size.height * 0.26).clamp(190.0, 250.0);

    return Scaffold(
      backgroundColor: const Color(0xFF241B2E),
      resizeToAvoidBottomInset: true,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            children: [
              // ── 노아의 방 (collapsing) ──
              SafeArea(
                bottom: false,
                child: ListenableBuilder(
                  listenable: c,
                  builder: (_, __) {
                    // 사용자가 말 걸기 전까지는 큰 방(첫인상). 첫 대화 후 슬림 헤더로.
                    final engaged = c.messages.any((m) => m.isMe);
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 420),
                      curve: Curves.easeOutCubic,
                      height: engaged ? slimH : bigH,
                      width: double.infinity,
                      child: NoaRoom(controller: c),
                    );
                  },
                ),
              ),
              // ── 대화 (둥근 시트로 방과 연결) ──
              Expanded(
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFFBE6DC), Color(0xFFFFFBF9)],
                      stops: [0.0, 0.22],
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(22),
                      topRight: Radius.circular(22),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x1FBE5A5A),
                        blurRadius: 18,
                        offset: Offset(0, -6),
                      ),
                    ],
                  ),
                  child: ListenableBuilder(
                    listenable: c,
                    builder: (_, __) {
                      if (c.messages.isEmpty && !c.typing) {
                        return const _EmptyState();
                      }
                      final count = c.messages.length + (c.typing ? 1 : 0);
                      return ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
                        itemCount: count,
                        itemBuilder: (_, i) {
                          if (i >= c.messages.length) {
                            return const _TypingBubble();
                          }
                          return _MessageRow(msg: c.messages[i]);
                        },
                      );
                    },
                  ),
                ),
              ),
              _InputBar(
                controller: _input,
                focusNode: _inputFocus,
                onSend: _send,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Text(
          '노아가 방을 어슬렁거려요.\n방을 톡 누르거나, 먼저 말 걸어보세요.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13.5,
            height: 1.5,
            color: Color(0xFFB98A8A),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _MessageRow extends StatelessWidget {
  final ChatMessage msg;
  const _MessageRow({required this.msg});

  @override
  Widget build(BuildContext context) {
    final isMe = msg.isMe;
    final bubble = _Bouncy(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFFE2474F) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMe ? 18 : 6),
            bottomRight: Radius.circular(isMe ? 6 : 18),
          ),
          boxShadow: isMe
              ? null
              : const [
                  BoxShadow(
                    color: Color(0x1FC95A5A),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
        ),
        child: Text(
          msg.text,
          style: TextStyle(
            fontSize: 15,
            height: 1.34,
            color: isMe ? Colors.white : const Color(0xFF5B2333),
            fontWeight: isMe ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );

    if (isMe) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!msg.read)
            const Padding(
              padding: EdgeInsets.only(right: 5, bottom: 7),
              child: Text(
                '1',
                style: TextStyle(
                  color: Color(0xFFE2474F),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          Flexible(child: bubble),
        ],
      );
    }

    return Row(children: [Flexible(child: bubble)]);
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
  late final AnimationController _a = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(6),
              bottomRight: Radius.circular(18),
            ),
            boxShadow: [
              BoxShadow(
                color: Color(0x1FC95A5A),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: AnimatedBuilder(
            animation: _a,
            builder: (_, __) => Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                final v = (((_a.value + i / 3) % 1.0) - 0.5).abs() * 2;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color.lerp(
                      const Color(0xFFF0B5BC),
                      const Color(0xFFE2474F),
                      1 - v,
                    ),
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
  final FocusNode focusNode;
  final VoidCallback onSend;
  const _InputBar({
    required this.controller,
    required this.focusNode,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x14BE5A5A),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSend(),
                  style: const TextStyle(color: Color(0xFF5B2333)),
                  decoration: InputDecoration(
                    hintText: '노아한테 말 걸기',
                    hintStyle: const TextStyle(color: Color(0xFFCAA3A3)),
                    filled: true,
                    fillColor: const Color(0xFFF6ECE8),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 11,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _SendButton(onTap: onSend),
            ],
          ),
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
            color: Color(0xFFE2474F),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.favorite_rounded,
            size: 20,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
