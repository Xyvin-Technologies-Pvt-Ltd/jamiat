import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jamiat/src/data/apis/empowerment_api.dart';
import 'package:jamiat/src/data/models/api_response.dart';
import 'package:jamiat/src/data/models/empowerment_model.dart';
import 'package:jamiat/src/data/models/paginated_response.dart';
import 'package:jamiat/src/interfaces/empowerment/empowerment_programs.dart';

class _EmpowermentApi implements EmpowermentApi {
  final calls = <({String search, int page})>[];
  final slow =
      Completer<ApiResponse<PaginatedResponse<EmpowermentProgramModel>>>();

  ApiResponse<PaginatedResponse<EmpowermentProgramModel>> result(
    String title,
    int page,
    int total,
  ) {
    return ApiResponse.success(
      PaginatedResponse(
        items: [
          EmpowermentProgramModel(
            id: title,
            title: title,
            description: 'Description',
            isApplied: false,
            isBookmarked: false,
          ),
        ],
        totalCount: total,
        pageNo: page,
        limit: 10,
      ),
      200,
    );
  }

  @override
  Future<ApiResponse<PaginatedResponse<EmpowermentProgramModel>>> getPrograms({
    int pageNo = 1,
    int limit = 10,
    String mode = 'all',
    String? search,
  }) async {
    calls.add((search: search ?? '', page: pageNo));
    if (search == 'slow') return slow.future;
    return result(
      search?.isNotEmpty == true
          ? 'Match $search page $pageNo'
          : 'Latest empowerment',
      pageNo,
      11,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets(
    'searches server, paginates, ignores stale responses and resets on clear',
    (tester) async {
      final api = _EmpowermentApi();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [empowermentApiProvider.overrideWithValue(api)],
          child: const MaterialApp(home: EmpowermentProgramsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Latest empowerment'), findsOneWidget);
      final field = find.byType(TextField);
      await tester.enterText(field, 'slow');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();
      await tester.enterText(field, '  Medical  ');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(find.text('Match Medical page 1'), findsOneWidget);
      expect(api.calls.last, (search: 'Medical', page: 1));
      api.slow.complete(api.result('Stale result', 1, 1));
      await tester.pumpAndSettle();
      expect(find.text('Stale result'), findsNothing);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(api.calls.last, (search: 'Medical', page: 2));
      expect(find.text('Match Medical page 2'), findsOneWidget);
      await tester.enterText(field, '');
      await tester.pumpAndSettle();
      expect(api.calls.last, (search: '', page: 1));
      expect(find.text('Latest empowerment'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
