import 'package:flutter_test/flutter_test.dart';
import 'package:vela_browser/media/media_policy.dart';

void main() {
  test('background playback/PiP are not offered on YouTube hosts', () {
    for (final u in [
      'https://m.youtube.com/watch?v=x',
      'https://www.youtube.com/',
      'https://youtu.be/x',
      'https://music.youtube.com/',
      'https://www.youtube-nocookie.com/embed/x',
    ]) {
      expect(backgroundPlaybackAllowed(Uri.parse(u)), isFalse, reason: u);
    }
    expect(backgroundPlaybackAllowed(Uri.parse('https://notyoutube.com/')), isTrue);
    expect(backgroundPlaybackAllowed(Uri.parse('https://example.com/a.mp3')), isTrue);
    expect(backgroundPlaybackAllowed(null), isTrue);
  });
}
