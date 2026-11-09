import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:jamiat/src/data/apis/event_api.dart';
import 'package:jamiat/src/data/apis/user_api.dart';
import 'package:jamiat/src/data/constants/color_constants.dart';
import 'package:jamiat/src/data/constants/style_constants.dart';
import 'package:jamiat/src/data/models/event_model.dart';
import 'package:jamiat/src/data/providers/event_provider.dart';
import 'package:jamiat/src/data/services/event_share_service.dart';
import 'package:jamiat/src/data/services/haptic_helper.dart';
import 'package:jamiat/src/data/services/navigation_services.dart';
import 'package:jamiat/src/data/utils/format_helpers.dart';
import 'package:jamiat/src/interfaces/components/async_content.dart';
import 'package:jamiat/src/interfaces/events/event_card.dart';
import 'package:url_launcher/url_launcher.dart';

class EventDetailsScreen extends ConsumerStatefulWidget {
  final String? eventId;
  final String title;
  final String date;
  final String location;
  final String image;
  final bool isBookmarked;

  const EventDetailsScreen({
    super.key,
    this.eventId,
    this.title = 'Event Details',
    this.date = '',
    this.location = '',
    this.image = 'assets/jpgs/campaign_education.jpg',
    this.isBookmarked = false,
  });

  @override
  ConsumerState<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends ConsumerState<EventDetailsScreen> {
  bool _bookmarkLoading = false;
  bool _registerLoading = false;
  bool _shareLoading = false;

  Future<void> _shareEvent(String eventId, String title) async {
    if (_shareLoading) return;
    setState(() => _shareLoading = true);
    try {
      HapticHelper.impact(HapticImpact.light);
      await ref.read(eventShareServiceProvider).shareEvent(
            context: context,
            eventId: eventId,
            title: title,
          );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _shareLoading = false);
    }
  }

  Widget _headerCircleButton({
    required Widget child,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: kWhite,
          border: Border.all(color: kGrey, width: 1.25),
        ),
        alignment: Alignment.center,
        child: child,
      ),
    );
  }

  Future<void> _toggleBookmark(EventModel event) async {
    if (_bookmarkLoading) return;
    setState(() => _bookmarkLoading = true);
    try {
      final api = ref.read(eventApiProvider);
      final res = event.isBookmarked
          ? await api.removeBookmark(event.id)
          : await api.bookmarkEvent(event.id);
      if (!mounted) return;
      if (!res.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res.message ?? 'Bookmark failed')),
        );
        return;
      }
      ref.invalidate(eventDetailProvider(event.id));
      ref.invalidate(savedEventsProvider);
      ref.invalidate(eventsListProvider);
    } finally {
      if (mounted) setState(() => _bookmarkLoading = false);
    }
  }

  BuildContext get _dialogContext =>
      NavigationService.navigatorKey.currentContext ?? context;

  Future<bool> _confirmRegistration(EventModel event) async {
    final confirmed = await showDialog<bool>(
      context: _dialogContext,
      useRootNavigator: true,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Register for event?'),
        content: Text('Do you want to register for "${event.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Register'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  /// Success confirmation for both online and offline registrations.
  Future<void> _showRegistrationConfirmation({
    required EventModel event,
    String? message,
    String? ticketId,
  }) {
    final hasTicket = ticketId != null && ticketId.isNotEmpty;

    return showDialog<void>(
      context: _dialogContext,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Registration Confirmed'),
        content: Text(
          message?.trim().isNotEmpty == true
              ? message!.trim()
              : 'You have successfully registered for ${event.title}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('OK'),
          ),
          if (hasTicket)
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                NavigationService().pushNamed(
                  'EventTicket',
                  arguments: {'ticketId': ticketId},
                );
              },
              child: const Text('View Ticket'),
            ),
        ],
      ),
    );
  }

  Future<void> _registerOrViewTicket(EventModel event) async {
    if (event.isRegistered == true) {
      // Online events have no tickets — show registration confirmation.
      if (event.isOnline) {
        await _showRegistrationConfirmation(event: event);
        return;
      }

      final ticketId = event.myTicketId;
      if (ticketId != null && ticketId.isNotEmpty) {
        NavigationService().pushNamed(
          'EventTicket',
          arguments: {'ticketId': ticketId},
        );
      } else {
        NavigationService().pushNamed('MyTickets');
      }
      return;
    }

    if (event.isFinished) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This event has ended')),
      );
      return;
    }

    if (_registerLoading) return;

    final confirmed = await _confirmRegistration(event);
    if (!confirmed || !mounted) return;

    setState(() => _registerLoading = true);
    try {
      final res = await ref.read(eventApiProvider).registerForEvent(event.id);
      if (!mounted) return;
      if (!res.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res.message ?? 'Registration failed')),
        );
        return;
      }

      final ticketId = res.data?.id;
      // Always show confirmation for online and offline registrations.
      await _showRegistrationConfirmation(
        event: event,
        message: res.message,
        ticketId: event.isOnline ? null : ticketId,
      );

      if (!mounted) return;
      ref.invalidate(eventDetailProvider(event.id));
      ref.invalidate(myTicketsProvider('upcoming'));
      ref.invalidate(myTicketsProvider('past'));
      ref.invalidate(eventsListProvider);
    } finally {
      if (mounted) setState(() => _registerLoading = false);
    }
  }

  String? _resolvePersonImageUrl(String? raw) {
    final imageUrl = raw?.trim();
    if (imageUrl == null || imageUrl.isEmpty) return null;
    if (imageUrl.startsWith('//')) return 'https:$imageUrl';
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      return imageUrl;
    }
    return null;
  }

  Widget _personAvatar(String? rawUrl, {double size = 40, double radius = 4}) {
    final url = _resolvePersonImageUrl(rawUrl);

    Widget placeholder() => Container(
      width: size,
      height: size,
      color: kScreenBg,
      alignment: Alignment.center,
      child: Icon(Icons.person_outline, color: kMutedText, size: size * 0.5),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: url == null
          ? placeholder()
          : Image.network(
              url,
              width: size,
              height: size,
              fit: BoxFit.cover,
              alignment: Alignment.center,
              filterQuality: FilterQuality.medium,
              cacheWidth: (size * 3).round(),
              cacheHeight: (size * 3).round(),
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return Container(
                  width: size,
                  height: size,
                  color: kScreenBg,
                  alignment: Alignment.center,
                  child: const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              },
              errorBuilder: (_, _, _) => placeholder(),
            ),
    );
  }

  Widget _speakerTile(EventPerson person) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          _personAvatar(person.image),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              person.name,
              style: kCaption12R.copyWith(color: kTextColor),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  bool _looksLikeUrl(String value) {
    final trimmed = value.trim().toLowerCase();
    return trimmed.startsWith('http://') ||
        trimmed.startsWith('https://') ||
        trimmed.startsWith('www.') ||
        trimmed.startsWith('maps.google.') ||
        trimmed.startsWith('meet.google.') ||
        trimmed.startsWith('goo.gl/') ||
        trimmed.startsWith('bit.ly/');
  }

  Uri? _parseExternalUri(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    final withScheme = _looksLikeUrl(trimmed) &&
            !trimmed.toLowerCase().startsWith('http://') &&
            !trimmed.toLowerCase().startsWith('https://')
        ? 'https://$trimmed'
        : trimmed;

    final uri = Uri.tryParse(withScheme);
    if (uri == null || !(uri.hasScheme && uri.host.isNotEmpty)) return null;
    return uri;
  }

  Uri? _locationUri(EventModel event) {
    final isOnline = event.type.toLowerCase() == 'online';

    // Offline events store the maps/location URL in `link` (onlineLink).
    if (!isOnline) {
      final link = event.onlineLink?.trim();
      if (link != null && link.isNotEmpty) {
        final fromLink = _parseExternalUri(link);
        if (fromLink != null) return fromLink;
      }
    }

    final venue = event.venue?.trim();
    if (venue == null || venue.isEmpty) return null;

    if (_looksLikeUrl(venue)) {
      return _parseExternalUri(venue);
    }

    return Uri.https(
      'www.google.com',
      '/maps/search/',
      <String, String>{'api': '1', 'query': venue},
    );
  }

  Future<void> _launchUri(Uri? uri, {String errorMessage = 'Unable to open link'}) async {
    if (uri == null) return;

    HapticHelper.impact(HapticImpact.light);
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    }
  }

  Future<void> _openExternalLink(String? rawUrl) =>
      _launchUri(_parseExternalUri(rawUrl ?? ''));

  Future<void> _openLocationLink(EventModel event) =>
      _launchUri(_locationUri(event), errorMessage: 'Unable to open location');


  Widget _metaRow({
    required IconData icon,
    required String text,
    VoidCallback? onTap,
  }) {
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 16, color: kTextColor),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            style: kCaption12R.copyWith(
              color: onTap != null ? kPrimaryColor : kTextColor,
              decoration: onTap != null ? TextDecoration.underline : null,
              decorationColor: onTap != null ? kPrimaryColor : null,
            ),
          ),
        ),
      ],
    );

    if (onTap == null) return row;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: row,
    );
  }

  Widget _organizersRow(EventModel event) {
    final named = event.coordinators.where((p) => p.name.isNotEmpty).toList();
    final organizer = named.isNotEmpty ? named.first : null;
    final name = organizer?.name ?? 'Jamiat Welfare Committee';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          _personAvatar(organizer?.image, radius: 4),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ORGANIZERS',
                  style: kCaption10SB.copyWith(
                    color: kSecondaryTextColor,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  name,
                  style: kCaption12R.copyWith(color: kTextColor),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(EventModel event) {
    final dateTimeLabel = formatEventDateTimeRange(
      event.startDate,
      event.endDate,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        kScreenPaddingH,
        0,
        kScreenPaddingH,
        24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 370 / 203,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(kCardRadiusMd),
              child: eventCoverImage(event.coverImage),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            event.title,
            style: kLabel19SB,
          ),
          const SizedBox(height: 16),
          if (dateTimeLabel.isNotEmpty) ...[
            _metaRow(
              icon: Icons.calendar_today_outlined,
              text: dateTimeLabel,
            ),
          ],
          if (event.venue != null && event.venue!.isNotEmpty) ...[
            const SizedBox(height: 8),
            _metaRow(
              icon: Icons.location_on_outlined,
              text: event.venue!,
              onTap: _locationUri(event) != null
                  ? () => _openLocationLink(event)
                  : null,
            ),
          ] else if (event.type.toLowerCase() != 'online' &&
              event.onlineLink != null &&
              event.onlineLink!.isNotEmpty) ...[
            // Offline events may only have a maps/location link.
            const SizedBox(height: 8),
            _metaRow(
              icon: Icons.location_on_outlined,
              text: event.onlineLink!,
              onTap: () => _openExternalLink(event.onlineLink),
            ),
          ],
          // Meeting link is only for registered attendees (not public).
          if (event.type.toLowerCase() == 'online' &&
              event.isRegistered == true &&
              event.onlineLink != null &&
              event.onlineLink!.isNotEmpty) ...[
            const SizedBox(height: 8),
            _metaRow(
              icon: Icons.link,
              text: event.onlineLink!,
              onTap: () => _openExternalLink(event.onlineLink),
            ),
          ],
          const SizedBox(height: 8),
          _organizersRow(event),
          const SizedBox(height: 8),
          Text('About Event', style: kSectionTitleSB),
          const SizedBox(height: 8),
          Text(
            event.description,
            style: kCaption12R.copyWith(color: kTextColor, height: 1.4),
          ),
          if (event.guests.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Speakers', style: kSectionTitleSB),
            const SizedBox(height: 8),
            ...event.guests.map(_speakerTile),
          ],
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _fallbackBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: kScreenPaddingH),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 370 / 203,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(kCardRadiusMd),
              child: eventCoverImage(widget.image),
            ),
          ),
          const SizedBox(height: 16),
          Text(widget.title, style: kLabel19SB),
          const SizedBox(height: 16),
          if (widget.date.isNotEmpty)
            _metaRow(
              icon: Icons.calendar_today_outlined,
              text: widget.date,
            ),
          if (widget.location.isNotEmpty) ...[
            const SizedBox(height: 8),
            _metaRow(
              icon: Icons.location_on_outlined,
              text: widget.location,
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasId = widget.eventId != null && widget.eventId!.isNotEmpty;
    final eventAsync = hasId
        ? ref.watch(eventDetailProvider(widget.eventId!))
        : null;
    final event = eventAsync?.value;
    final isBookmarked = event?.isBookmarked ?? widget.isBookmarked;
    final currentUserId = ref.watch(userProfileProvider).maybeWhen(
      data: (user) => user.id,
      orElse: () => null,
    );
    final isCoordinator =
        event != null && event.isCoordinator(currentUserId);
    final isCompleted = event?.isFinished == true;
    final isRegistered = event?.isRegistered == true;
    final isOnline = event?.isOnline == true;
    // Past events: Completed (grey). Offline registered events can view ticket.
    final showCompleted =
        event != null && !isCoordinator && isCompleted && !isRegistered;
    final showViewTicket =
        event != null && !isCoordinator && isRegistered && !isOnline;
    final showRegisteredOnline =
        event != null && !isCoordinator && isRegistered && isOnline;
    final showRegister = event != null &&
        !isCoordinator &&
        !isCompleted &&
        !isRegistered &&
        event.registrationEnabled == true;
    // QR check-in is only for offline / in-person events.
    final showScanQr =
        event != null && isCoordinator && !isCompleted && !isOnline;
    final showBottomBar = showScanQr ||
        showRegister ||
        showViewTicket ||
        showRegisteredOnline ||
        showCompleted;

    return Scaffold(
      backgroundColor: kWhite,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                kScreenPaddingH,
                8,
                kScreenPaddingH,
                16,
              ),
              child: Row(
                children: [
                  _headerCircleButton(
                    onTap: () {
                      HapticHelper.impact(HapticImpact.light);
                      Navigator.pop(context);
                    },
                    child: const Icon(
                      Icons.arrow_back,
                      color: kTextColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Event Details',
                      style: kSectionTitleSB,
                    ),
                  ),
                  if (hasId) ...[
                    _headerCircleButton(
                      onTap: _shareLoading
                          ? null
                          : () {
                              final id = widget.eventId!;
                              final title = event?.title ?? widget.title;
                              _shareEvent(id, title);
                            },
                      child: _shareLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : SvgPicture.asset(
                              'assets/svg/share.svg',
                              width: 18,
                              height: 18,
                              colorFilter: const ColorFilter.mode(
                                kTextColor,
                                BlendMode.srcIn,
                              ),
                            ),
                    ),
                    const SizedBox(width: 8),
                    _headerCircleButton(
                      onTap: _bookmarkLoading
                          ? null
                          : () {
                              HapticHelper.impact(HapticImpact.light);
                              if (event != null) _toggleBookmark(event);
                            },
                      child: _bookmarkLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : SvgPicture.asset(
                              'assets/svg/bookmark.svg',
                              width: 18,
                              height: 18,
                              colorFilter: ColorFilter.mode(
                                isBookmarked ? kPrimaryColor : kTextColor,
                                BlendMode.srcIn,
                              ),
                            ),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: hasId
                  ? RefreshIndicator(
                      color: kPrimaryColor,
                      onRefresh: () async {
                        ref.invalidate(eventDetailProvider(widget.eventId!));
                        await ref.read(
                          eventDetailProvider(widget.eventId!).future,
                        );
                      },
                      child: AsyncContent(
                        asyncValue: eventAsync!,
                        onRetry: () => ref.invalidate(
                          eventDetailProvider(widget.eventId!),
                        ),
                        builder: _buildBody,
                      ),
                    )
                  : _fallbackBody(),
            ),
          ],
        ),
      ),
      bottomNavigationBar: hasId && event != null && showBottomBar
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  kScreenPaddingH,
                  8,
                  kScreenPaddingH,
                  16,
                ),
                child: ElevatedButton(
                  onPressed: showCompleted
                      ? null
                      : showScanQr
                      ? () {
                          HapticHelper.impact(HapticImpact.medium);
                          NavigationService().pushNamed(
                            'EventQrScan',
                            arguments: {
                              'eventId': event.id,
                              'eventTitle': event.title,
                            },
                          );
                        }
                      : _registerLoading
                      ? null
                      : () {
                          HapticHelper.impact(HapticImpact.medium);
                          _registerOrViewTicket(event);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: (showCompleted || showRegisteredOnline)
                        ? kGrey
                        : kPrimaryColor,
                    foregroundColor: kWhite,
                    disabledBackgroundColor: showCompleted
                        ? kGrey
                        : kPrimaryColor.withValues(alpha: 0.6),
                    disabledForegroundColor: kWhite,
                    minimumSize: const Size.fromHeight(56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(kCardRadiusSm),
                    ),
                    elevation: 0,
                  ),
                  child: showCompleted
                      ? Text('Completed', style: kButtonLabelSB)
                      : showRegisteredOnline
                      ? Text('Registered', style: kButtonLabelSB)
                      : showScanQr
                      ? Text('Scan QR', style: kButtonLabelSB)
                      : _registerLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: kWhite,
                          ),
                        )
                      : Text(
                          showViewTicket ? 'View Ticket' : 'Register',
                          style: kButtonLabelSB,
                        ),
                ),
              ),
            )
          : null,
    );
  }
}
