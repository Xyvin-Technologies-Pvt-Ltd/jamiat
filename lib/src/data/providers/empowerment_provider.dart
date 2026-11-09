import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jamiat/src/data/apis/empowerment_api.dart';
import 'package:jamiat/src/data/models/empowerment_model.dart';
import 'package:jamiat/src/data/models/paginated_response.dart';

final empowermentProgramsProvider = FutureProvider.autoDispose
    .family<PaginatedResponse<EmpowermentProgramModel>, String>((
      ref,
      mode,
    ) async {
      final response = await ref
          .watch(empowermentApiProvider)
          .getPrograms(mode: mode);
      if (!response.success || response.data == null) {
        throw Exception(response.message ?? 'Failed to load programs');
      }
      return response.data!;
    });

final empowermentProgramDetailProvider =
    FutureProvider.autoDispose.family<EmpowermentProgramModel, String>((
      ref,
      id,
    ) async {
      final response = await ref
          .watch(empowermentApiProvider)
          .getProgramById(id);
      if (!response.success || response.data == null) {
        throw Exception(response.message ?? 'Failed to load program');
      }

      var program = response.data!;
      if (!program.isApplied) {
        final isApplied = await _resolveProgramAppliedStatus(ref, id);
        if (isApplied) {
          program = program.copyWith(isApplied: true);
        }
      }
      return program;
    });

Future<bool> _resolveProgramAppliedStatus(Ref ref, String id) async {
  final allAsync = ref.read(empowermentProgramsProvider('all'));
  final fromAll = allAsync.maybeWhen(
    data: (page) {
      for (final program in page.items) {
        if (program.id == id) return program.isApplied;
      }
      return null;
    },
    orElse: () => null,
  );
  if (fromAll == true) return true;

  final appliedAsync = ref.read(empowermentProgramsProvider('applied'));
  final fromApplied = appliedAsync.maybeWhen(
    data: (page) => page.items.any((program) => program.id == id),
    orElse: () => null,
  );
  if (fromApplied == true) return true;

  final appliedResponse = await ref
      .read(empowermentApiProvider)
      .getPrograms(mode: 'applied', limit: 100);
  if (appliedResponse.success && appliedResponse.data != null) {
    return appliedResponse.data!.items.any((program) => program.id == id);
  }
  return false;
}

final empowermentSearchProvider = FutureProvider.autoDispose
    .family<
      PaginatedResponse<EmpowermentProgramModel>,
      ({String search, int page})
    >((ref, query) async {
      final response = await ref
          .watch(empowermentApiProvider)
          .getPrograms(search: query.search, pageNo: query.page);
      if (!response.success || response.data == null) {
        throw Exception(response.message ?? 'Failed to load programs');
      }
      return response.data!;
    });
