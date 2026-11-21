/// What a model is used for.
enum AiTask { segmentation, portraitMatting, upscale, inpainting }

/// Describes a downloadable on-device model. Every model is fetched from a
/// public URL on demand, verified with SHA-256 and cached locally – nothing
/// is bundled in the app and no image ever leaves the device.
class ModelSpec {
  const ModelSpec({
    required this.id,
    required this.task,
    required this.displayName,
    required this.url,
    required this.sha256,
    required this.sizeBytes,
    required this.license,
    required this.source,
    required this.inputNames,
    required this.outputName,
    this.fixedInputSize,
    this.notes = '',
  });

  final String id;
  final AiTask task;
  final String displayName;
  final String url;
  final String sha256;
  final int sizeBytes;
  final String license;
  final String source;
  final List<String> inputNames;
  final String outputName;

  /// Square input size when the graph has static dimensions.
  final int? fixedInputSize;
  final String notes;

  String get fileName => '$id.onnx';

  double get sizeMb => sizeBytes / (1024 * 1024);
}

/// The model registry. SHA-256 values are the Git LFS object ids published
/// by Hugging Face for each file (verified when this registry was written).
class ModelRegistry {
  static const u2netp = ModelSpec(
    id: 'u2netp',
    task: AiTask.segmentation,
    displayName: 'U²-Net (portable) – salient object segmentation',
    url: 'https://huggingface.co/BritishWerewolf/U-2-Netp/resolve/main/onnx/model.onnx',
    sha256: '309c8469258dda742793dce0ebea8e6dd393174f89934733ecc8b14c76f4ddd8',
    sizeBytes: 4574861,
    license: 'Apache-2.0',
    source: 'https://github.com/xuebinqin/U-2-Net',
    inputNames: ['input.1'],
    outputName: '1959',
    fixedInputSize: 320,
    notes: 'ImageNet normalization, sigmoid output d0, min-max normalized.',
  );

  static const modnet = ModelSpec(
    id: 'modnet_q8',
    task: AiTask.portraitMatting,
    displayName: 'MODNet – portrait matting (int8)',
    url: 'https://huggingface.co/Xenova/modnet/resolve/main/onnx/model_quantized.onnx',
    sha256: '92e49898c3e05a6d7a944fc67a8cb87c4aad754ffb6ebd949528c7d1105fee3a',
    sizeBytes: 6632188,
    license: 'Apache-2.0',
    source: 'https://github.com/ZHKKKe/MODNet',
    inputNames: ['input'],
    outputName: 'output',
    notes: 'Dynamic H/W (multiples of 32), mean=std=0.5, alpha matte 0..1.',
  );

  static const realEsrgan = ModelSpec(
    id: 'realesrgan_general_x4v3',
    task: AiTask.upscale,
    displayName: 'Real-ESRGAN General x4 v3 – 4× super resolution',
    url: 'https://huggingface.co/tamnvcc/Real-ESRGAN-General-x4v3_float/resolve/main/onnx/model.onnx',
    sha256: '83adcbbe5f96dc323c839abef6ca540e719bbdbd4c1bc91ffc7526f83073bedf',
    sizeBytes: 4876654,
    license: 'BSD-3-Clause',
    source: 'https://github.com/xinntao/Real-ESRGAN',
    inputNames: ['image'],
    outputName: 'upscaled_image',
    fixedInputSize: 128,
    notes: 'Static 1x3x128x128 float input 0..1 → 1x3x512x512.',
  );

  static const migan = ModelSpec(
    id: 'migan_pipeline',
    task: AiTask.inpainting,
    displayName: 'MI-GAN – fast object eraser',
    url: 'https://huggingface.co/anyisalin/migan-onnx/resolve/main/onnx/migan_pipeline.onnx',
    sha256: '6f1f3530a1a2324b19752018ce756088b07973cda8d7d890034ace5c8a48c40b',
    sizeBytes: 28079181,
    license: 'MIT (Picsart AI Research MI-GAN)',
    source: 'https://github.com/Picsart-AI-Research/MI-GAN',
    inputNames: ['image', 'mask'],
    outputName: 'result',
    notes: 'uint8 NCHW image, uint8 mask (255 = keep, 0 = erase), any size.',
  );

  static const lama = ModelSpec(
    id: 'lama_fp32',
    task: AiTask.inpainting,
    displayName: 'LaMa – high quality object eraser (large)',
    url: 'https://huggingface.co/Carve/LaMa-ONNX/resolve/main/lama_fp32.onnx',
    sha256: '1faef5301d78db7dda502fe59966957ec4b79dd64e16f03ed96913c7a4eb68d6',
    sizeBytes: 208044816,
    license: 'Apache-2.0',
    source: 'https://github.com/advimman/lama',
    inputNames: ['image', 'mask'],
    outputName: 'output',
    fixedInputSize: 512,
    notes: 'Static 512x512, float image 0..1, float mask 1 = erase.',
  );

  static const List<ModelSpec> all = [u2netp, modnet, realEsrgan, migan, lama];

  static ModelSpec byId(String id) => all.firstWhere((m) => m.id == id);

  static List<ModelSpec> forTask(AiTask task) => all.where((m) => m.task == task).toList();
}

/// The model-backed tools of the photo editor's AI tab.
enum AiTool { removeBackground, cutOutPerson, backgroundBlur, portraitRetouch, eraser, upscale }

/// Models a tool needs on the device before it can run.
List<ModelSpec> aiToolModels(AiTool tool) => switch (tool) {
  AiTool.removeBackground => const [ModelRegistry.u2netp],
  AiTool.cutOutPerson || AiTool.backgroundBlur || AiTool.portraitRetouch => const [ModelRegistry.modnet],
  AiTool.eraser => const [ModelRegistry.migan],
  AiTool.upscale => const [ModelRegistry.realEsrgan],
};
