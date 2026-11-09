import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jamiat/src/data/apis/product_api.dart';
import 'package:jamiat/src/data/models/paginated_response.dart';
import 'package:jamiat/src/data/models/product_model.dart';

final productsListProvider =
    FutureProvider.autoDispose<PaginatedResponse<ProductModel>>((ref) async {
  final response = await ref.watch(productApiProvider).listProducts();
  if (!response.success || response.data == null) {
    throw Exception(response.message ?? 'Failed to load products');
  }
  return response.data!;
});

final productDetailProvider =
    FutureProvider.autoDispose.family<ProductModel, String>((ref, id) async {
  final response = await ref.watch(productApiProvider).getProductById(id);
  if (!response.success || response.data == null) {
    throw Exception(response.message ?? 'Failed to load product');
  }
  return response.data!;
});

final savedProductsProvider =
    FutureProvider.autoDispose<PaginatedResponse<ProductModel>>((ref) async {
  final response = await ref.watch(productApiProvider).getSavedProducts();
  if (!response.success || response.data == null) {
    throw Exception(response.message ?? 'Failed to load saved products');
  }
  return response.data!;
});

final myProductEnquiriesProvider =
    FutureProvider.autoDispose<PaginatedResponse<ProductEnquiryModel>>((
      ref,
    ) async {
      final response = await ref.watch(productApiProvider).getMyEnquiries();
      if (!response.success || response.data == null) {
        throw Exception(response.message ?? 'Failed to load enquiries');
      }
      return response.data!;
    });
