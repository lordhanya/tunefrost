import 'package:flutter/material.dart';

import 'package:music_player/features/playback/now_playing_screen.dart';

/// iOS-style modal-card presentation: the incoming route slides up from the
/// bottom while the route beneath it scales back and dims — the same feel
/// as Apple Music's now-playing sheet.
class CardPageRoute<T> extends PageRouteBuilder<T> {
  CardPageRoute({required Widget page})
    : super(
        transitionDuration: const Duration(milliseconds: 420),
        reverseTransitionDuration: const Duration(milliseconds: 360),
        opaque: false,
        barrierColor: Colors.black26,
        pageBuilder: (_, _, _) => page,
        transitionsBuilder: (_, animation, secondary, child) {
          // Own push/pop: slide up from the bottom edge.
          final push = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          // A route above is covering us: scale back + round + let the
          // barrier scrim show through.
          final covered = CurvedAnimation(
            parent: secondary,
            curve: Curves.easeOutCubic,
          );

          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(push),
            child: Transform.scale(
              scale: 1 - 0.06 * covered.value,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18 * covered.value),
                child: child,
              ),
            ),
          );
        },
      );
}

/// Opens Now Playing with the card presentation.
void openNowPlaying(BuildContext context) {
  Navigator.of(context).push(CardPageRoute(page: const NowPlayingScreen()));
}
