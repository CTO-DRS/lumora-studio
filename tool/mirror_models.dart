// Prints one TSV line per registered model:
//   <pinned URL>\t<sha256>\t<mirror asset name>
//
// Single source of truth: the URLs and checksums come straight from
// lib/features/ai/domain/model_registry.dart, so the mirror can never drift
// from what the app downloads. Run with plain dart (no Flutter needed):
//   dart run tool/mirror_models.dart
// ignore_for_file: avoid_print
import 'package:lumora/features/ai/domain/model_registry.dart';

void main() {
  for (final m in ModelRegistry.all) {
    if (m.mirrorUrl.isEmpty) continue;
    print('${m.url}\t${m.sha256}\t${m.mirrorAssetName}');
  }
}
