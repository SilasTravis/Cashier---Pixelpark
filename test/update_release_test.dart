import 'package:flutter_test/flutter_test.dart';

import 'package:cashier_app/core/update/update_release.dart';

Map<String, dynamic> _json({
  String tag = 'v1.2.3',
  String body = 'Release notes here',
  List<Map<String, dynamic>>? assets,
}) => <String, dynamic>{
  'tag_name': tag,
  'body': body,
  'html_url': 'https://github.com/SilasTravis/Cashier---Pixelpark/releases/tag/$tag',
  'assets': assets ??
      <Map<String, dynamic>>[
        {
          'name': 'cashier_app-windows-$tag.zip',
          'size': 123456,
          'browser_download_url': 'https://example.test/$tag.zip',
        },
        {
          'name': 'cashier_app-windows-$tag.zip.sha256',
          'size': 64,
          'browser_download_url': 'https://example.test/$tag.zip.sha256',
        },
      ],
};

void main() {
  test('parses tag, notes, page url and both assets', () {
    final release = UpdateRelease.fromGithubJson(_json())!;

    expect(release.version, '1.2.3');
    expect(release.notes, 'Release notes here');
    expect(release.zipUrl, 'https://example.test/v1.2.3.zip');
    expect(release.zipSize, 123456);
    expect(release.sha256Url, 'https://example.test/v1.2.3.zip.sha256');
    expect(
      release.releasePageUrl,
      'https://github.com/SilasTravis/Cashier---Pixelpark/releases/tag/v1.2.3',
    );
  });

  test('accepts a tag without the v prefix', () {
    expect(UpdateRelease.fromGithubJson(_json(tag: '2.0.0'))!.version, '2.0.0');
  });

  test('returns null when no zip asset is attached', () {
    final json = _json(assets: <Map<String, dynamic>>[
      {
        'name': 'notes.txt',
        'size': 12,
        'browser_download_url': 'https://example.test/notes.txt',
      },
    ]);

    expect(UpdateRelease.fromGithubJson(json), isNull);
  });

  test('returns null when the payload has no tag', () {
    expect(UpdateRelease.fromGithubJson(<String, dynamic>{}), isNull);
  });

  test('tolerates a missing sha256 asset and a null body', () {
    final json = _json(assets: <Map<String, dynamic>>[
      {
        'name': 'cashier_app-windows-v1.2.3.zip',
        'size': 10,
        'browser_download_url': 'https://example.test/v1.2.3.zip',
      },
    ]);
    json['body'] = null;

    final release = UpdateRelease.fromGithubJson(json)!;
    expect(release.sha256Url, isNull);
    expect(release.notes, isEmpty);
  });
}
