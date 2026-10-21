/// Sites whose terms reserve background playback / picture-in-picture for
/// their own paid offering (YouTube: background play is a Premium feature;
/// see docs/STORE_READINESS.md). On these hosts the browser pauses media when
/// the app goes to the background and does not auto-enter PiP, regardless of
/// the user's media settings. Compiled in (not remotely switchable) so the
/// behaviour reviewed by the stores is the behaviour users get.
const kNoBackgroundPlaybackHosts = {
  'youtube.com',
  'youtu.be',
  'youtube-nocookie.com',
  'music.youtube.com',
};

bool backgroundPlaybackAllowed(Uri? url) {
  final host = url?.host.toLowerCase() ?? '';
  if (host.isEmpty) return true;
  return !kNoBackgroundPlaybackHosts
      .any((h) => host == h || host.endsWith('.$h'));
}
