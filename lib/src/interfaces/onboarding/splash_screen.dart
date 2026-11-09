import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import 'package:jamiat/src/data/providers/screen_data_providers.dart';
import 'package:jamiat/src/data/services/auth_session_service.dart';
import 'package:jamiat/src/data/services/deep_link_service.dart';
import 'package:jamiat/src/data/services/navigation_services.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _entranceController;
  late AnimationController _shimmerController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<double> _blurAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _scaleAnimation = TweenSequence([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.5,
          end: 1.1,
        ).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 70,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.1,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 30,
      ),
    ]).animate(_entranceController);

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _blurAnimation = Tween<double>(begin: 15.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
      ),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _entranceController,
            curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
          ),
        );

    _entranceController.forward();

    _navigateToNext();
  }

  Future<void> _navigateToNext() async {
    final routeFuture = ref
        .read(authSessionServiceProvider)
        .resolveInitialRoute();
    await Future.delayed(const Duration(seconds: 3));
    final route = await routeFuture;
    if (!mounted) return;
    NavigationService().pushNamedAndRemoveUntil(route);
    // Only open shared campaigns once the user can enter the app.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (route == 'navBar') {
        DeepLinkService.instance.markReady();
      } else {
        DeepLinkService.instance.resetReady();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _entranceController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = ref.watch(screenSizeProvider);

    // Figma: collage ~95.5% of frame width (≈8px inset on 375 design).
    final horizontalInset = screenSize.responsivePadding(8);

    // Logo asset includes transparent padding (~9.5% of asset width).
    // Figma visual logo ≈ 37.7% of width → asset width ≈ 41.5%.
    final logoWidth = screenSize.isTablet
        ? screenSize.responsiveSize(156)
        : screenSize.widthPercent(41.5).clamp(0.0, double.infinity);

    // Figma visual gap collage → logo ≈ 4.7% of frame height.
    // Subtract the logo asset's transparent top pad so the visible gap matches.
    const logoAssetHeight = 288.0;
    const logoAssetWidth = 632.0;
    const logoTrimTop = 48.0;
    final logoDisplayHeight = logoWidth * (logoAssetHeight / logoAssetWidth);
    final logoTopPad = logoDisplayHeight * (logoTrimTop / logoAssetHeight);
    final collageLogoGap = (screenSize.heightPercent(4.7) - logoTopPad).clamp(
      0.0,
      double.infinity,
    );

    return Scaffold(
      backgroundColor: Colors.white,
      body: AnimatedBuilder(
        animation: _entranceController,
        builder: (context, child) {
          return SlideTransition(
            position: _slideAnimation,
            child: FadeTransition(
              opacity: _opacityAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(
                    sigmaX: _blurAnimation.value,
                    sigmaY: _blurAnimation.value,
                  ),
                  child: SizedBox.expand(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalInset,
                      ),
                      child: Column(
                        children: [
                          // Figma top ≈ 25%, bottom ≈ 26.6% — near-equal spacers.
                          const Spacer(flex: 25),
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: screenSize.isTablet
                                  ? screenSize.responsiveSize(420)
                                  : double.infinity,
                            ),
                            child: const _SplashCollage(),
                          ),
                          SizedBox(height: collageLogoGap),
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(
                                width: logoWidth,
                                child: Image.asset(
                                  'assets/pngs/jamiat_logo.png',
                                  fit: BoxFit.contain,
                                  filterQuality: FilterQuality.high,
                                ),
                              ),
                              if (_entranceController.value > 0.5)
                                Shimmer.fromColors(
                                  baseColor: Colors.transparent,
                                  highlightColor: Colors.white.withValues(
                                    alpha: 0.8,
                                  ),
                                  period: const Duration(milliseconds: 1500),
                                  direction: ShimmerDirection.ltr,
                                  child: SizedBox(
                                    width: logoWidth,
                                    child: Image.asset(
                                      'assets/pngs/jamiat_logo.png',
                                      fit: BoxFit.contain,
                                      filterQuality: FilterQuality.high,
                                      color: Colors.white.withValues(
                                        alpha: 200 / 255,
                                      ),
                                      colorBlendMode: BlendMode.srcIn,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const Spacer(flex: 27),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Staggered 3×2 collage matching the original splash artboard (1484×1288).
/// Positions 1 (bottom-left) and 2 (bottom-right) use distinct photo assets.
class _SplashCollage extends StatelessWidget {
  const _SplashCollage();

  // Fractions measured from the original jamiat_splashimage.png artboard.
  static const double _aspect = 1484 / 1288;
  static const double _tileW = 0.304582;
  // Corner radius ≈ 46px on a 451px tile.
  static const double _radiusRatio = 46 / 451;

  static const _TileSpec _tl = _TileSpec(
    left: 0.0,
    top: 0.096273,
    width: _tileW,
    height: 0.397516,
    asset: 'assets/pngs/splash_tile_tl.png',
  );
  static const _TileSpec _tm = _TileSpec(
    left: 0.347709,
    top: 0.0,
    width: _tileW,
    height: 0.419255,
    asset: 'assets/pngs/splash_tile_tm.png',
  );
  static const _TileSpec _tr = _TileSpec(
    left: 0.695418,
    top: 0.096273,
    width: _tileW,
    height: 0.310559,
    asset: 'assets/pngs/splash_tile_tr.png',
  );
  // Marked "1" — hands / teamwork photo.
  static const _TileSpec _bl = _TileSpec(
    left: 0.0,
    top: 0.568323,
    width: _tileW,
    height: 0.310559,
    asset: 'assets/pngs/splash1.jpeg',
    cover: true,
  );
  static const _TileSpec _bm = _TileSpec(
    left: 0.347709,
    top: 0.518634,
    width: _tileW,
    height: 0.481366,
    asset: 'assets/pngs/splash_tile_bm.png',
  );
  // Marked "2" — child studying photo.
  static const _TileSpec _br = _TileSpec(
    left: 0.695418,
    top: 0.481366,
    width: _tileW,
    height: 0.397516,
    asset: 'assets/pngs/splash2.png',
    cover: true,
  );

  static const List<_TileSpec> _tiles = [_tl, _tm, _tr, _bl, _bm, _br];

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: _aspect,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          final radius = BorderRadius.circular(w * _tileW * _radiusRatio);

          return Stack(
            clipBehavior: Clip.none,
            children: [
              for (final tile in _tiles)
                Positioned(
                  left: w * tile.left,
                  top: h * tile.top,
                  width: w * tile.width,
                  height: h * tile.height,
                  child: tile.cover
                      ? ClipRRect(
                          borderRadius: radius,
                          child: Image.asset(
                            tile.asset,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            filterQuality: FilterQuality.high,
                          ),
                        )
                      : Image.asset(
                          tile.asset,
                          fit: BoxFit.fill,
                          filterQuality: FilterQuality.high,
                        ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _TileSpec {
  const _TileSpec({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.asset,
    this.cover = false,
  });

  final double left;
  final double top;
  final double width;
  final double height;
  final String asset;
  final bool cover;
}
