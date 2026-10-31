import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:jamiat/src/data/apis/empowerment_api.dart';
import 'package:jamiat/src/data/constants/color_constants.dart';
import 'package:jamiat/src/data/constants/style_constants.dart';
import 'package:jamiat/src/data/models/empowerment_model.dart';
import 'package:jamiat/src/data/providers/empowerment_provider.dart';
import 'package:jamiat/src/data/services/haptic_helper.dart';
import 'package:jamiat/src/data/services/navigation_services.dart';
import 'package:jamiat/src/data/utils/format_helpers.dart';
import 'package:jamiat/src/interfaces/components/async_content.dart';

class EmpowermentProgramsScreen extends ConsumerStatefulWidget {
  const EmpowermentProgramsScreen({super.key});

  @override
  ConsumerState<EmpowermentProgramsScreen> createState() =>
      _EmpowermentProgramsScreenState();
}

class _EmpowermentProgramsScreenState
    extends ConsumerState<EmpowermentProgramsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int _page = 1;
  Timer? _searchDebounce;

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    if (value.trim().isEmpty) {
      _applySearch();
    } else {
      _searchDebounce = Timer(const Duration(milliseconds: 300), _applySearch);
    }
  }

  void _applySearch() {
    _searchDebounce?.cancel();
    final query = _searchController.text.trim();
    if (!mounted || query == _searchQuery) return;
    setState(() {
      _searchQuery = query;
      _page = 1;
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _apply(EmpowermentProgramModel program) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Apply for program?'),
        content: Text('Do you want to apply for "${program.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Apply'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final res = await ref
        .read(empowermentApiProvider)
        .applyForProgram(program.id);
    if (!mounted) return;
    if (res.success) {
      ref.invalidate(empowermentProgramsProvider('all'));
      ref.invalidate(empowermentSearchProvider);
      ref.invalidate(empowermentProgramsProvider('applied'));
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Application Submitted'),
          content: Text('You have successfully applied for ${program.title}.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(res.message ?? 'Failed to apply')));
    }
  }

  Future<void> _toggleSave(EmpowermentProgramModel program) async {
    final api = ref.read(empowermentApiProvider);
    final res = program.isBookmarked
        ? await api.unsaveProgram(program.id)
        : await api.saveProgram(program.id);
    if (res.success) {
      ref.invalidate(empowermentProgramsProvider('all'));
      ref.invalidate(empowermentSearchProvider);
      ref.invalidate(empowermentProgramsProvider('saved'));
    }
  }

  Widget _headerCircleButton({required Widget child, VoidCallback? onTap}) {
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

  Widget _image(String? url) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: url != null && url.startsWith('http')
          ? Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                color: kScreenBg,
                child: const Icon(Icons.image_outlined, color: kMutedText),
              ),
            )
          : Image.asset(
              url ?? 'assets/jpgs/campaign_welfare.jpg',
              fit: BoxFit.cover,
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final searchProvider = empowermentSearchProvider((
      search: _searchQuery,
      page: _page,
    ));
    final programsAsync = ref.watch(searchProvider);

    return Scaffold(
      backgroundColor: kWhite,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                kScreenPaddingH,
                8,
                kScreenPaddingH,
                0,
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
                    child: Text('Empowerment Programs', style: kSectionTitleSB),
                  ),
                  _headerCircleButton(
                    onTap: () {
                      HapticHelper.impact(HapticImpact.light);
                      NavigationService().pushNamed('AppliedPrograms');
                    },
                    child: SvgPicture.asset(
                      'assets/svg/bookmark.svg',
                      width: 18,
                      height: 18,
                      colorFilter: const ColorFilter.mode(
                        kTextColor,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: kScreenPaddingH),
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
                        onChanged: _onSearchChanged,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => _applySearch(),
                        decoration: InputDecoration(
                          hintText: 'Search programs',
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
            const SizedBox(height: 16),
            Expanded(
              child: AsyncContent(
                asyncValue: programsAsync,
                onRetry: () => ref.invalidate(searchProvider),
                builder: (page) {
                  final programs = page.items;
                  if (programs.isEmpty) {
                    return Center(
                      child: Text('No programs found', style: kEmptyStateM),
                    );
                  }
                  return Column(
                    children: [
                      Expanded(
                        child: ListView.builder(
                          key: ValueKey((_searchQuery, _page)),
                          padding: const EdgeInsets.symmetric(
                            horizontal: kScreenPaddingH,
                          ),
                          itemCount: programs.length,
                          itemBuilder: (context, index) {
                            final program = programs[index];
                            return GestureDetector(
                              onTap: () {
                                NavigationService().pushNamed(
                                  'ProgramDetails',
                                  arguments: {
                                    'programId': program.id,
                                    'isApplied': program.isApplied,
                                  },
                                );
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 20),
                                decoration: BoxDecoration(
                                  color: kWhite,
                                  borderRadius: BorderRadius.circular(
                                    kCardRadiusLg,
                                  ),
                                  border: Border.all(color: kCardBorder),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Stack(
                                      children: [
                                        _image(program.image),
                                        Positioned(
                                          top: 10,
                                          right: 10,
                                          child: Material(
                                            color: kBlack.withValues(
                                              alpha: 0.35,
                                            ),
                                            shape: const CircleBorder(),
                                            child: InkWell(
                                              customBorder:
                                                  const CircleBorder(),
                                              onTap: () {
                                                HapticHelper.impact(
                                                  HapticImpact.light,
                                                );
                                                _toggleSave(program);
                                              },
                                              child: SizedBox(
                                                width: 36,
                                                height: 36,
                                                child: Center(
                                                  child: SvgPicture.asset(
                                                    'assets/svg/bookmark.svg',
                                                    width: 16,
                                                    height: 16,
                                                    colorFilter:
                                                        ColorFilter.mode(
                                                          program.isBookmarked
                                                              ? kPrimaryColor
                                                              : kWhite,
                                                          BlendMode.srcIn,
                                                        ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(14),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            program.title,
                                            style: kSectionTitleSB,
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            program.description,
                                            style: kCaption12R.copyWith(
                                              color: kSecondaryTextColor,
                                              height: 1.4,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 12),
                                          Row(
                                            children: [
                                              if (program.startDate != null)
                                                Expanded(
                                                  child: Text(
                                                    'Starts ${formatDateLabel(program.startDate)}',
                                                    style: kCaption12R.copyWith(
                                                      color: kTextColor,
                                                    ),
                                                  ),
                                                )
                                              else
                                                const Spacer(),
                                              SizedBox(
                                                height: 40,
                                                child: ElevatedButton(
                                                  onPressed: program.isApplied
                                                      ? null
                                                      : () {
                                                          HapticHelper.impact(
                                                            HapticImpact.medium,
                                                          );
                                                          _apply(program);
                                                        },
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        kPrimaryColor,
                                                    foregroundColor: kWhite,
                                                    disabledBackgroundColor:
                                                        kPrimaryColor
                                                            .withValues(
                                                              alpha: 0.6,
                                                            ),
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 20,
                                                        ),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            kCardRadiusSm,
                                                          ),
                                                    ),
                                                    elevation: 0,
                                                  ),
                                                  child: Text(
                                                    program.isApplied
                                                        ? 'Applied'
                                                        : 'Apply',
                                                    style: kButtonLabelSB,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      if (_page > 1 || page.hasMore)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: kScreenPaddingH,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TextButton(
                                onPressed: _page > 1
                                    ? () => setState(() => _page--)
                                    : null,
                                child: const Text('Previous'),
                              ),
                              Text('Page $_page', style: kCaption12R),
                              TextButton(
                                onPressed: page.hasMore
                                    ? () => setState(() => _page++)
                                    : null,
                                child: const Text('Next'),
                              ),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
