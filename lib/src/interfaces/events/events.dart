import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jamiat/src/data/apis/event_api.dart';
import 'package:jamiat/src/data/constants/color_constants.dart';
import 'package:jamiat/src/data/constants/style_constants.dart';
import 'package:jamiat/src/data/models/event_model.dart';
import 'package:jamiat/src/data/providers/event_provider.dart';
import 'package:jamiat/src/data/services/event_share_service.dart';
import 'package:jamiat/src/data/services/haptic_helper.dart';
import 'package:jamiat/src/data/services/navigation_services.dart';
import 'package:jamiat/src/interfaces/components/async_content.dart';
import 'package:jamiat/src/interfaces/events/event_card.dart';

class EventsScreen extends ConsumerStatefulWidget {
  const EventsScreen({super.key});

  @override
  ConsumerState<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends ConsumerState<EventsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final Map<String, bool> _bookmarkOverrides = {};
  String? _bookmarkLoadingId;
  String? _shareLoadingId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<EventModel> _filter(List<EventModel> items) {
    // Upcoming list: drop completed/deleted (API status) and past-by-date.
    var result = items
        .where((e) => !e.isHiddenFromListing && !e.hasEnded)
        .toList();
    if (_searchQuery.isEmpty) return result;
    final query = _searchQuery.toLowerCase();
    return result.where((e) {
      return e.title.toLowerCase().contains(query) ||
          e.type.toLowerCase().contains(query) ||
          (e.venue?.toLowerCase().contains(query) ?? false) ||
          e.description.toLowerCase().contains(query);
    }).toList();
  }

  bool _isBookmarked(EventModel event) {
    return _bookmarkOverrides[event.id] ?? event.isBookmarked;
  }

  Future<void> _toggleBookmark(EventModel event) async {
    if (_bookmarkLoadingId != null) return;
    final currentlyBookmarked = _isBookmarked(event);
    setState(() => _bookmarkLoadingId = event.id);
    try {
      final api = ref.read(eventApiProvider);
      final res = currentlyBookmarked
          ? await api.removeBookmark(event.id)
          : await api.bookmarkEvent(event.id);
      if (!mounted) return;
      if (!res.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res.message ?? 'Bookmark failed')),
        );
        return;
      }
      // Optimistic UI until providers refresh, then overrides are cleared.
      setState(() => _bookmarkOverrides[event.id] = !currentlyBookmarked);
      ref.invalidate(savedEventsProvider);
      ref.invalidate(eventsListProvider);
      ref.invalidate(eventDetailProvider(event.id));
    } finally {
      if (mounted) setState(() => _bookmarkLoadingId = null);
    }
  }

  Future<void> _shareEvent(EventModel event) async {
    if (_shareLoadingId != null) return;
    setState(() => _shareLoadingId = event.id);
    try {
      HapticHelper.impact(HapticImpact.light);
      await ref.read(eventShareServiceProvider).shareEvent(
            context: context,
            eventId: event.id,
            title: event.title,
          );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _shareLoadingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Drop local overrides once the list reflects server bookmark state.
    // Fixes green bookmark staying active after unsaving from Saved Events.
    ref.listen(eventsListProvider, (previous, next) {
      // Wait until a fresh (non-loading) response arrives so we don't clear
      // optimistic overrides against stale cached list data mid-refresh.
      if (!next.hasValue || next.isLoading) return;
      if (!mounted || _bookmarkOverrides.isEmpty) return;
      setState(() => _bookmarkOverrides.clear());
    });

    final eventsAsync = ref.watch(eventsListProvider);
    final upcomingTicketsAsync = ref.watch(myTicketsProvider('upcoming'));

    return Scaffold(
      backgroundColor: kWhite,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            kScreenPaddingH,
            8,
            kScreenPaddingH,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          HapticHelper.impact(HapticImpact.light);
                          if (Navigator.canPop(context)) {
                            Navigator.pop(context);
                          }
                        },
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: kWhite.withValues(alpha: 0.08),
                            border: Border.all(color: kGrey, width: 1.25),
                          ),
                          child: const Icon(
                            Icons.arrow_back,
                            color: kTextColor,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('Events', style: kSectionTitleSB),
                    ],
                  ),
                  PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    offset: const Offset(0, 44),
                    color: kWhite,
                    elevation: 8,
                    shadowColor: kBlack.withValues(alpha: 0.18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    icon: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: kWhite.withValues(alpha: 0.08),
                        border: Border.all(color: kGrey, width: 1.25),
                      ),
                      child: const Icon(
                        Icons.more_vert,
                        color: kTextColor,
                        size: 20,
                      ),
                    ),
                    onSelected: (value) {
                      HapticHelper.impact(HapticImpact.light);
                      if (value == 'tickets') {
                        NavigationService().pushNamed('MyTickets');
                      } else {
                        NavigationService().pushNamed('SavedEvents');
                      }
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem<String>(
                        value: 'tickets',
                        height: 48,
                        child: Text(
                          'My Tickets',
                          style: kStyle(
                            kMedium,
                            15,
                            color: const Color(0xFF888888),
                          ),
                        ),
                      ),
                      PopupMenuItem<String>(
                        enabled: false,
                        height: 1,
                        padding: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Divider(
                            height: 1,
                            thickness: 1,
                            color: kBorder.withValues(alpha: 0.9),
                          ),
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'saved',
                        height: 48,
                        child: Text(
                          'Saved',
                          style: kStyle(
                            kMedium,
                            15,
                            color: const Color(0xFF888888),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 56,
                      decoration: BoxDecoration(
                        color: kWhite,
                        borderRadius: BorderRadius.circular(kCardRadiusMd),
                        border: Border.all(color: kCardBorder),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          const Icon(Icons.search, color: kMutedText, size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              onChanged: (v) =>
                                  setState(() => _searchQuery = v),
                              decoration: InputDecoration(
                                hintText: 'Search for events...',
                                hintStyle: kBodyTitleR.copyWith(
                                  color: kSecondaryTextColor,
                                ),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // const SizedBox(width: 10),
                  // Container(
                  //   width: 56,
                  //   height: 56,
                  //   decoration: BoxDecoration(
                  //     color: kWhite,
                  //     borderRadius: BorderRadius.circular(kCardRadiusMd),
                  //     border: Border.all(color: kCardBorder),
                  //   ),
                  //   child: IconButton(
                  //     onPressed: () {
                  //       HapticHelper.impact(HapticImpact.light);
                  //       ScaffoldMessenger.of(context).showSnackBar(
                  //         const SnackBar(
                  //           content: Text('Filters coming soon'),
                  //         ),
                  //       );
                  //     },
                  //     icon: const Icon(
                  //       Icons.tune_rounded,
                  //       color: kTextColor,
                  //       size: 22,
                  //     ),
                  //   ),
                  // ),
                ],
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () {
                  HapticHelper.impact(HapticImpact.light);
                  NavigationService().pushNamed('MyTickets');
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDF6E3),
                    borderRadius: BorderRadius.circular(kCardRadiusMd),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.confirmation_number_outlined,
                          color: Color(0xFFB45309),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'My Tickets',
                              style: kCaption10R.copyWith(
                                color: kSecondaryTextColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              upcomingTicketsAsync.when(
                                data: (tickets) {
                                  final count = tickets
                                      .where((t) => t.isOfflineEvent)
                                      .length;
                                  if (count == 0) {
                                    return 'No upcoming tickets';
                                  }
                                  return '$count upcoming ticket${count == 1 ? '' : 's'}';
                                },
                                loading: () => 'Loading tickets...',
                                error: (_, _) => 'View your tickets',
                              ),
                              style: kCaption12SB.copyWith(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        color: kMutedText,
                        size: 22,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Upcoming events', style: kSectionTitleSB),
              const SizedBox(height: 12),
              Expanded(
                child: AsyncContent(
                  asyncValue: eventsAsync,
                  onRetry: () => ref.invalidate(eventsListProvider),
                  builder: (page) {
                    final events = _filter(page.items);
                    if (events.isEmpty) {
                      return Center(
                        child: Text(
                          _searchQuery.isEmpty
                              ? 'No upcoming events'
                              : 'No events found',
                          style: kEmptyStateM,
                        ),
                      );
                    }
                    return RefreshIndicator(
                      color: kPrimaryColor,
                      onRefresh: () async {
                        ref.invalidate(eventsListProvider);
                        ref.invalidate(myTicketsProvider('upcoming'));
                        await ref.read(eventsListProvider.future);
                      },
                      child: ListView.builder(
                        itemCount: events.length,
                        itemBuilder: (_, i) {
                          final event = events[i];
                          return EventListCard(
                            event: event,
                            isBookmarked: _isBookmarked(event),
                            isBookmarkLoading: _bookmarkLoadingId == event.id,
                            isShareLoading: _shareLoadingId == event.id,
                            onTap: () {
                              HapticHelper.impact(HapticImpact.light);
                              NavigationService().pushNamed(
                                'EventDetails',
                                arguments: {'eventId': event.id},
                              );
                            },
                            onBookmark: () {
                              HapticHelper.impact(HapticImpact.light);
                              _toggleBookmark(event);
                            },
                            onShare: () => _shareEvent(event),
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
      ),
    );
  }
}
