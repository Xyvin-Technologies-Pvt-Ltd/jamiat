import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jamiat/src/data/constants/color_constants.dart';
import 'package:jamiat/src/data/constants/style_constants.dart';
import 'package:jamiat/src/data/models/event_model.dart';
import 'package:jamiat/src/data/providers/event_provider.dart';
import 'package:jamiat/src/data/services/haptic_helper.dart';
import 'package:jamiat/src/data/services/navigation_services.dart';
import 'package:jamiat/src/data/utils/format_helpers.dart';
import 'package:jamiat/src/interfaces/components/async_content.dart';

/// Profile → Events: only events the logged-in user has registered for.
class MyRegisteredEventsScreen extends ConsumerStatefulWidget {
  const MyRegisteredEventsScreen({super.key});

  @override
  ConsumerState<MyRegisteredEventsScreen> createState() =>
      _MyRegisteredEventsScreenState();
}

class _MyRegisteredEventsScreenState
    extends ConsumerState<MyRegisteredEventsScreen> {
  bool _isUpcomingSelected = true;

  static const _cardCream = Color(0xFFFFF8E7);

  Map<String, List<EventTicketModel>> _groupByMonth(
    List<EventTicketModel> tickets,
  ) {
    final map = <String, List<EventTicketModel>>{};
    for (final ticket in tickets) {
      final date = ticket.eventDate ?? DateTime.now();
      final key = formatEventMonthYear(date);
      map.putIfAbsent(key, () => []).add(ticket);
    }
    return map;
  }

  void _openRegisteredEvent(EventTicketModel ticket) {
    HapticHelper.impact(HapticImpact.light);
    final eventId = ticket.eventId;
    if (eventId != null && eventId.isNotEmpty) {
      NavigationService().pushNamed(
        'EventDetails',
        arguments: {'eventId': eventId},
      );
      return;
    }
    NavigationService().pushNamed(
      'EventTicket',
      arguments: {'ticketId': ticket.id},
    );
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

  @override
  Widget build(BuildContext context) {
    final tab = _isUpcomingSelected ? 'upcoming' : 'past';
    final eventsAsync = ref.watch(myTicketsProvider(tab));
    final upcomingAsync = ref.watch(myTicketsProvider('upcoming'));
    final pastAsync = ref.watch(myTicketsProvider('past'));

    final upcomingCount = upcomingAsync.value?.length;
    final pastCount = pastAsync.value?.length;

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
                  Text('Events', style: kSectionTitleSB),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: kScreenPaddingH),
              child: Row(
                children: [
                  _tabChip(
                    label: 'Upcoming',
                    count: upcomingCount,
                    active: _isUpcomingSelected,
                    onTap: () => setState(() => _isUpcomingSelected = true),
                  ),
                  const SizedBox(width: 10),
                  _tabChip(
                    label: 'Past',
                    count: pastCount,
                    active: !_isUpcomingSelected,
                    onTap: () => setState(() => _isUpcomingSelected = false),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: AsyncContent(
                asyncValue: eventsAsync,
                onRetry: () => ref.invalidate(myTicketsProvider(tab)),
                builder: (tickets) {
                  if (tickets.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Text(
                          _isUpcomingSelected
                              ? 'No upcoming registered events'
                              : 'No past registered events',
                          style: kEmptyStateM,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }

                  final grouped = _groupByMonth(tickets);
                  final sections = grouped.entries.toList();

                  return RefreshIndicator(
                    color: kPrimaryColor,
                    onRefresh: () async {
                      ref.invalidate(myTicketsProvider('upcoming'));
                      ref.invalidate(myTicketsProvider('past'));
                      await ref.read(myTicketsProvider(tab).future);
                    },
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: kScreenPaddingH,
                      ),
                      itemCount: sections.length,
                      itemBuilder: (context, sectionIndex) {
                        final entry = sections[sectionIndex];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: EdgeInsets.only(
                                top: sectionIndex == 0 ? 0 : 8,
                                bottom: 10,
                              ),
                              child: Text(
                                entry.key,
                                style: kCaption12M.copyWith(
                                  color: kMutedText,
                                ),
                              ),
                            ),
                            ...entry.value.map(
                              (ticket) => _RegisteredEventCard(
                                ticket: ticket,
                                isUpcoming: _isUpcomingSelected,
                                cream: _cardCream,
                                onTap: () => _openRegisteredEvent(ticket),
                                onViewTicket: ticket.isOfflineEvent
                                    ? () {
                                        HapticHelper.impact(
                                          HapticImpact.light,
                                        );
                                        NavigationService().pushNamed(
                                          'EventTicket',
                                          arguments: {'ticketId': ticket.id},
                                        );
                                      }
                                    : null,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabChip({
    required String label,
    required bool active,
    required VoidCallback onTap,
    int? count,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: active ? kSecondaryColor : kWhite,
          borderRadius: BorderRadius.circular(kCardRadiusSm),
          border: Border.all(
            color: active
                ? kSecondaryColor
                : kSecondaryColor.withValues(alpha: 0.45),
          ),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: kCaption12M.copyWith(
                color: active ? kTextColor : kMutedText,
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: active
                      ? kWhite.withValues(alpha: 0.9)
                      : kScreenBg,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  '$count',
                  style: kCaption10SB.copyWith(
                    color: active ? kTextColor : kMutedText,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RegisteredEventCard extends StatelessWidget {
  const _RegisteredEventCard({
    required this.ticket,
    required this.isUpcoming,
    required this.cream,
    required this.onTap,
    this.onViewTicket,
  });

  final EventTicketModel ticket;
  final bool isUpcoming;
  final Color cream;
  final VoidCallback onTap;
  final VoidCallback? onViewTicket;

  @override
  Widget build(BuildContext context) {
    final attended = ticket.isAttended;
    final statusLabel = isUpcoming
        ? 'Registered'
        : (attended ? 'Attended' : 'Missed');
    final statusColor = isUpcoming
        ? kPrimaryColor
        : (attended ? kPrimaryColor : kRed);
    final statusBg = isUpcoming
        ? kLightGreen
        : (attended ? kLightGreen : kRedSoftBg);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: kWhite,
          borderRadius: BorderRadius.circular(kCardRadiusMd),
          border: Border.all(color: kCardBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              color: isUpcoming ? cream : kScreenBg,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ticket.eventTitle ?? 'Event',
                          style: kCaption12SB.copyWith(color: kTextColor),
                        ),
                        if (isUpcoming) ...[
                          const SizedBox(height: 4),
                          Text(
                            ticket.passType,
                            style: kCaption12R.copyWith(color: kMutedText),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(kCardRadiusSm),
                    ),
                    child: Text(
                      statusLabel,
                      style: kCaption12M.copyWith(color: statusColor),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Date',
                          style: kCaption12R.copyWith(
                            color: kSecondaryTextColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          formatEventShortDate(ticket.eventDate),
                          style: kCaption12SB.copyWith(color: kTextColor),
                        ),
                      ],
                    ),
                  ),
                  if (ticket.venue != null && ticket.venue!.isNotEmpty)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Venue',
                            style: kCaption12R.copyWith(
                              color: kSecondaryTextColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            ticket.venue!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: kCaption12SB.copyWith(color: kTextColor),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            if (isUpcoming && onViewTicket != null)
              Material(
                color: kScreenBg,
                child: InkWell(
                  onTap: onViewTicket,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.qr_code_2,
                          size: 28,
                          color: kTextColor,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'View ticket',
                                style: kCaption12SB.copyWith(
                                  color: kTextColor,
                                ),
                              ),
                              Text(
                                'Show QR to coordinators',
                                style: kCaption12R.copyWith(
                                  color: kSecondaryTextColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: kMutedText),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
