import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jamiat/src/data/apis/event_api.dart';
import 'package:jamiat/src/data/models/event_model.dart';
import 'package:jamiat/src/data/models/paginated_response.dart';

final eventsListProvider =
    FutureProvider.autoDispose<PaginatedResponse<EventModel>>((ref) async {
  final response = await ref.watch(eventApiProvider).listEvents();
  if (!response.success || response.data == null) {
    throw Exception(response.message ?? 'Failed to load events');
  }
  return response.data!;
});

final eventDetailProvider =
    FutureProvider.autoDispose.family<EventModel, String>((ref, id) async {
  final response = await ref.watch(eventApiProvider).getEventById(id);
  if (!response.success || response.data == null) {
    throw Exception(response.message ?? 'Failed to load event');
  }
  return response.data!;
});

final savedEventsProvider = FutureProvider.autoDispose<List<EventModel>>((
  ref,
) async {
  final response = await ref.watch(eventApiProvider).getSavedEvents();
  if (!response.success || response.data == null) {
    throw Exception(response.message ?? 'Failed to load saved events');
  }
  return response.data!;
});

final myTicketsProvider = FutureProvider.autoDispose
    .family<List<EventTicketModel>, String>((ref, tab) async {
  final response = await ref.watch(eventApiProvider).getMyTickets(tab: tab);
  if (!response.success || response.data == null) {
    throw Exception(response.message ?? 'Failed to load tickets');
  }
  return response.data!;
});

final eventTicketProvider =
    FutureProvider.autoDispose.family<EventTicketModel, String>((
  ref,
  ticketId,
) async {
  final response = await ref.watch(eventApiProvider).getTicketById(ticketId);
  if (!response.success || response.data == null) {
    throw Exception(response.message ?? 'Failed to load ticket');
  }
  return response.data!;
});
