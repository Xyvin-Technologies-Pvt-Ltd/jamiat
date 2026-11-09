import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jamiat/src/data/apis/enquiry_api.dart';
import 'package:jamiat/src/data/models/enquiry_model.dart';
import 'package:jamiat/src/data/models/paginated_response.dart';

final receivedEnquiriesProvider =
    FutureProvider.autoDispose<PaginatedResponse<EnquiryModel>>((ref) async {
      final response = await ref
          .watch(enquiryApiProvider)
          .getReceivedEnquiries();
      if (!response.success || response.data == null) {
        throw Exception(response.message ?? 'Failed to load enquiries');
      }
      return response.data!;
    });
