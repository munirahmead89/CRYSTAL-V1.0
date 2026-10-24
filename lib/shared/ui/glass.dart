import 'dart:ui';

import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../models/chat_message.dart';

/// Translucent surface treatment.
///
/// ## Why real blur and not just alpha
///
/// An alpha-only "glass" panel looks like a grey rectangle: it has no depth cue,
/// so the eye reads it as a flat fill rather than a pane of glass sitting above
/// the content. [BackdropFilter] samples what is actually behind the widget,
/// which is what sells the material. On a chat list, where rows move over
/// another row, the blur is legible as motion behind the surface.
///
/// ## Why it is kept to specific places
///
/// Frosted glass everywhere is the failure mode, not the goal. Blur is
/// expensive - a full-width backdrop filter repaints everything behind it on
/// every frame the background changes - and a screen made entirely of blur is
/// unreadable and slow. So glass is used for surfaces that genuinely float:
/// the app bar, sheets, the composer, the media viewer chrome. Message bubbles
/// stay solid, because text has to be readable over arbitrary media.
///
/// ## Cost control
///
/// Every glass surface sets [BackdropFilter.blurSigma] modestly and, more
/// importantly, keeps its blur subtree small. A chat bubble is never glass; a
/// composer's composer bar is.
abstract final class Glass {
  /// Blur sigma for large surfaces (app bar, sheets).
  static const double blurLarge = 24;

  /// Blur sigma for small surfaces (chips, pills, controls).
  static const double blurSmall = 12;

  static const double radiusLarge = 24;
  static const double radiusMedium = 18;
  static const double radiusSmall = 12;

  /// Tint used on top of the blur.
  ///
  /// Dark in dark mode, light in light mode, both derived from the theme's
  /// own surface colour so glass stays consistent when the theme changes.
  static Color tint(BuildContext context, {double opacity = 0.55}) {
    final scheme = Theme.of(context).colorScheme;
    final base = scheme.brightness == Brightness.dark
        ? CrystalColors.black
        : CrystalColors.white;
    return base.withValues(alpha: opacity);
  }
}

/// A frosted panel.
///
/// The workhorse of the visual language: any floating surface - app bar, sheet,
/// composer, panel - is a [GlassSurface] so the treatment is identical
/// everywhere rather than re-tuned per screen.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.blur = Glass.blurLarge,
    this.opacity = 0.55,
    this.radius = Glass.radiusLarge,
    this.border = true,
    this.tint,
    this.clip = true,
  });

  final Widget child;

  /// Backdrop blur sigma. Lower means sharper, which reads more like a tinted
  /// pane; higher reads more like frosted glass.
  final double blur;

  /// Alpha of the tint laid over the blurred backdrop.
  final double opacity;

  final double radius;

  /// A 1px light edge. This is what actually sells "glass": a soft border
  /// catches the light and separates the pane from what is behind it.
  final bool border;

  final Color? tint;

  final bool clip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final resolvedTint = tint ?? Glass.tint(context, opacity: opacity);
    final borderColor = scheme.brightness == Brightness.dark
        ? CrystalColors.white12
        : CrystalColors.black12;

    Widget surface = DecoratedBox(
      decoration: BoxDecoration(
        color: resolvedTint,
        borderRadius: BorderRadius.circular(radius),
        border: border ? Border.all(color: borderColor, width: 1) : null,
      ),
      child: child,
    );

    if (clip) {
      surface = ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: surface,
      );
    }

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
      child: surface,
    );
  }
}

/// A glass panel with padding, for cards and grouped settings.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = Glass.radiusMedium,
    this.opacity = 0.5,
    this.blur = Glass.blurLarge,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double opacity;
  final double blur;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      blur: blur,
      opacity: opacity,
      radius: radius,
      child: Padding(padding: padding, child: child),
    );
  }
}

/// A glass pill, used for chips, badges and the transfers indicator.
class GlassPill extends StatelessWidget {
  const GlassPill({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      blur: Glass.blurSmall,
      opacity: 0.6,
      radius: 999,
      child: Padding(padding: padding, child: child),
    );
  }
}

/// Frosted top app bar.
///
/// The app bar is the single most important glass surface: it is always
/// floating above scrolling content, so the blur is doing real work there and
/// nowhere else.
class GlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  const GlassAppBar({
    super.key,
    this.title,
    this.titleWidget,
    this.actions,
    this.leading,
    this.bottom,
    this.showBack = true,
    this.titleSpacing,
  });

  final String? title;

  /// Used instead of [title] for a compound header (avatar + name + presence).
  /// Exactly one of the two is expected; [title] takes precedence when both are
  /// given so a caller cannot accidentally render two titles.
  final Widget? titleWidget;
  final List<Widget>? actions;
  final Widget? leading;
  final PreferredSizeWidget? bottom;
  final bool showBack;
  final double? titleSpacing;

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: Glass.blurLarge,
          sigmaY: Glass.blurLarge,
        ),
        child: Container(
          decoration: BoxDecoration(
            // Very low opacity: the blur does the work, and a heavy tint here
            // would darken the top of every scrolling list.
            color: Glass.tint(context, opacity: 0.42),
            border: Border(
              bottom: BorderSide(
                color: theme.colorScheme.brightness == Brightness.dark
                    ? CrystalColors.white12
                    : CrystalColors.black12,
                width: 1,
              ),
            ),
          ),
          child: AppBar(
            title: titleWidget ?? (title == null ? null : Text(title!)),
            actions: actions,
            leading: leading,
            titleSpacing: titleSpacing,
            automaticallyImplyLeading: showBack,
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            bottom: bottom,
          ),
        ),
      ),
    );
  }
}

/// Message bubble.
///
/// Deliberately NOT glass. A bubble sits directly on top of whatever is behind
/// it, including a photo or a video thumbnail; frosting it would blur the media
/// and cut text contrast, which is a legibility problem, not a style one. The
/// brand colour is used at full opacity so the transcript stays scannable, with
/// the only soft treatment on the outgoing side where it sits over the user's
/// own wallpaper.
///
/// The scale of the radius is what makes it read as a message rather than a
/// rectangle, and it is asymmetric on purpose: the corner nearest the previous
/// bubble stays large so consecutive messages visually group.
class CrystalBubble extends StatelessWidget {
  const CrystalBubble({
    super.key,
    required this.outgoing,
    required this.child,
    this.isFailed = false,
    this.tail = true,
    this.hasAttachment = false,
  });

  final bool outgoing;
  final Widget child;
  final bool isFailed;

  /// False for a bubble that continues a run, which squares off the inner
  /// corners.
  final bool tail;

  /// Attachment bubbles hug their media, so they get a tighter radius.
  final bool hasAttachment;

  static const double radius = 18;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final background = isFailed
        ? scheme.errorContainer
        : outgoing
        ? scheme.primary
        : scheme.surfaceContainerHighest;

    // Asymmetric on purpose: the corner nearest the previous bubble stays large
    // so consecutive messages visually group into a run. An attachment hugs its
    // media, so it is rounded evenly instead.
    final corners = hasAttachment
        ? BorderRadius.circular(radius)
        : BorderRadius.only(
            topLeft: const Radius.circular(radius),
            topRight: Radius.circular(tail ? 4 : radius),
            bottomLeft: Radius.circular(
              outgoing ? (tail ? 4 : radius) : radius,
            ),
            bottomRight: Radius.circular(radius),
          );

    return Container(
      decoration: BoxDecoration(
        color: background,
        borderRadius: corners,
        border: isFailed ? Border.all(color: scheme.error) : null,
        // A soft drop shadow gives the bubble lift off the background without
        // the hard edge a border would give.
        boxShadow: outgoing
            ? [
                BoxShadow(
                  color: CrystalColors.black.withValues(alpha: 0.18),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: child,
    );
  }
}

/// Scrim behind the full-screen viewer.
///
/// Darkened far enough that media, including a white screenshot, is the only
/// thing drawing attention, but kept as a flat colour rather than a blur:
/// blurring the whole screen behind a full-bleed image does nothing but cost
/// frames.
class ViewerScrim extends StatelessWidget {
  const ViewerScrim({super.key, required this.child, this.opacity = 0.94});

  final Widget child;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: CrystalColors.black.withValues(alpha: opacity),
      child: child,
    );
  }
}

/// A message-bubble-shaped backdrop for a viewer control.
///
/// Keeps the chrome legible over arbitrary media without the viewer having to
/// know what is behind it.
class ViewerChromePill extends StatelessWidget {
  const ViewerChromePill({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      blur: Glass.blurSmall,
      opacity: 0.45,
      radius: 999,
      child: Padding(padding: padding, child: child),
    );
  }
}

/// Resolves the text colour that is legible on top of a [CrystalBubble].
Color onBubbleColor(
  BuildContext context,
  bool outgoing, {
  bool failed = false,
}) {
  final scheme = Theme.of(context).colorScheme;
  if (failed) return scheme.onErrorContainer;
  return outgoing ? scheme.onPrimary : scheme.onSurface;
}

/// Convenience for the "what kind of message is this" label used by the reply
/// quote, the forward banner and the notification body.
String describeAttachment(String type) => switch (type) {
  'image' => '📷 Photo',
  'video' => '🎥 Video',
  'voice' => '🎤 Voice note',
  'file' => '📎 File',
  _ => 'Attachment',
};

/// True when [message] has something worth rendering as media rather than text.
bool hasRenderableMedia(ChatMessage message) =>
    message.attachment != null &&
    (message.type == 'image' ||
        message.type == 'video' ||
        message.type == 'voice');
