import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:jamiat/src/data/apis/empowerment_api.dart';
import 'package:jamiat/src/data/constants/color_constants.dart';
import 'package:jamiat/src/data/constants/style_constants.dart';
import 'package:jamiat/src/data/providers/empowerment_provider.dart';
import 'package:jamiat/src/data/services/haptic_helper.dart';
import 'package:jamiat/src/data/utils/format_helpers.dart';
import 'package:jamiat/src/interfaces/components/async_content.dart';

class ProgramDetailsScreen extends ConsumerStatefulWidget {
  final String programId;
  final bool initialIsApplied;

  const ProgramDetailsScreen({
    super.key,
    required this.programId,
    this.initialIsApplied = false,
  });

  @override
  ConsumerState<ProgramDetailsScreen> createState() =>
      _ProgramDetailsScreenState();
}

class _ProgramDetailsScreenState extends ConsumerState<ProgramDetailsScreen> {
  bool _bookmarkLoading = false;
  bool _applyLoading = false;

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

  Future<void> _toggleBookmark(bool isBookmarked) async {
    if (_bookmarkLoading) return;
    setState(() => _bookmarkLoading = true);
    try {
      final api = ref.read(empowermentApiProvider);
      final res = isBookmarked
          ? await api.unsaveProgram(widget.programId)
          : await api.saveProgram(widget.programId);
      if (!mounted) return;
      if (!res.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res.message ?? 'Bookmark failed')),
        );
        return;
      }
      ref.invalidate(empowermentProgramDetailProvider(widget.programId));
      ref.invalidate(empowermentProgramsProvider('all'));
      ref.invalidate(empowermentSearchProvider);
      ref.invalidate(empowermentProgramsProvider('saved'));
    } finally {
      if (mounted) setState(() => _bookmarkLoading = false);
    }
  }

  Future<void> _apply() async {
    if (_applyLoading) return;
    setState(() => _applyLoading = true);
    try {
      final res = await ref
          .read(empowermentApiProvider)
          .applyForProgram(widget.programId);
      if (!mounted) return;
      if (res.success) {
        ref.invalidate(empowermentProgramDetailProvider(widget.programId));
        ref.invalidate(empowermentProgramsProvider('all'));
        ref.invalidate(empowermentSearchProvider);
        ref.invalidate(empowermentProgramsProvider('applied'));
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Application submitted')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res.message ?? 'Failed to apply')),
        );
      }
    } finally {
      if (mounted) setState(() => _applyLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final programAsync = ref.watch(
      empowermentProgramDetailProvider(widget.programId),
    );
    final program = programAsync.value;
    final isApplied = (program?.isApplied ?? false) || widget.initialIsApplied;
    final isBookmarked = program?.isBookmarked ?? false;

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
                    child: Text('Program Details', style: kSectionTitleSB),
                  ),
                  _headerCircleButton(
                    onTap: () {
                      HapticHelper.impact(HapticImpact.light);
                      final title = program?.title ?? 'program';
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Thanks for sharing $title')),
                      );
                    },
                    child: SvgPicture.asset(
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
                            _toggleBookmark(isBookmarked);
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
              ),
            ),
            Expanded(
              child: AsyncContent(
                asyncValue: programAsync,
                onRetry: () => ref.invalidate(
                  empowermentProgramDetailProvider(widget.programId),
                ),
                builder: (program) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: kScreenPaddingH,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(kCardRadiusMd),
                          child: AspectRatio(
                            aspectRatio: 370 / 203,
                            child:
                                program.image != null &&
                                    program.image!.startsWith('http')
                                ? Image.network(
                                    program.image!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => Image.asset(
                                      'assets/jpgs/campaign_welfare.jpg',
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : Image.asset(
                                    'assets/jpgs/campaign_welfare.jpg',
                                    fit: BoxFit.cover,
                                  ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(program.title, style: kLabel19SB),
                        if (program.startDate != null) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Icon(
                                Icons.calendar_today_outlined,
                                size: 16,
                                color: kTextColor,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Starts ${formatDateLabel(program.startDate)}',
                                style: kCaption12R.copyWith(color: kTextColor),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 16),
                        Text(
                          'ORGANIZERS',
                          style: kCaption10SB.copyWith(
                            color: kSecondaryTextColor,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Jamiat Welfare Committee',
                          style: kCaption12R.copyWith(color: kTextColor),
                        ),
                        const SizedBox(height: 16),
                        Text('About Program', style: kSectionTitleSB),
                        const SizedBox(height: 8),
                        Text(
                          program.description,
                          style: kCaption12R.copyWith(
                            color: kTextColor,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 80),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            kScreenPaddingH,
            8,
            kScreenPaddingH,
            16,
          ),
          child: SizedBox(
            height: 56,
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isApplied || _applyLoading
                  ? null
                  : () {
                      HapticHelper.impact(HapticImpact.medium);
                      _apply();
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryColor,
                foregroundColor: kWhite,
                disabledBackgroundColor: kPrimaryColor.withValues(alpha: 0.6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(kCardRadiusSm),
                ),
                elevation: 0,
              ),
              child: _applyLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: kWhite,
                      ),
                    )
                  : Text(
                      isApplied ? 'Applied' : 'Apply Now',
                      style: kButtonLabelSB,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
