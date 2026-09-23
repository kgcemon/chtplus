import 'package:cht_plus/core/utils/deep_links.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every link below is one the backend actually produces — taken from
/// `lib/notify.js` call sites and the chat route's `sendPush`. If the server
/// ever changes one of these, a test here should fail rather than a tap
/// silently landing on the wrong screen.
void main() {
  group('links the backend sends', () {
    test('a chat message opens that conversation', () {
      expect(appRouteForLink('/chat/12'), '/chat/12');
    });

    test('push sends the same link absolute, which resolves the same way', () {
      expect(appRouteForLink('https://chtplus.xyz/chat/12'), '/chat/12');
      expect(appRouteForLink('https://www.chtplus.xyz/chat/12'), '/chat/12');
    });

    test('a donor review or like opens the donor, not the donor list', () {
      expect(appRouteForLink('/donors?open=bd_1700000000000'),
          '/donors/bd_1700000000000');
    });

    test('a service review or approval opens the service detail', () {
      expect(appRouteForLink('/my-services?open=svc_17000'), '/services/svc_17000');
    });

    test('an approved listing opens that listing', () {
      expect(appRouteForLink('/marketplace/listing/ml_17000'),
          '/marketplace/listing/ml_17000');
    });

    test("a follower's new service opens their profile", () {
      expect(appRouteForLink('/u/u_1700000000000'), '/u/u_1700000000000');
    });

    test('serial and coin decisions open their own screens', () {
      expect(appRouteForLink('/my-appointments'), '/my-appointments');
      expect(appRouteForLink('/coins'), '/coins');
    });
  });

  group('links without an ?open= id fall back to the list', () {
    test('donors', () => expect(appRouteForLink('/donors'), '/donors'));
    test('my services',
        () => expect(appRouteForLink('/my-services'), '/my-services'));
    test('my listings',
        () => expect(appRouteForLink('/my-listings'), '/my-listings'));
  });

  group('links the app has no screen for', () {
    test('an empty or missing link gives null', () {
      expect(appRouteForLink(null), isNull);
      expect(appRouteForLink(''), isNull);
      expect(appRouteForLink('   '), isNull);
    });

    test('an unknown site path gives null', () {
      expect(appRouteForLink('/admin/settings'), isNull);
      expect(appRouteForLink('/privacy-policy'), isNull);
    });

    test('a bare prefix with no id is not treated as a detail route', () {
      expect(appRouteForLink('/u/'), isNull);
      expect(appRouteForLink('/chat/'), '/chat');
    });

    test('an off-site link is never opened in the app', () {
      expect(appRouteForLink('https://example.com/chat/12'), isNull);
      expect(appRouteForLink('https://evil.test/u/u_1'), isNull);
    });
  });

  test('the biodata list path maps onto the app tab', () {
    expect(appRouteForLink('/biodata/list'), '/biodata');
    expect(appRouteForLink('/biodata/view/mb_17000'), '/biodata/view/mb_17000');
  });
}
