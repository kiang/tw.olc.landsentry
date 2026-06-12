import 'package:url_launcher/url_launcher.dart';

/// Opens turn-by-turn navigation to the given coordinates: tries the
/// Google Maps navigation intent first, then falls back to the web
/// directions URL for devices without the app.
Future<void> navigateToPoint(double lat, double lng) async {
  final intent = Uri.parse('google.navigation:q=$lat,$lng');
  try {
    if (await launchUrl(intent, mode: LaunchMode.externalApplication)) {
      return;
    }
  } catch (_) {
    // fall through to web fallback
  }
  await launchUrl(
    Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving'),
    mode: LaunchMode.externalApplication,
  );
}
