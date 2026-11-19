import 'package:flutter_test/flutter_test.dart';
import 'package:phoneshop_ms/components/common.dart';

void main() {
  test('shop pictures ask for the smallest sharp copy', () {
    const url = 'http://127.0.0.1:8010/media/abc.png';
    expect(sizedImageUrl(url, 100), '$url?w=160');
    expect(sizedImageUrl(url, 44 * 3), '$url?w=160');
    expect(sizedImageUrl(url, 150 * 2), '$url?w=320');
    expect(sizedImageUrl(url, 300 * 2), '$url?w=640');
    expect(sizedImageUrl(url, 2000), url); // bigger than every copy
    // Not ours, or already sized: left alone
    expect(sizedImageUrl('https://cdn.example/x.png', 100), 'https://cdn.example/x.png');
    expect(sizedImageUrl('$url?w=320', 100), '$url?w=320');
  });
}
