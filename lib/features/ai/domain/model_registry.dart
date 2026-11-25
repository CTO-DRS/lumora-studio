/// What a model is used for.
enum AiTask {
  segmentation,
  portraitMatting,
  upscale,
  inpainting,
  interactiveSegmentation,
  depth,
  faceDetection,
  faceLandmarks,
  sceneClassification,
}

/// Describes a downloadable on-device model. Every model is fetched from a
/// public URL on demand, verified with SHA-256 and cached locally – nothing
/// is bundled in the app and no image ever leaves the device. When [url]
/// fails (HTTP error, TLS problem, corrupted bytes), the same file is
/// fetched from [mirrorUrl], a project-controlled GitHub Releases asset
/// with the **identical SHA-256**, before the download is reported failed.
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
    this.mirrorUrl,
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

  /// Project-hosted copy of the exact same file (same SHA-256), used as an
  /// automatic fallback when [url] fails. Hosted as release assets of this
  /// repository (tag `models-v1.3`, see `tool/sync_model_mirrors.py`).
  final String? mirrorUrl;

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
    mirrorUrl: '$_kMirrorBase/u2netp.onnx',
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
    mirrorUrl: '$_kMirrorBase/modnet_q8.onnx',
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
    mirrorUrl: '$_kMirrorBase/realesrgan_general_x4v3.onnx',
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
    mirrorUrl: '$_kMirrorBase/migan_pipeline.onnx',
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
    mirrorUrl: '$_kMirrorBase/lama_fp32.onnx',
    fixedInputSize: 512,
    notes: 'Static 512x512, float image 0..1, float mask 1 = erase.',
  );

  // Revision-pinned URLs (v1.3): the file at that commit can never change;
  // SHA-256 values are the LFS oids, verified by downloading each file and
  // running it with ONNX Runtime (see docs/SMART_EDIT.md).

  /// Base URL of the project-hosted model mirrors (release assets of this
  /// repository, tag `models-v1.3`; see `tool/sync_model_mirrors.py`).
  static const _kMirrorBase = 'https://github.com/CTO-DRS/lumora-studio/releases/download/models-v1.3';

  static const mobileSamEncoder = ModelSpec(
    id: 'mobilesam_encoder',
    task: AiTask.interactiveSegmentation,
    displayName: 'MobileSAM – image encoder (tap to select)',
    url:
        'https://huggingface.co/Acly/MobileSAM/resolve/0d3b403339b4674a82493d5e97964dd78089ddc8/mobile_sam_image_encoder.onnx',
    sha256: '580f5fb648ea1062c0aabc26217aed56921985f03f0cbbd852bba81d760cc749',
    sizeBytes: 28157093,
    license: 'Apache-2.0 (MobileSAM)',
    source: 'https://github.com/ChaoningZhang/MobileSAM',
    inputNames: ['input_image'],
    outputName: 'image_embeddings',
    mirrorUrl: '$_kMirrorBase/mobilesam_encoder.onnx',
    notes: 'HWC float 0..255, long side 1024 (the graph normalises and pads) → 1x256x64x64.',
  );

  static const mobileSamDecoder = ModelSpec(
    id: 'mobilesam_decoder',
    task: AiTask.interactiveSegmentation,
    displayName: 'Segment Anything – mask decoder (tap to select)',
    url:
        'https://huggingface.co/Acly/MobileSAM/resolve/0d3b403339b4674a82493d5e97964dd78089ddc8/sam_mask_decoder_single.onnx',
    sha256: '93915fc7c993ab9d59ab8c9ccd3bce37f7509c81ab4150a74abd4d2abbd8570d',
    sizeBytes: 16501323,
    license: 'Apache-2.0 (Segment Anything / MobileSAM)',
    source: 'https://github.com/ChaoningZhang/MobileSAM',
    inputNames: ['image_embeddings', 'point_coords', 'point_labels', 'mask_input', 'has_mask_input', 'orig_im_size'],
    outputName: 'masks',
    mirrorUrl: '$_kMirrorBase/mobilesam_decoder.onnx',
    notes:
        'Points in the 1024-px encoder frame (label 1 = add, 0 = subtract, -1 = padding) → mask logits at orig_im_size.',
  );

  /// Multi-candidate mask decoder: same inputs as [mobileSamDecoder] but
  /// returns 4 candidate masks (dim 1) with an `iou_predictions` [1, 4]
  /// score each; `low_res_masks` [1, 4, 256, 256] can be fed back as
  /// `mask_input` for refinement. Verified by running it with ONNX Runtime
  /// (see docs/SMART_EDIT.md). Powers the candidate picker of tap to select.
  static const mobileSamDecoderMulti = ModelSpec(
    id: 'mobilesam_decoder_multi',
    task: AiTask.interactiveSegmentation,
    displayName: 'Segment Anything – multi-mask decoder (tap to select)',
    url:
        'https://huggingface.co/Acly/MobileSAM/resolve/0d3b403339b4674a82493d5e97964dd78089ddc8/sam_mask_decoder_multi.onnx',
    sha256: '8976b90a87ba50a6a72217a5ff994f7d25ce16f2229fcc1ed259e1294c622ffe',
    sizeBytes: 16496559,
    license: 'Apache-2.0 (Segment Anything / MobileSAM)',
    source: 'https://github.com/ChaoningZhang/MobileSAM',
    inputNames: ['image_embeddings', 'point_coords', 'point_labels', 'mask_input', 'has_mask_input', 'orig_im_size'],
    outputName: 'masks',
    mirrorUrl: '$_kMirrorBase/mobilesam_decoder_multi.onnx',
    notes:
        'Same prompts as the single decoder (box corners = labels 2, 3) → masks [1, 4, H, W] + iou_predictions [1, 4] + low_res_masks [1, 4, 256, 256].',
  );

  static const depthAnythingSmall = ModelSpec(
    id: 'depth_anything_v2_small_q8',
    task: AiTask.depth,
    displayName: 'Depth Anything V2 Small – depth (int8)',
    url:
        'https://huggingface.co/onnx-community/depth-anything-v2-small/resolve/4472b7362082ad9968fee890ca0f1e5aca36b93d/onnx/model_quantized.onnx',
    sha256: 'fcf51f1b230362b28690bb9d1809bf0431f29cad20534e3f589bd7285547f20d',
    sizeBytes: 27258801,
    license: 'Apache-2.0',
    source: 'https://github.com/DepthAnything/Depth-Anything-V2',
    inputNames: ['pixel_values'],
    outputName: 'predicted_depth',
    mirrorUrl: '$_kMirrorBase/depth_anything_v2_small_q8.onnx',
    notes: 'NCHW ImageNet-normalised, sides multiples of 14 → relative inverse depth (larger = nearer).',
  );

  // Revision-pinned URLs (v1.4): the file at that commit can never change;
  // SHA-256 values were verified by downloading each file and running it with
  // ONNX Runtime (YuNet decode checked against the reference implementation;
  // landmark presence gated on a real photo). See docs/SMART_EDIT.md.

  /// YuNet face detector (OpenCV Zoo 2023mar export). The ONNX graph ships 12
  /// raw outputs (cls/obj/bbox/kps at strides 8/16/32); decoding happens in
  /// [FacePipeline] — anchors at grid corners, centre = anchor + bbox[:2] *
  /// stride, w/h = exp(bbox[2:]) * stride, keypoints = anchor + kps * stride,
  /// score = sqrt(cls * obj) (the graph applies the sigmoids itself), NMS IoU
  /// 0.3. Verified in the sandbox: 0.87 confidence on a test portrait,
  /// ~20 ms per 640×640 frame on two x86 cores.
  static const yunetFaceDetect = ModelSpec(
    id: 'yunet_face_detect',
    task: AiTask.faceDetection,
    displayName: 'YuNet – face detection (2023mar)',
    url:
        'https://huggingface.co/opencv/face_detection_yunet/resolve/3cc26e7f1014a5ee5d74a42acee58bafc9d0a310/face_detection_yunet_2023mar.onnx',
    sha256: '8f2383e4dd3cfbb4553ea8718107fc0423210dc964f9f4280604804ed2552fa4',
    sizeBytes: 232589,
    license: 'MIT (OpenCV Zoo / libfacedetection)',
    source: 'https://github.com/opencv/opencv_zoo/tree/main/models/face_detection_yunet',
    inputNames: ['input'],
    outputName: 'cls_8',
    mirrorUrl: '$_kMirrorBase14/yunet_face_detect.onnx',
    notes:
        'Static 1x3x640x640 float BGR 0..255 (resize any photo to 640x640 and scale boxes back). 12 outputs: cls_8/16/32 [1,N,1], obj_8/16/32 [1,N,1], bbox_8/16/32 [1,N,4], kps_8/16/32 [1,N,10] with N = 6400/1600/400 (row-major grids).',
  );

  /// MediaPipe Face Landmarker (468-point mesh + 10 iris points = 478),
  /// converted TFLite → ONNX with unchanged Google weights (Apache-2.0).
  /// Input is a square crop around one face, rolled so the eyes are level —
  /// exactly what MediaPipe builds from its face detector. Verified in the
  /// sandbox: presence 0.97 on a real portrait, ~15 ms per face on two x86
  /// cores.
  static const faceLandmarks478 = ModelSpec(
    id: 'face_landmarks_478',
    task: AiTask.faceLandmarks,
    displayName: 'MediaPipe Face Landmarker – 478-point mesh',
    url:
        'https://huggingface.co/senty-au/face_landmarks_detector-ONNX/resolve/337d58218b5b1cc597ca3c67360880b920f6ce7b/onnx/model.onnx',
    sha256: '7d6e82dee82a1dca5fbddb282b3cc74571833a530de317fc22ae325c3358beeb',
    sizeBytes: 4920995,
    license: 'Apache-2.0 (MediaPipe Face Landmarker, weights © Google)',
    source: 'https://ai.google.dev/edge/mediapipe/solutions/vision/face_landmarker',
    inputNames: ['input_12'],
    outputName: 'Identity',
    mirrorUrl: '$_kMirrorBase14/face_landmarks_478.onnx',
    fixedInputSize: 256,
    notes:
        'NHWC float RGB 0..1 [1,256,256,3] aligned square crop → Identity [1,1,1,1434] = 478×(x,y,z) in crop pixels (0..256); Identity_1 = face presence logit (sigmoid, keep > 0.5); Identity_2 auxiliary (ignored).',
  );

  /// Base URL of the v1.4 project-hosted model mirrors (release assets of
  /// this repository, tag `models-v1.4`; see `tool/sync_model_mirrors.py`).
  static const _kMirrorBase14 = 'https://github.com/CTO-DRS/lumora-studio/releases/download/models-v1.4';

  /// MobileNetV2 (int8, ImageNet-1k) scene classifier, ~3.5 MB. Powers the
  /// scene-aware suggestions of the Smart bar: the photo's proxy is
  /// classified on-device and the result nudges which quick fixes are
  /// offered (pets → soft warm portrait, food → vivid, nature → landscape…).
  /// Never downloaded automatically — suggestions keep working with pure
  /// statistics until the user installs the model (Settings › AI models).
  /// Downloaded, verified and executed with ONNX Runtime before being
  /// registered (see docs/SMART_EDIT.md); the pinned zoo commit can never
  /// change the file.
  static const mobilenetScene = ModelSpec(
    id: 'mobilenetv2_224_q8',
    task: AiTask.sceneClassification,
    displayName: 'MobileNetV2 – scene classifier (int8)',
    url:
        'https://github.com/onnx/models/raw/4c46cd00fbdb7cd30b6c1c17ab54f2e1f4f7b177/validated/vision/classification/mobilenet/model/mobilenetv2-12-int8.onnx',
    sha256: 'cc028fe6cae7bc11a4ff53cfc9b79c920e8be65ce33a904ec3e2a8f66d77f95f',
    sizeBytes: 3655033,
    license: 'MIT (ONNX model zoo MobileNetV2)',
    source: 'https://github.com/onnx/models/tree/main/validated/vision/classification/mobilenet',
    inputNames: ['input'],
    outputName: 'output',
    mirrorUrl: '$_kMirrorBase/mobilenetv2_224_q8.onnx',
    fixedInputSize: 224,
    notes:
        'Static [batch, 3, 224, 224] float, RGB 0..1 with ImageNet mean/std normalisation → 1000 ImageNet logits (measurements on a 2-core x86 sandbox: 2.4 ms per frame).',
  );

  static const List<ModelSpec> all = [
    u2netp,
    modnet,
    realEsrgan,
    migan,
    lama,
    mobileSamEncoder,
    mobileSamDecoder,
    mobileSamDecoderMulti,
    depthAnythingSmall,
    yunetFaceDetect,
    faceLandmarks478,
    mobilenetScene,
  ];

  static ModelSpec byId(String id) => all.firstWhere((m) => m.id == id);

  static List<ModelSpec> forTask(AiTask task) => all.where((m) => m.task == task).toList();
}

/// The model-backed tools of the photo editor's AI tab.
enum AiTool {
  removeBackground,
  cutOutPerson,
  backgroundBlur,
  portraitRetouch,
  eraser,
  upscale,
  selectObject,
  depthBlur,
  relight,
  erasePerson,
  faceRetouch,
  eyeBrighten,
  teethWhiten,
}

/// Models a tool needs on the device before it can run.
List<ModelSpec> aiToolModels(AiTool tool) => switch (tool) {
  AiTool.removeBackground => const [ModelRegistry.u2netp],
  AiTool.cutOutPerson || AiTool.backgroundBlur || AiTool.portraitRetouch => const [ModelRegistry.modnet],
  AiTool.eraser => const [ModelRegistry.migan],
  AiTool.upscale => const [ModelRegistry.realEsrgan],
  AiTool.selectObject => const [ModelRegistry.mobileSamEncoder, ModelRegistry.mobileSamDecoderMulti],
  AiTool.depthBlur || AiTool.relight => const [ModelRegistry.depthAnythingSmall],
  AiTool.erasePerson => const [ModelRegistry.modnet, ModelRegistry.migan],
  AiTool.faceRetouch ||
  AiTool.eyeBrighten ||
  AiTool.teethWhiten => const [ModelRegistry.yunetFaceDetect, ModelRegistry.faceLandmarks478],
};
