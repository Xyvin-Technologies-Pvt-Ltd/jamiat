import 'dart:developer';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jamiat/src/data/constants/color_constants.dart';
import 'package:jamiat/src/data/constants/style_constants.dart';
import 'package:jamiat/src/data/providers/screen_data_providers.dart';
import 'package:jamiat/src/data/services/auth_session_service.dart';
import 'package:jamiat/src/data/services/deep_link_service.dart';
import 'package:jamiat/src/data/services/navigation_services.dart';
import 'package:jamiat/src/data/services/version_check_service.dart';
import 'package:jamiat/src/interfaces/components/primarybutton.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';

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

  bool _isAppUpdateRequired = false;
  bool _forceUpdate = false;
  bool _hasVersionCheckError = false;
  String _errorMessage = '';
  String? _updateLink;
  bool _isRetrying = false;

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

    _bootstrap();
  }

  /// Store version gate first, then auth bootstrap. Never navigates away when
  /// update is required or settings are unreachable.
  Future<void> _bootstrap() async {
    log('Splash bootstrap starting', name: 'SplashScreen');
    final startedAt = DateTime.now();
    final gate = await ref.read(versionCheckServiceProvider).check();

    if (!mounted) return;

    switch (gate.outcome) {
      case VersionGateOutcome.serverError:
        log('Navigation blocked — settings error', name: 'SplashScreen');
        setState(() {
          _hasVersionCheckError = true;
          _isAppUpdateRequired = true;
          _forceUpdate = false;
          _errorMessage =
              'Unable to reach the server. Check your connection and try again.';
          _updateLink = null;
          _isRetrying = false;
        });
        return;

      case VersionGateOutcome.updateRequired:
        log(
          'Navigation blocked — update required '
          '(force=${gate.isForce})',
          name: 'SplashScreen',
        );
        setState(() {
          _hasVersionCheckError = false;
          _isAppUpdateRequired = true;
          _forceUpdate = gate.isForce;
          _errorMessage = gate.updateMessage;
          _updateLink = gate.applink;
          _isRetrying = false;
        });
        return;

      case VersionGateOutcome.upToDate:
        log('Version OK — continuing auth bootstrap', name: 'SplashScreen');
        setState(() {
          _hasVersionCheckError = false;
          _isAppUpdateRequired = false;
          _forceUpdate = false;
          _errorMessage = '';
          _updateLink = null;
          _isRetrying = false;
        });
        await _navigateAfterAuth(startedAt: startedAt);
    }
  }

  Future<void> _navigateAfterAuth({DateTime? startedAt}) async {
    final routeFuture = ref
        .read(authSessionServiceProvider)
        .resolveInitialRoute();

    // Keep a ~3s splash when coming from cold start; skip when user tapped Later.
    if (startedAt != null) {
      const minSplash = Duration(seconds: 3);
      final elapsed = DateTime.now().difference(startedAt);
      final remaining = minSplash - elapsed;
      if (remaining > Duration.zero) {
        await Future.delayed(remaining);
      }
    }

    final route = await routeFuture;
    if (!mounted) return;
    if (_isAppUpdateRequired) {
      log(
        'Navigation skipped — update UI still active',
        name: 'SplashScreen',
      );
      return;
    }
    log('Navigating to $route', name: 'SplashScreen');
    NavigationService().pushNamedAndRemoveUntil(route);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (route == 'navBar') {
        DeepLinkService.instance.markReady();
      } else {
        DeepLinkService.instance.resetReady();
      }
    });
  }

  Future<void> _openStore() async {
    final link = _updateLink;
    log('Opening store link: $link', name: 'SplashScreen');
    if (link == null || link.isEmpty) return;
    try {
      await launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication);
    } catch (e) {
      log('Failed to open store: $e', name: 'SplashScreen');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open the store link')),
      );
    }
  }

  Future<void> _onLater() async {
    log('Optional update skipped (Later)', name: 'SplashScreen');
    setState(() {
      _isAppUpdateRequired = false;
      _forceUpdate = false;
      _errorMessage = '';
      _updateLink = null;
    });
    await _navigateAfterAuth();
  }

  Future<void> _onRetry() async {
    if (_isRetrying) return;
    log('Retrying version check', name: 'SplashScreen');
    setState(() {
      _isRetrying = true;
      _hasVersionCheckError = false;
      _isAppUpdateRequired = false;
      _errorMessage = '';
    });
    await _bootstrap();
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

    return PopScope(
      canPop: !_forceUpdate && !_hasVersionCheckError,
      child: Scaffold(
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
                            if (_isAppUpdateRequired) ...[
                              SizedBox(height: screenSize.responsiveSize(24)),
                              _SplashUpdatePanel(
                                hasError: _hasVersionCheckError,
                                forceUpdate: _forceUpdate,
                                message: _errorMessage,
                                isRetrying: _isRetrying,
                                onRetry: _onRetry,
                                onLater: _onLater,
                                onUpdateNow: _openStore,
                              ),
                              SizedBox(height: screenSize.responsiveSize(24)),
                            ] else
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
      ),
    );
  }
}

class _SplashUpdatePanel extends StatelessWidget {
  const _SplashUpdatePanel({
    required this.hasError,
    required this.forceUpdate,
    required this.message,
    required this.isRetrying,
    required this.onRetry,
    required this.onLater,
    required this.onUpdateNow,
  });

  final bool hasError;
  final bool forceUpdate;
  final String message;
  final bool isRetrying;
  final VoidCallback onRetry;
  final VoidCallback onLater;
  final VoidCallback onUpdateNow;

  @override
  Widget build(BuildContext context) {
    final accent = hasError ? const Color(0xFFC62828) : kPrimaryColor;
    final title = hasError
        ? 'Server unavailable'
        : (message.isNotEmpty ? message : 'Update Available');
    final subtitle = hasError
        ? 'Please check your internet connection and try again.'
        : forceUpdate
        ? 'This update is required to continue using the app.'
        : 'A new version is available. Update now for the best experience.';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.06),
          border: Border.all(color: accent.withValues(alpha: 0.22)),
          borderRadius: BorderRadius.circular(kCardRadiusSm),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasError ? Icons.cloud_off_outlined : Icons.system_update_outlined,
              color: accent,
              size: 32,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: kBodyTitleSB.copyWith(color: kTextColor, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: kBodyTitleR.copyWith(
                color: kSecondaryTextColor,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            if (hasError)
              primaryButton(
                label: 'Retry',
                onPressed: isRetrying ? null : onRetry,
                isLoading: isRetrying,
                buttonHeight: 52,
              )
            else
              Row(
                children: [
                  if (!forceUpdate) ...[
                    Expanded(
                      child: primaryButton(
                        label: 'Later',
                        onPressed: onLater,
                        buttonColor: kWhite,
                        labelColor: kPrimaryColor,
                        sideColor: kPrimaryColor,
                        buttonHeight: 52,
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: primaryButton(
                      label: 'Update Now',
                      onPressed: onUpdateNow,
                      buttonHeight: 52,
                    ),
                  ),
                ],
              ),
          ],
        ),
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
