import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../app_providers.dart';
import '../config/remote_config.dart';
import '../l10n/l10n.dart';

/// A banner in app UI (never over web content). Takes no space until an ad
/// has actually loaded; failures/no-fill simply leave it collapsed.
class BannerSlot extends ConsumerStatefulWidget {
  const BannerSlot({super.key, required this.placement});
  final AdPlacementId placement;

  @override
  ConsumerState<BannerSlot> createState() => _BannerSlotState();
}

class _BannerSlotState extends ConsumerState<BannerSlot> {
  BannerAd? _ad;
  bool _loaded = false;
  String? _unit;
  int? _width;

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  Future<void> _load(String unit, int width) async {
    _ad?.dispose();
    _ad = null;
    _loaded = false;
    _unit = unit;
    _width = width;
    final size =
        await AdSize.getLargeAnchoredAdaptiveBannerAdSize(width);
    if (!mounted || size == null || _unit != unit) return;
    final ad = BannerAd(
      adUnitId: unit,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
          if (mounted) setState(() => _ad = null);
        },
      ),
    );
    _ad = ad;
    await ad.load();
  }

  @override
  Widget build(BuildContext context) {
    final ads = ref.watch(adsProvider);
    final unit = ads.bannerUnit(widget.placement);
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth.truncate();
      if (unit == null) {
        if (_ad != null) {
          _ad!.dispose();
          _ad = null;
          _loaded = false;
          _unit = null;
        }
        return const SizedBox.shrink();
      }
      if (unit != _unit || width != _width) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _load(unit, width);
        });
      }
      final ad = _ad;
      if (ad == null || !_loaded) return const SizedBox.shrink();
      return Semantics(
        label: context.l10n.adLabel,
        container: true,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 12, top: 4),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(context.l10n.adLabel,
                  style: Theme.of(context).textTheme.labelSmall),
            ),
          ),
          SizedBox(
            width: ad.size.width.toDouble(),
            height: ad.size.height.toDouble(),
            child: AdWidget(ad: ad),
          ),
        ]),
      );
    });
  }
}
