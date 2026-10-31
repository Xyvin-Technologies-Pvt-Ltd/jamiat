import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:jamiat/src/data/apis/user_api.dart';
import 'package:jamiat/src/data/constants/color_constants.dart';
import 'package:jamiat/src/data/constants/style_constants.dart';
import 'package:jamiat/src/data/router/nav_router.dart';
import 'package:jamiat/src/data/services/haptic_helper.dart';
import 'package:jamiat/src/data/services/get_fcm.dart';
import 'package:jamiat/src/data/services/deep_link_service.dart';
import 'package:jamiat/src/interfaces/animations/page_load_animation.dart';
import 'package:jamiat/src/interfaces/components/profile_avatar.dart';
import 'package:jamiat/src/interfaces/main_pages/donate.dart';
import 'package:jamiat/src/interfaces/main_pages/home.dart';
import 'package:jamiat/src/interfaces/main_pages/market.dart';
import 'package:jamiat/src/interfaces/main_pages/profile.dart';

class NavBar extends ConsumerStatefulWidget {
  const NavBar({super.key});

  @override
  ConsumerState<NavBar> createState() => _NavBarState();
}

class _NavTab {
  final int pageIndex;
  final String icon;
  final String label;

  const _NavTab({
    required this.pageIndex,
    required this.icon,
    required this.label,
  });
}

class _NavBarState extends ConsumerState<NavBar> {
  static const List<_NavTab> _allTabs = [
    _NavTab(pageIndex: 0, icon: 'assets/svg/home_icon.svg', label: 'Home'),
    _NavTab(pageIndex: 1, icon: 'assets/svg/donate.svg', label: 'Donate'),
    _NavTab(pageIndex: 2, icon: 'assets/svg/market_icon.svg', label: 'Market'),
    _NavTab(
      pageIndex: 3,
      icon: 'assets/svg/profile_icon.svg',
      label: 'Profile',
    ),
  ];

  List<_NavTab> _tabsForRole(bool isJamiatMember) {
    if (isJamiatMember) return _allTabs;
    return _allTabs.where((tab) => tab.pageIndex != 2).toList();
  }

  @override
  void initState() {
    super.initState();
    DeepLinkService.instance.onSelectNavTab = (index) {
      if (!mounted) return;
      ref.read(selectedIndexProvider.notifier).updateIndex(index);
    };
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      DeepLinkService.instance.consumePendingNavTab();
      await getFcmToken(context, ref);
    });
  }

  @override
  void dispose() {
    DeepLinkService.instance.onSelectNavTab = null;
    super.dispose();
  }

  static const List<Widget> _pages = <Widget>[
    HomePage(),
    DonatePage(),
    MarketPage(),
    ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);
    final isJamiatMember = profileAsync.maybeWhen(
      data: (user) => user.role == 'jamiat_member',
      orElse: () => false,
    );
    final profileImageUrl = profileAsync.maybeWhen(
      data: (user) => user.image,
      orElse: () => null,
    );
    final tabs = _tabsForRole(isJamiatMember);
    final selectedIndex = ref.watch(selectedIndexProvider);

    ref.listen(userProfileProvider, (previous, next) {
      next.whenData((user) {
        if (user.role != 'jamiat_member' &&
            ref.read(selectedIndexProvider) == 2) {
          ref.read(selectedIndexProvider.notifier).updateIndex(0);
        }
      });
    });

    final pageIndex = !isJamiatMember && selectedIndex == 2 ? 0 : selectedIndex;

    return PopScope(
      canPop: pageIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        log('inside navbar popscope', name: 'NavBar');
        if (pageIndex != 0) {
          ref.read(selectedIndexProvider.notifier).updateIndex(0);
        }
      },
      child: Scaffold(
        backgroundColor: kWhite,
        // Replay the entrance each time a tab is selected. The bar stays fixed.
        body: PageLoadAnimation(
          key: ValueKey(pageIndex),
          child: _pages.elementAt(pageIndex),
        ),
        // Figma BottomNav: shadow 7/-1/18 @ 18% · pt 8 · pb 24 · gap 6 · label 10
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: kWhite,
            boxShadow: [
              BoxShadow(
                color: kBlack.withValues(alpha: 0.18),
                blurRadius: 18,
                offset: const Offset(7, -1),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              child: Row(
                children: List.generate(tabs.length, (index) {
                  final tab = tabs[index];
                  final isSelected = selectedIndex == tab.pageIndex;
                  final color = isSelected ? kPrimaryColor : kIconMuted;

                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        if (selectedIndex == tab.pageIndex) return;
                        HapticHelper.impact(HapticImpact.light);
                        ref
                            .read(selectedIndexProvider.notifier)
                            .updateIndex(tab.pageIndex);
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _NavBarIcon(
                              tab: tab,
                              color: color,
                              isSelected: isSelected,
                              profileImageUrl: profileImageUrl,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              tab.label,
                              style: (isSelected ? kNavLabelM : kNavLabelR)
                                  .copyWith(color: color),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavBarIcon extends StatelessWidget {
  const _NavBarIcon({
    required this.tab,
    required this.color,
    required this.isSelected,
    this.profileImageUrl,
  });

  final _NavTab tab;
  final Color color;
  final bool isSelected;
  final String? profileImageUrl;

  static const double _profileSize = 24;

  @override
  Widget build(BuildContext context) {
    if (tab.pageIndex != 3) {
      return SvgPicture.asset(
        tab.icon,
        width: 24,
        height: 24,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      );
    }

    // Figma active Profile tab: 24×24 avatar with 2px primary border
    final avatar = ProfileAvatar(
      imageUrl: profileImageUrl,
      size: _profileSize,
      backgroundColor: Colors.transparent,
      iconColor: color,
    );

    if (!isSelected) return avatar;

    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: kPrimaryColor, width: 2),
      ),
      child: ClipOval(child: avatar),
    );
  }
}
