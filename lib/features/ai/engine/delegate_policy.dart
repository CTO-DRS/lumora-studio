/// Delegate selection policy for the LiteRT engine (Wave 2, "Pro
/// Intelligence" W1 — LiteRT/NPU runtime).
///
/// The safe floor is CPU kernels. Acceleration climbs a ladder — NPU where
/// the SoC's NPU is known-good through Android NNAPI, then GPU (OpenGL on
/// Android, Metal on iOS) — and every failure is recorded in a per-session
/// blacklist so a broken delegate is never retried while the app lives.
/// A native abort cannot be caught from Dart, which is why NPU is gated
/// behind an explicit SoC allow-list (see ROADMAP §7 risks).
library;

/// Accelerators the LiteRT engine can pick for a session, best first.
enum Accelerator {
  /// Neural Processing Unit via the Android NNAPI delegate.
  npu,

  /// GPU via the LiteRT GPU delegate (OpenGL/ES on Android, Metal on iOS).
  gpu,

  /// Plain CPU kernels — always available, the safe floor.
  cpu;

  /// Human-readable label for diagnostics breadcrumbs.
  String get label => switch (this) {
    Accelerator.npu => 'NPU (NNAPI)',
    Accelerator.gpu => 'GPU delegate',
    Accelerator.cpu => 'CPU kernels',
  };
}

/// SoC identifiers whose NPUs are known-good through the Android NNAPI
/// delegate. Conservative by design; the device farm grows this list.
/// Keys are normalised (lowercase, no spaces).
const Set<String> kNpuAllowList = {
  // Qualcomm Snapdragon 8-series flagships (SDM845 / SM8xxx, Kryo + Hexagon).
  'sdm845',
  'sdm855',
  'sm8450',
  'sm8475',
  'sm8550',
  'sm8650',
  'sm8750',
  // Google Tensor (GS101/GS201 and the marketing names).
  'gs101',
  'gs201',
  'tensor',
  'tensor_g2',
  'tensor_g3',
  'tensor_g4',
  'zuma',
  'zumapro',
  // MediaTek Dimensity 9000+ (MT6983 and successors).
  'mt6983',
  'mt6985',
  'mt6991',
};

/// Normalises a raw SoC identifier to a allow-list key: lowercase, spaces
/// and punctuation collapsed to `_`, vendor noise dropped. Returns `null`
/// for empty input.
String? normaliseSoc(String? raw) {
  if (raw == null) return null;
  var s = raw.trim().toLowerCase();
  if (s.isEmpty) return null;
  const noise = [
    'qualcomm technologies inc',
    'qualcomm technologies',
    'qualcomm',
    'mediatek inc',
    'mediatek',
    'samsung electronics',
    'samsung',
    'inc',
    'technologies',
  ];
  for (final n in noise) {
    s = s.replaceAll(n, ' ');
  }
  s = s.trim().replaceAll(RegExp('[^a-z0-9]+'), '_');
  s = s.replaceAll(RegExp('_+'), '_');
  while (s.startsWith('_')) {
    s = s.substring(1);
  }
  while (s.endsWith('_')) {
    s = s.substring(0, s.length - 1);
  }
  if (s.isEmpty) return null;
  return s;
}

/// Best-effort SoC hint from `/proc/cpuinfo` content. Android exposes the
/// board hardware line as `Hardware : …` on many devices; newer kernels may
/// not expose it at all (the caller passes `null` and the policy falls back
/// to the GPU-only ladder). Pure function so it is unit-testable.
String? socFromCpuinfo(String cpuinfo) {
  final match = RegExp(r'^Hardware\s*:\s*(.+)$', multiLine: true).firstMatch(cpuinfo);
  if (match == null) return null;
  return normaliseSoc(match.group(1));
}

/// Whether [soc] is on the NPU allow-list. Unknown SoCs never get the NPU.
bool socHasNpu(String? soc) {
  final s = normaliseSoc(soc);
  if (s == null) return false;
  return kNpuAllowList.contains(s);
}

/// Constant default for [DelegatePolicy] constructors (top-level function
/// references are constant expressions).
const bool Function(String? soc) kDefaultSocHasNpu = socHasNpu;

/// Orders the accelerators for a session, best first.
///
/// * Not accelerated → CPU only (the shipped default; see onnx_engine.dart).
/// * Apple → GPU (Metal) then CPU.
/// * Android → NPU (NNAPI) only for allow-listed SoCs, then GPU, then CPU.
/// * Desktop → CPU only.
class DelegatePolicy {
  const DelegatePolicy({this.socHasNpu = kDefaultSocHasNpu});

  /// Injectable so tests can force the allow-list decision.
  final bool Function(String? soc) socHasNpu;

  List<Accelerator> orderFor({required bool accelerated, required bool android, required bool apple, String? soc}) {
    if (!accelerated) return const [Accelerator.cpu];
    if (apple) return const [Accelerator.gpu, Accelerator.cpu];
    if (android) {
      return socHasNpu(soc)
          ? const [Accelerator.npu, Accelerator.gpu, Accelerator.cpu]
          : const [Accelerator.gpu, Accelerator.cpu];
    }
    return const [Accelerator.cpu];
  }
}

/// Per-session memory of `(model, accelerator)` pairs that failed to open or
/// run. A delegate that throws once is never retried for that model while
/// the app lives — the failure cost is paid at most once per session.
class DelegateBlacklist {
  final Set<String> _blocked = {};

  void block(String modelId, Accelerator a) => _blocked.add('$modelId:${a.name}');

  bool isBlocked(String modelId, Accelerator a) => _blocked.contains('$modelId:${a.name}');

  bool get isEmpty => _blocked.isEmpty;
  int get length => _blocked.length;
}
