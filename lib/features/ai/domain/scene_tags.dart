import 'dart:math' as math;
import 'dart:typed_data';

/// High-level scene tags the Smart bar uses to make its suggestions
/// scene-aware. Each tag maps to a curated subset of ImageNet-1k class
/// indices (the MobileNetV2 scene classifier outputs 1000 logits in the
/// standard synset order); the per-tag score is the summed softmax mass of
/// that subset, so a tag survives even when the classifier's top-1 is a
/// neighbouring class.
enum SceneTag { pets, food, nature, city, vehicle, plant }

/// ImageNet-1k class indices per [SceneTag], hand-curated from the model
/// zoo's `synset.txt` (dogs n02085620–n02107142 + wild canids + cats;
/// dishes, drinks and fruits; landscape synsets; famous buildings and
/// street furniture; road/air/sea vehicles; flowers and plants).
const Map<SceneTag, List<int>> kSceneTagIndices = {
  // 151–236: the dog-breed block (n02085620–n02107142); 273 dingo,
  // 275 African hunting dog; 281–285 the cat block (n02123045–n02124075).
  SceneTag.pets: [
    151, 152, 153, 154, 155, 156, 157, 158, 159, 160, 161, 162, //
    163, 164, 165, 166, 167, 168, 169, 170, 171, 172, 173, 174,
    175, 176, 177, 178, 179, 180, 181, 182, 183, 184, 185, 186,
    187, 188, 189, 190, 191, 192, 193, 194, 195, 196, 197, 198,
    199, 200, 201, 202, 203, 204, 205, 206, 207, 208, 209, 210,
    211, 212, 213, 214, 215, 216, 217, 218, 219, 220, 221, 222,
    223, 224, 225, 226, 227, 228, 229, 230, 231, 232, 233, 234,
    235, 236, 273, 275, 281, 282, 283, 284, 285,
  ],
  // Dishes and ingredients, drinks, fruits (soup bowl … eggnog, corn ear).
  SceneTag.food: [
    809, 907, 924, 925, 926, 928, 929, 930, 931, 932, //
    933, 934, 935, 949, 950, 951, 952, 953, 954, 955,
    956, 957, 959, 960, 961, 962, 963, 964, 965, 966,
    967, 969, 998,
  ],
  // Landscape synsets: cliff, coral reef, geyser, lakeside, promontory,
  // sandbar, seashore, valley, volcano.
  SceneTag.nature: [972, 973, 974, 975, 976, 977, 978, 979, 980],
  // Famous/recognisable buildings and street furniture: barn, boathouse,
  // bookshop, castle, church, cinema, confectionery, library, monastery,
  // mosque, palace, park bench, restaurant, stupa, tile roof, street sign,
  // traffic light.
  SceneTag.city: [425, 449, 454, 483, 497, 498, 509, 624, 663, 668, 698, 703, 762, 832, 858, 919, 920],
  // Road, air and sea: airliner, airship, container ship, station wagon,
  // tandem bicycle, cab, catamaran, convertible, fireboat, fire engine,
  // forklift, garbage truck, gondola, jeep, limousine, minivan, motor
  // scooter, moving van, pickup, police van, RV, school bus, speedboat,
  // sports car, streetcar, tow truck, tractor, trailer truck, trimaran,
  // trolleybus.
  SceneTag.vehicle: [
    404, 405, 436, 444, 468, 484, 510, 511, 554, 555, //
    561, 569, 576, 609, 627, 656, 670, 675, 717, 734,
    757, 779, 814, 817, 829, 864, 866, 867, 871, 874,
  ],
  // Flowers and plants: flowerpot, acorn squash, rapeseed, daisy, yellow
  // lady's slipper, corn, acorn, rose hip, buckeye.
  SceneTag.plant: [738, 941, 984, 985, 986, 987, 988, 989, 990],
};

/// Minimum per-tag probability for the tag to influence suggestions.
const double kSceneTagMinScore = 0.20;

/// The result of classifying one photo: a probability per [SceneTag]
/// (each 0..1, the summed softmax mass of its class subset) plus the
/// single most probable ImageNet class, kept for the error log and tests.
class SceneResult {
  SceneResult._(this.scores, this.topClassIndex, this.topClassProbability)
    : assert(scores.length == SceneTag.values.length, 'scores must cover every SceneTag'),
      assert(topClassIndex >= 0 && topClassIndex < 1000, 'topClassIndex must be an ImageNet class'),
      assert(topClassProbability >= 0 && topClassProbability <= 1, 'topClassProbability must be a probability');

  /// Probability per tag, 0..1 (sum of softmax mass over the tag's classes).
  final Map<SceneTag, double> scores;

  /// Argmax class over the raw 1000 logits (diagnostic).
  final int topClassIndex;
  final double topClassProbability;

  /// Tags worth acting on, strongest first (probability ≥ [kSceneTagMinScore]).
  List<SceneTag> get activeTags => [
    for (final t in SceneTag.values)
      if ((scores[t] ?? 0) >= kSceneTagMinScore) t,
  ]..sort((a, b) => (scores[b] ?? 0).compareTo(scores[a] ?? 0));

  double score(SceneTag tag) => scores[tag] ?? 0;

  /// Softmax over the 1000 logits, then per-tag subset sums.
  ///
  /// Numerically stable (shifted exponentials); handles the flat/random
  /// logits of tests and never produces NaN or values outside 0..1.
  static SceneResult fromLogits(List<num> logits) {
    assert(logits.length == 1000, 'expected 1000 ImageNet logits, got ${logits.length}');
    var max = logits[0].toDouble();
    for (final v in logits) {
      if (v > max) max = v.toDouble();
    }
    var total = 0.0;
    final exp = Float64List(1000);
    for (var i = 0; i < 1000; i++) {
      final e = math.exp(logits[i].toDouble() - max);
      exp[i] = e;
      total += e;
    }
    final scores = <SceneTag, double>{};
    for (final tag in SceneTag.values) {
      var s = 0.0;
      for (final i in kSceneTagIndices[tag]!) {
        s += exp[i] / total;
      }
      scores[tag] = s;
    }
    var top = 0;
    for (var i = 1; i < 1000; i++) {
      if (exp[i] > exp[top]) top = i;
    }
    return SceneResult._(Map.unmodifiable(scores), top, exp[top] / total);
  }
}
