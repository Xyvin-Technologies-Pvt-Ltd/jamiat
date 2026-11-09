import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:jamiat/src/data/apis/user_api.dart';
import 'package:jamiat/src/data/constants/color_constants.dart';
import 'package:jamiat/src/data/constants/style_constants.dart';
import 'package:jamiat/src/data/models/campaign_model.dart';
import 'package:jamiat/src/data/models/welfare_model.dart';
import 'package:jamiat/src/data/providers/campaign_provider.dart';
import 'package:jamiat/src/data/providers/home_provider.dart';
import 'package:jamiat/src/data/providers/news_provider.dart';
import 'package:jamiat/src/data/providers/welfare_provider.dart';
import 'package:jamiat/src/data/router/nav_router.dart';
import 'package:jamiat/src/data/services/haptic_helper.dart';
import 'package:jamiat/src/data/services/navigation_services.dart';
import 'package:jamiat/src/data/utils/category_mapper.dart';
import 'package:jamiat/src/data/utils/format_helpers.dart';
import 'package:jamiat/src/interfaces/components/async_content.dart';
import 'package:jamiat/src/interfaces/components/campaign_card.dart';
import 'package:jamiat/src/interfaces/components/profile_avatar.dart';

class _QuickAccessItem {
  final String label;
  final String icon;
  final Color background;

  const _QuickAccessItem({
    required this.label,
    required this.icon,
    required this.background,
  });
}

const _quickAccessItems = <_QuickAccessItem>[
  // Figma Home Quick Access order (636:885+)
  _QuickAccessItem(
    label: 'Autopay',
    icon: 'assets/svg/autopay.svg',
    background: Color(0xFFE8F6EE),
  ),
  _QuickAccessItem(
    label: 'Welfare',
    icon: 'assets/svg/welfare.svg',
    background: kQuickWelfareBg,
  ),
  _QuickAccessItem(
    label: 'Events',
    icon: 'assets/svg/events.svg',
    background: kQuickEventsBg,
  ),
  _QuickAccessItem(
    label: 'Market',
    icon: 'assets/svg/market.svg',
    background: kQuickMarketBg,
  ),
  _QuickAccessItem(
    label: 'News',
    icon: 'assets/svg/news.svg',
    background: Color(0xFFEFF5E5),
  ),
  _QuickAccessItem(
    label: 'Programs',
    icon: 'assets/svg/programs.svg',
    background: Color(0xFFF2E7E1),
  ),
];

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  // ── Home spacing system ──────────────────────────────────────────────────
  // Apply gap as top-only padding on each section to avoid double-stacking
  // (A.bottom + B.top). All major section-to-section gaps share one token.
  static const double _sectionGap = 20;
  static const double _screenBottomGap = 32;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isJamiatMember = ref
        .watch(userProfileProvider)
        .maybeWhen(
          data: (user) => user.role == 'jamiat_member',
          orElse: () => false,
        );

    return Scaffold(
      backgroundColor: kWhite,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                kScreenPaddingH,
                16,
                kScreenPaddingH,
                0,
              ),
              child: const _HomeHeader(),
            ),
            Expanded(
              child: RefreshIndicator(
                color: kPrimaryColor,
                onRefresh: () => refreshHomeData(ref),
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          kScreenPaddingH,
                          20,
                          kScreenPaddingH,
                          0,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _ContributionsCard(),
                            if (isJamiatMember) ...[
                              const SizedBox(height: 24),
                              Text('Quick Access', style: kSectionTitleSB),
                              const SizedBox(height: 12),
                            ],
                          ],
                        ),
                      ),
                    ),
                    if (isJamiatMember) const _QuickAccessList(),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          kScreenPaddingH,
                          24,
                          kScreenPaddingH,
                          12,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Active Campaigns',
                                style: kSectionTitleSB,
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                HapticHelper.impact(HapticImpact.light);
                                ref
                                    .read(selectedIndexProvider.notifier)
                                    .updateIndex(1);
                              },
                              child: Text(
                                'See all',
                                style: kCaption12M.copyWith(
                                  color: kPrimaryColor,
                                  height: 1.2,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(child: _ActiveCampaignsSection()),

                    // Jamiat Market Place promo — Figma 2248:718
                    if (isJamiatMember)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.only(
                            left: kScreenPaddingH,
                            right: kScreenPaddingH,
                            top: _sectionGap,
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: ColoredBox(
                              color: const Color(0xFFF4F4F4),
                              child: Stack(
                                clipBehavior: Clip.hardEdge,
                                children: [
                                  Positioned(
                                    right: -9,
                                    top: 0,
                                    bottom: 0,
                                    width: 168,
                                    child: Center(
                                      child: SizedBox(
                                        width: 168,
                                        height: 112,
                                        child: Image.asset(
                                          'assets/pngs/market_banner.png',
                                          fit: BoxFit.cover,
                                          alignment: Alignment.center,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'Jamiat Market Place',
                                          style: kLabel15SB.copyWith(
                                            height: 1.2,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Discover exclusive deals & items',
                                          style: kCaption12R.copyWith(
                                            color: kTextColor,
                                            height: 1.2,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        GestureDetector(
                                          onTap: () {
                                            HapticHelper.impact(
                                              HapticImpact.light,
                                            );
                                            ref
                                                .read(
                                                  selectedIndexProvider
                                                      .notifier,
                                                )
                                                .updateIndex(2);
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              color: kPrimaryColor,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              'Explore',
                                              style: kCaption12M.copyWith(
                                                color: kWhite,
                                                height: 1.2,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                    // Redesigned: Welfare Grid Section
                    if (isJamiatMember)
                      const SliverToBoxAdapter(child: _WelfareGridSection()),

                    // Medical Relief Fund banner — Figma 2248:756 / Frame 2001
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(
                          left: kScreenPaddingH,
                          right: kScreenPaddingH,
                          top: _sectionGap,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: ColoredBox(
                            color: kSecondarySoftBg,
                            child: Stack(
                              clipBehavior: Clip.hardEdge,
                              children: [
                                Positioned(
                                  right: -30,
                                  top: -20,
                                  width: 180,
                                  height: 140,
                                  child: Opacity(
                                    opacity: 0.85,
                                    child: Image.asset(
                                      'assets/pngs/medical_deco_1.png',
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  right: -20,
                                  bottom: -50,
                                  width: 140,
                                  height: 170,
                                  child: Opacity(
                                    opacity: 0.75,
                                    child: Image.asset(
                                      'assets/pngs/medical_deco_3.png',
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: kWhite.withValues(alpha: 0.66),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          'Medical Relief Fund',
                                          style: kCaption10M.copyWith(
                                            color: kTextColor,
                                            height: 1.2,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        'Millions lack healthcare; fund life-saving medicine today.',
                                        style: kSubHeadingSB.copyWith(
                                          color: kTextColor,
                                          height: 1.4,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      GestureDetector(
                                        onTap: () {
                                          HapticHelper.impact(
                                            HapticImpact.light,
                                          );
                                          ref
                                              .read(
                                                selectedIndexProvider.notifier,
                                              )
                                              .updateIndex(1);
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 10,
                                          ),
                                          decoration: BoxDecoration(
                                            color: kSecondaryColor,
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: Text(
                                            'Donate Now',
                                            style: kCaption12M.copyWith(
                                              color: kTextColor,
                                              height: 1.2,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Latest News — Figma Frame 43 (370 × 172)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          kScreenPaddingH,
                          _sectionGap,
                          kScreenPaddingH,
                          8,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Latest News',
                                style: kSectionTitleSB,
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                HapticHelper.impact(HapticImpact.light);
                                NavigationService().pushNamed('NewsList');
                              },
                              child: Text(
                                'See all',
                                style: kCaption12M.copyWith(
                                  color: kPrimaryColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 146,
                        child: Consumer(
                          builder: (context, ref, _) {
                            final newsAsync = ref.watch(newsListProvider);
                            return AsyncContent(
                              asyncValue: newsAsync,
                              onRetry: () => refreshHomeData(ref),
                              builder: (page) {
                                final items = page.items.take(5).toList();
                                if (items.isEmpty) {
                                  return Center(
                                    child: Text(
                                      'No news yet',
                                      style: kEmptyStateM,
                                    ),
                                  );
                                }
                                return ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: kScreenPaddingH,
                                  ),
                                  itemCount: items.length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(width: 8),
                                  itemBuilder: (context, index) {
                                    final item = items[index];
                                    return GestureDetector(
                                      onTap: () {
                                        HapticHelper.impact(HapticImpact.light);
                                        NavigationService().pushNamed(
                                          'NewsDetail',
                                          arguments: {'newsId': item.id},
                                        );
                                      },
                                      child: Container(
                                        width: 323,
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: kWhite,
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          border: Border.all(color: kBorder),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.subTitle ?? 'Announcement',
                                              style: kCaption12R.copyWith(
                                                color: kMutedText,
                                                height: 1.2,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              item.title,
                                              style: kLabel15SB.copyWith(
                                                height: 1.2,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 8),
                                            Expanded(
                                              child: Text(
                                                item.description,
                                                style: kCaption12R.copyWith(
                                                  color: kTextColor,
                                                  height: 1.2,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            Text(
                                              _formatNewsDate(item.createdAt),
                                              style: kCaption10R.copyWith(
                                                color: kMutedText,
                                                height: 1.2,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ),

                    // Empowerment Programs banner — Figma Frame 46
                    if (isJamiatMember)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.only(
                            left: kScreenPaddingH,
                            right: kScreenPaddingH,
                            top: _sectionGap,
                            bottom: _sectionGap,
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: AspectRatio(
                              aspectRatio: 370 / 212,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.asset(
                                    'assets/pngs/empowerment.jpeg',
                                    fit: BoxFit.cover,
                                    alignment: Alignment.center,
                                  ),
                                  const DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                        colors: [
                                          Color(0xE62C3E50),
                                          Color(0x992C3E50),
                                          Color(0x002C3E50),
                                        ],
                                        stops: [0.0, 0.42, 0.72],
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Explore our',
                                          style: kBodyTitleR.copyWith(
                                            color: kWhite,
                                            height: 1.2,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Empowerment\nPrograms',
                                          style: kHeadTitleSB.copyWith(
                                            color: kWhite,
                                            height: 1.15,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        SizedBox(
                                          width: 168,
                                          child: Text(
                                            'for skill building, financial aid requests, and welfare services.',
                                            style: kCaption12R.copyWith(
                                              color: kWhite,
                                              height: 1.2,
                                            ),
                                          ),
                                        ),
                                        const Spacer(),
                                        GestureDetector(
                                          onTap: () {
                                            HapticHelper.impact(
                                              HapticImpact.light,
                                            );
                                            NavigationService().pushNamed(
                                              'EmpowermentPrograms',
                                            );
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 10,
                                            ),
                                            decoration: BoxDecoration(
                                              color: kPrimaryColor,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              'Explore Programs',
                                              style: kCaption12M.copyWith(
                                                color: kWhite,
                                                height: 1.2,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    const SliverToBoxAdapter(
                      child: SizedBox(height: _screenBottomGap),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _ContributeButton(
        onTap: () {
          HapticHelper.impact(HapticImpact.light);
          NavigationService().pushNamed('AutopayView');
        },
      ),
    );
  }
}

class _HomeHeader extends ConsumerWidget {
  const _HomeHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);
    final statsAsync = ref.watch(homeStatsProvider);
    final user = profileAsync.asData?.value ?? statsAsync.value?.user;
    final userName = user?.displayName ?? 'Member';
    final image = user?.image;

    // Figma Home header: avatar 48 · gap 8 · greeting 15/#aaa · name 19 SB · bell 40
    return Row(
      children: [
        ProfileAvatar(imageUrl: image, size: 48),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'As-salamu alaykum',
                style: kBodyTitleR.copyWith(
                  color: kSecondaryTextColor,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                userName,
                style: kSubHeadingSB.copyWith(height: 1.2),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Material(
          color: kWhite.withValues(alpha: 0.08),
          shape: const CircleBorder(
            side: BorderSide(color: kGrey, width: 1.25),
          ),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () {
              HapticHelper.impact(HapticImpact.light);
              NavigationService().pushNamed('Notifications');
            },
            child: SizedBox(
              width: 40,
              height: 40,
              child: Center(
                child: SvgPicture.asset(
                  'assets/svg/bell.svg',
                  width: 24,
                  height: 24,
                  colorFilter: const ColorFilter.mode(
                    kIconMuted,
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ContributionsCard extends ConsumerWidget {
  const _ContributionsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(homeStatsProvider);

    // Figma 2248:620 — bg #edf9f3 · radius 14 · pad 16 · gap 10
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kContributionsBg,
        borderRadius: BorderRadius.circular(kCardRadiusMd),
      ),
      child: AsyncContent(
        asyncValue: statsAsync,
        onRetry: () => refreshHomeData(ref),
        builder: (stats) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'My Contributions',
              style: kBodyTitleSB.copyWith(color: kTextColor, height: 1.2),
            ),
            const SizedBox(height: 4),
            Text(
              'Members-only deals & services',
              style: kCaption12R.copyWith(
                color: kContributionsSubtext,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 10),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _StatTile(
                      label: 'TOTAL DONATED',
                      value: formatRupee(stats.totalDonated),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatTile(
                      label: 'PARTICIPATED CAMPAIGNS',
                      value: '${stats.participatedCampaigns}',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;

  const _StatTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    // Figma stat tiles: pad 16 · radius 8 · label 12 Bold/#6d6d6d · value 19 SB primary
    // Reserve 2 label lines so a wrapping title (e.g. PARTICIPATED CAMPAIGNS)
    // does not push its value below the sibling tile.
    const labelHeight = kSize12 * 1.3 * 2;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(kCardRadiusSm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: labelHeight,
            child: Text(
              label,
              style: kCaption12SB.copyWith(
                color: kMutedText,
                fontWeight: kBold,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: kSubHeadingSB.copyWith(color: kPrimaryColor, height: 1.2),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _QuickAccessList extends ConsumerWidget {
  const _QuickAccessList();

  // Figma 2320:688 — cards 100×126, gap 16
  static const double _cardWidth = 100;
  static const double _cardHeight = 126;
  static const double _cardGap = 16;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = _quickAccessItems;
    return SliverToBoxAdapter(
      child: SizedBox(
        height: _cardHeight,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: kScreenPaddingH),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(width: _cardGap),
          itemBuilder: (context, index) {
            final item = items[index];
            return _QuickAccessCard(
              width: _cardWidth,
              height: _cardHeight,
              item: item,
              onTap: () {
                HapticHelper.impact(HapticImpact.light);
                switch (item.label) {
                  case 'Autopay':
                    NavigationService().pushNamed('AutopayView');
                  case 'Events':
                    NavigationService().pushNamed('Events');
                  case 'Welfare':
                    NavigationService().pushNamed('WelfareProgram');
                  case 'News':
                    NavigationService().pushNamed('NewsList');
                  case 'Programs':
                    NavigationService().pushNamed('EmpowermentPrograms');
                  case 'Market':
                    ref.read(selectedIndexProvider.notifier).updateIndex(2);
                }
              },
            );
          },
        ),
      ),
    );
  }
}

class _QuickAccessCard extends StatelessWidget {
  final double width;
  final double height;
  final _QuickAccessItem item;
  final VoidCallback onTap;

  const _QuickAccessCard({
    required this.width,
    required this.height,
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Material(
        color: item.background,
        borderRadius: BorderRadius.circular(kCardRadiusMd),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: BorderRadius.circular(kCardRadiusMd),
          onTap: onTap,
          child: Stack(
            children: [
              Positioned(
                top: 10,
                left: 12,
                right: 12,
                child: Text(
                  item.label,
                  style: kBodyTitleR.copyWith(height: 1.2),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Positioned(
                right: 12,
                bottom: 10,
                width: 48,
                height: 48,
                child: SvgPicture.asset(
                  item.icon,
                  fit: BoxFit.contain,
                  alignment: Alignment.bottomRight,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActiveCampaignsSection extends ConsumerWidget {
  const _ActiveCampaignsSection();

  // Figma Active Campaigns cards: 241×262 · gap 12 · radius 14
  static const double _cardWidth = 241;
  static const double _cardHeight = 262;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final campaignsAsync = ref.watch(featuredCampaignsProvider);

    return SizedBox(
      height: _cardHeight,
      child: AsyncContent(
        asyncValue: campaignsAsync,
        onRetry: () => refreshHomeData(ref),
        builder: (campaigns) {
          if (campaigns.isEmpty) {
            return Center(
              child: Text('No active campaigns', style: kEmptyStateM),
            );
          }
          return ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: kScreenPaddingH),
            itemCount: campaigns.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              return _CampaignCard(
                width: _cardWidth,
                height: _cardHeight,
                campaign: campaigns[index],
                onTap: () {
                  HapticHelper.impact(HapticImpact.light);
                  NavigationService().pushNamed(
                    'CampaignDetails',
                    arguments: {'campaignId': campaigns[index].id},
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _CampaignCard extends StatelessWidget {
  final double width;
  final double height;
  final CampaignModel campaign;
  final VoidCallback onTap;

  const _CampaignCard({
    required this.width,
    required this.height,
    required this.campaign,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasTarget = campaign.hasTargetAmount;
    final progress = hasTarget
        ? (campaign.collectedAmount / campaign.targetAmount).clamp(0.0, 1.0)
        : 0.0;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: width,
        height: height,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(kCardRadiusMd),
          child: Stack(
            fit: StackFit.expand,
            children: [
              campaignCoverImage(
                campaign.coverImage,
                placeholderIconSize: 36,
                showPlaceholderLabel: false,
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x00000000), Color(0xE6000000)],
                    stops: [0.664, 1],
                  ),
                ),
              ),
              Positioned(
                top: 16,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xCCD5D5D5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    CategoryMapper.toUi(campaign.category),
                    style: kCaption10M.copyWith(color: kTextColor, height: 1.2),
                  ),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      campaign.title,
                      style: kBodyTitleSB.copyWith(color: kWhite, height: 1.2),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (hasTarget) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(1),
                        child: LinearProgressIndicator(
                          value: progress.toDouble(),
                          minHeight: 4,
                          backgroundColor: const Color(0x66D9D9D9),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            kPrimaryColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: formatRupee(campaign.collectedAmount),
                              style: kCaption12SB.copyWith(
                                color: kWhite,
                                height: 1.2,
                              ),
                            ),
                            TextSpan(
                              text: ' / ',
                              style: kCaption12M.copyWith(
                                color: kWhite,
                                height: 1.2,
                              ),
                            ),
                            TextSpan(
                              text: 'of ${formatRupee(campaign.targetAmount)}',
                              style: kCaption12R.copyWith(
                                color: kWhite,
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WelfareGridSection extends ConsumerWidget {
  const _WelfareGridSection();

  // Uniform grid constants — single source of truth for spacing and sizing.
  static const int _columns = 3;
  static const double _tileGap = 12;
  // childAspectRatio: width / height. 113 wide × 128 tall ≈ 0.88.
  static const double _tileAspectRatio = 113 / 128;

  static const _fallbackColors = [
    Color(0xFFFFFBEB),
    Color(0xFFFFF1F2),
    Color(0xFFF0FDF4),
    Color(0xFFEFF6FF),
    Color(0xFFFDF4FF),
    Color(0xFFF5EBE6),
  ];

  static const _localAssetByKeyword = <String, String>{
    'maktab': 'assets/pngs/maktab.png',
    'ulama': 'assets/pngs/ulama.png',
    'youth': 'assets/pngs/youth_club.png',
    'model': 'assets/pngs/model_village.png',
    'study': 'assets/pngs/study_center.png',
    'jem': 'assets/pngs/jem.png',
  };

  Color _cardColor(WelfareServiceModel service, int index) {
    final raw = service.accentColor?.trim();
    if (raw != null && raw.isNotEmpty) {
      var hex = raw.replaceFirst('#', '');
      if (hex.length == 6) hex = 'FF$hex';
      final value = int.tryParse(hex, radix: 16);
      if (value != null) {
        return Color(value).withValues(alpha: 0.18);
      }
    }
    return _fallbackColors[index % _fallbackColors.length];
  }

  String? _localAsset(String name) {
    final lower = name.toLowerCase();
    for (final entry in _localAssetByKeyword.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(welfareListProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kScreenPaddingH),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Explore our Social & Welfare Services.',
            textAlign: TextAlign.center,
            style: kSectionTitleSB.copyWith(height: 1.2),
          ),
          const SizedBox(height: 8),
          Text(
            'Dedicated programs focused on supporting and empowering our community.',
            textAlign: TextAlign.center,
            style: kCaption12R.copyWith(color: kMutedText, height: 1.35),
          ),
          const SizedBox(height: 16),
          Center(
            child: GestureDetector(
              onTap: () {
                HapticHelper.impact(HapticImpact.light);
                NavigationService().pushNamed('WelfareProgram');
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: kPrimaryColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Explore All',
                  style: kCaption12M.copyWith(color: kWhite, height: 1.2),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          AsyncContent(
            asyncValue: listAsync,
            onRetry: () => ref.invalidate(welfareListProvider),
            builder: (page) {
              final services = page.items;
              if (services.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Text(
                    'No welfare services available yet.',
                    textAlign: TextAlign.center,
                    style: kEmptyStateM,
                  ),
                );
              }

              final preview = services.take(6).toList();

              // GridView.count keeps all tiles equal width, equal height, and
              // equal gaps — no manual column splitting or height maps needed.
              return GridView.count(
                crossAxisCount: _columns,
                crossAxisSpacing: _tileGap,
                mainAxisSpacing: _tileGap,
                childAspectRatio: _tileAspectRatio,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (var i = 0; i < preview.length; i++)
                    _WelfareServiceCard(
                      service: preview[i],
                      bgColor: _cardColor(preview[i], i),
                      fallbackAsset: _localAsset(preview[i].name),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _WelfareServiceCard extends StatelessWidget {
  final WelfareServiceModel service;
  final Color bgColor;
  final String? fallbackAsset;

  const _WelfareServiceCard({
    required this.service,
    required this.bgColor,
    this.fallbackAsset,
  });

  Widget _image() {
    final icon = service.icon;
    if (icon != null && icon.startsWith('http')) {
      return Image.network(
        icon,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => fallbackAsset != null
            ? Image.asset(fallbackAsset!, fit: BoxFit.contain)
            : const Icon(Icons.volunteer_activism_outlined, color: kMutedText),
      );
    }
    if (fallbackAsset != null) {
      return Image.asset(fallbackAsset!, fit: BoxFit.contain);
    }
    return const Icon(Icons.volunteer_activism_outlined, color: kMutedText);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticHelper.impact(HapticImpact.light);
        NavigationService().pushNamed(
          'WelfareDetails',
          arguments: {'welfareId': service.id},
        );
      },
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        // Column layout: label pinned at top, image fills remaining space.
        // No Positioned/Stack needed — the GridView cell provides the fixed size.
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                service.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: kCaption12SB.copyWith(color: kTextColor, height: 1.2),
              ),
              const SizedBox(height: 6),
              Expanded(child: _image()),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContributeButton extends StatelessWidget {
  final VoidCallback onTap;

  const _ContributeButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    // Figma Contribute FAB: gradient #FFDE79→#FBBD05 · r14 · text #5D5D5D 12 SB
    return Material(
      color: Colors.transparent,
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(kCardRadiusMd),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(kCardRadiusMd),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFFDE79), kSecondaryColor],
            ),
            boxShadow: [
              BoxShadow(
                color: kBlack.withValues(alpha: 0.12),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Contribute',
                  style: kCaption12SB.copyWith(color: kText2Color, height: 1.2),
                ),
                const SizedBox(width: 8),
                SvgPicture.asset(
                  'assets/svg/donate.svg',
                  width: 20,
                  height: 20,
                  colorFilter: const ColorFilter.mode(
                    kText2Color,
                    BlendMode.srcIn,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _formatNewsDate(DateTime? date) {
  if (date == null) return '';
  final local = date.toLocal();
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${local.day} ${months[local.month - 1]} ${local.year}';
}
