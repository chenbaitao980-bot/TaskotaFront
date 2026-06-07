class ObsidianService {
  static Future<bool> openUri(String uri) async => false;

  static String buildUri({
    required String vault,
    required String filePath,
    String? heading,
  }) {
    if (heading != null && heading.isNotEmpty) {
      return 'obsidian://adv-uri?vault='
          '${Uri.encodeComponent(vault)}'
          '&filepath='
          '${Uri.encodeComponent(filePath)}'
          '&heading='
          '${Uri.encodeComponent(heading)}';
    }
    return 'obsidian://open?vault='
        '${Uri.encodeComponent(vault)}'
        '&file='
        '${Uri.encodeComponent(filePath)}';
  }

  static bool isValidObsidianUri(String uri) => uri.startsWith('obsidian://');

  static String? parseVault(String uri) {
    final uriObj = Uri.tryParse(uri);
    return uriObj?.queryParameters['vault'];
  }

  static String? parseFilePath(String uri) {
    final uriObj = Uri.tryParse(uri);
    return uriObj?.queryParameters['file'] ??
        uriObj?.queryParameters['filepath'];
  }

  static String? parseHeading(String uri) {
    final uriObj = Uri.tryParse(uri);
    return uriObj?.queryParameters['heading'];
  }

  static ({String vaultRoot, String vaultName})? detectVault(
    String filePath,
  ) => null;

  static String relativePath(String absolutePath, String vaultRoot) {
    var rel = absolutePath.replaceFirst(vaultRoot, '');
    if (rel.startsWith('/')) rel = rel.substring(1);
    return rel;
  }

  static String documentName(String filePath) {
    final name = filePath.split('/').last;
    if (name.endsWith('.md')) return name.substring(0, name.length - 3);
    return name;
  }
}
