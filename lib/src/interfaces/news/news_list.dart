import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jamiat/src/data/constants/color_constants.dart';
import 'package:jamiat/src/data/constants/style_constants.dart';
import 'package:jamiat/src/data/providers/news_provider.dart';
import 'package:jamiat/src/data/services/haptic_helper.dart';
import 'package:jamiat/src/data/services/navigation_services.dart';
import 'package:jamiat/src/data/utils/format_helpers.dart';
import 'package:jamiat/src/interfaces/components/async_content.dart';

class NewsListScreen extends ConsumerStatefulWidget {
  const NewsListScreen({super.key});

  @override
  ConsumerState<NewsListScreen> createState() => _NewsListScreenState();
}

class _NewsListScreenState extends ConsumerState<NewsListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int _page = 1;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      _searchDebounce?.cancel();
      final query = _searchController.text.trim();
      if (query.isEmpty) {
        _applySearch();
      } else {
        _searchDebounce = Timer(
          const Duration(milliseconds: 300),
          _applySearch,
        );
      }
    });
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

  Widget _thumb(String? url) {
    if (url != null && url.startsWith('http')) {
      return Image.network(
        url,
        width: 90,
        height: 90,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(
          width: 90,
          height: 90,
          color: kScreenBg,
          child: const Icon(Icons.image_outlined, color: kMutedText),
        ),
      );
    }
    return Image.asset(
      url ?? 'assets/jpgs/campaign_education.jpg',
      width: 90,
      height: 90,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => Container(
        width: 90,
        height: 90,
        color: kScreenBg,
        child: const Icon(Icons.image_outlined, color: kMutedText),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final searchProvider = newsSearchProvider((
      search: _searchQuery,
      page: _page,
    ));
    final newsAsync = ref.watch(searchProvider);

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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          HapticHelper.impact(HapticImpact.light);
                          Navigator.pop(context);
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
                      Text('News & Announcements', style: kSectionTitleSB),
                    ],
                  ),
                  // Container(
                  //   width: 40,
                  //   height: 40,
                  //   decoration: BoxDecoration(
                  //     shape: BoxShape.circle,
                  //     color: kWhite.withValues(alpha: 0.08),
                  //     border: Border.all(color: kGrey, width: 1.25),
                  //   ),
                  //   child: const Icon(Icons.more_vert, color: kMutedText, size: 20),
                  // ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: kScreenPaddingH),
              child: Container(
                decoration: BoxDecoration(
                  color: kWhite,
                  borderRadius: BorderRadius.circular(kCardRadiusMd),
                  border: Border.all(color: kCardBorder, width: 1),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Icon(Icons.search, color: kMutedText, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => _applySearch(),
                        style: kBodyTitleR.copyWith(color: kTextColor),
                        decoration: InputDecoration(
                          hintText: 'Search for news',
                          hintStyle: kBodyTitleR.copyWith(
                            color: kMutedText,
                            fontSize: 15,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 16,
                          ),
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
                asyncValue: newsAsync,
                onRetry: () => ref.invalidate(searchProvider),
                builder: (page) {
                  final filtered = page.items;
                  if (filtered.isEmpty) {
                    return Center(
                      child: Text(
                        'No news articles found',
                        style: kEmptyStateM,
                      ),
                    );
                  }
                  return Column(
                    children: [
                      Expanded(
                        child: ListView.builder(
                          key: ValueKey((_searchQuery, _page)),
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(
                            horizontal: kScreenPaddingH,
                          ),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final item = filtered[index];
                            return GestureDetector(
                              onTap: () {
                                HapticHelper.impact(HapticImpact.light);
                                NavigationService().pushNamed(
                                  'NewsDetail',
                                  arguments: {
                                    'newsId': item.id,
                                    'newsIds':
                                        filtered.map((e) => e.id).toList(),
                                  },
                                );
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: kWhite,
                                  borderRadius: BorderRadius.circular(
                                    kCardRadiusMd,
                                  ),
                                  border: Border.all(color: kBorder, width: 1),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: _thumb(item.image),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.title,
                                            style: kBodyTitleB.copyWith(
                                              color: kTextColor,
                                              fontSize: 15,
                                              height: 1.2,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            item.subTitle ?? item.description,
                                            style: kCaption12R.copyWith(
                                              color: kSecondaryTextColor,
                                              height: 1.2,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            formatDateLabel(item.createdAt),
                                            style: kCaption10SB.copyWith(
                                              color: kText2Color,
                                            ),
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
