import 'dart:io';

class ObsidianService {
  /// 打开 Obsidian URI，定位到指定文档/标题
  /// 返回 true 表示启动成功
  static Future<bool> openUri(String uri) async {
    try {
      if (Platform.isWindows) {
        // 使用 cmd /c start 打开 URI
        // - start "" 第一个空引号是窗口标题，防止 start 把 URI 当标题
        // - & 在 cmd 中是命令分隔符，需要转义为 ^&
        // - 不手动加引号，让 Dart Process.run 自行处理参数引用，避免 \" 污染
        final escapedUri = uri.replaceAll('&', '^&');
        try {
          final result = await Process.run(
            'cmd',
            ['/c', 'start', '', escapedUri],
          );
          return result.exitCode == 0;
        } catch (_) {
          return false;
        }
      } else if (Platform.isMacOS) {
        final result = await Process.run('open', [uri]);
        return result.exitCode == 0;
      } else if (Platform.isLinux) {
        final result = await Process.run('xdg-open', [uri]);
        return result.exitCode == 0;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// 从结构化字段构建 Obsidian URI
  /// 如果提供了 heading，使用 adv-uri 协议（需要 Advanced URI 插件）
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

  /// 校验是否为合法的 Obsidian URI
  static bool isValidObsidianUri(String uri) {
    return uri.startsWith('obsidian://');
  }

  /// 尝试从 Obsidian URI 中解析出 vault 名称
  static String? parseVault(String uri) {
    final uriObj = Uri.tryParse(uri);
    if (uriObj == null) return null;
    return uriObj.queryParameters['vault'];
  }

  /// 尝试从 Obsidian URI 中解析出文件路径
  static String? parseFilePath(String uri) {
    final uriObj = Uri.tryParse(uri);
    if (uriObj == null) return null;
    return uriObj.queryParameters['file'] ??
        uriObj.queryParameters['filepath'];
  }

  /// 尝试从 Obsidian URI 中解析出标题
  static String? parseHeading(String uri) {
    final uriObj = Uri.tryParse(uri);
    if (uriObj == null) return null;
    return uriObj.queryParameters['heading'];
  }

  /// 从 .md 文件绝对路径往上查找 .obsidian 目录，返回 (vaultRoot, vaultName)
  /// 如果找不到，返回 null
  static ({String vaultRoot, String vaultName})? detectVault(String filePath) {
    var dir = Directory(filePath).parent;
    while (true) {
      final obsidianDir = Directory('${dir.path}/.obsidian');
      if (obsidianDir.existsSync()) {
        return (
          vaultRoot: dir.path,
          vaultName: dir.path.split(Platform.pathSeparator).last,
        );
      }
      final parent = dir.parent;
      if (parent.path == dir.path) break; // 到达根目录
      dir = parent;
    }
    return null;
  }

  /// 从绝对文件路径计算出相对于 vault 根目录的相对路径
  static String relativePath(String absolutePath, String vaultRoot) {
    var rel = absolutePath.replaceFirst(vaultRoot, '');
    // 去掉开头的路径分隔符，统一为正斜杠
    rel = rel.replaceAll(Platform.pathSeparator, '/');
    if (rel.startsWith('/')) rel = rel.substring(1);
    return rel;
  }

  /// 从文件路径提取文档名称（不含 .md 后缀）
  static String documentName(String filePath) {
    final name = filePath.split(Platform.pathSeparator).last;
    if (name.endsWith('.md')) {
      return name.substring(0, name.length - 3);
    }
    return name;
  }
}
