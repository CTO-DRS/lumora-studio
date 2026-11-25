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
  skySegmentation,
}

/// Describes a downloadable on-device model. Every model is fetched from a
/// public URL on demand, verified with SHA-256 and cached locally – nothing
/// is bundled in the app and no image ever leaves the device. Every file is
/// also mirrored on the project's own host (a GitHub Release asset) with the
/// identical SHA-256; the mirror is used automatically when the primary
/// download fails (see [ModelManager]).
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
    this.mirrorUrl = '',
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

  /// Project-hosted copy with the same bytes (empty when there is none).
  final String mirrorUrl;

  /// The asset name used by the project mirror.
  String get mirrorAssetName => fileName;

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
    mirrorUrl: 'https://github.com/CTO-DRS/lumora-studio/releases/download/models-1.3/u2netp.onnx',
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
    mirrorUrl: 'https://github.com/CTO-DRS/lumora-studio/releases/download/models-1.3/modnet_q8.onnx',
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
    mirrorUrl: 'https://github.com/CTO-DRS/lumora-studio/releases/download/models-1.3/realesrgan_general_x4v3.onnx',
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
    mirrorUrl: 'https://github.com/CTO-DRS/lumora-studio/releases/download/models-1.3/migan_pipeline.onnx',
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
    mirrorUrl: 'https://github.com/CTO-DRS/lumora-studio/releases/download/models-1.3/lama_fp32.onnx',
  );

  // Revision-pinned URLs (v1.3): the file at that commit can never change;
  // SHA-256 values are the LFS oids, verified by downloading each file and
  // running it with ONNX Runtime (see docs/SMART_EDIT.md). Every file is
  // mirrored as a GitHub Release asset of this repository with the same name
  // and the same bytes.

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
    notes: 'HWC float 0..255, long side 1024 (the graph normalises and pads) → 1x256x64x64.',
    mirrorUrl: 'https://github.com/CTO-DRS/lumora-studio/releases/download/models-1.3/mobilesam_encoder.onnx',
  );

  /// Multi-mask SAM decoder (v1.3.x): the same inputs as the single-mask
  /// decoder of 1.3, but `masks` has four channels – 0 is the single-mask
  /// branch, 1..3 are the three candidates with `iou_predictions` per
  /// channel. Verified by downloading, hashing and running the file with
  /// ONNX Runtime 1.32: a synthetic circle decoded with a centre point,
  /// a box prompt (labels 2/3) and a 256 px mask_input all produced sane
  /// masks in ≈ 100 ms on the 2-core x86 sandbox.
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
    notes:
        'Points/box in the 1024-px encoder frame (label 1 = add, 0 = subtract, 2/3 = box corners, -1 = padding) '
        '→ masks [1, 4, h, w] logits at orig_im_size (channel 0 single, 1..3 candidates) + iou_predictions [1, 4].',
    mirrorUrl: 'https://github.com/CTO-DRS/lumora-studio/releases/download/models-1.3/mobilesam_decoder_multi.onnx',
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
    notes: 'NCHW ImageNet-normalised, sides multiples of 14 → relative inverse depth (larger = nearer).',
    mirrorUrl: 'https://github.com/CTO-DRS/lumora-studio/releases/download/models-1.3/depth_anything_v2_small_q8.onnx',
  );

  // v1.4 "Pro foundations" models. Same verification methodology as v1.3:
  // every file was downloaded, SHA-256-checked and executed with ONNX
  // Runtime before this entry was written (see docs/SMART_EDIT.md).

  /// OpenCV Zoo YuNet pinned at commit 48b10fa5… – the Git LFS oid equals the
  /// SHA-256 below. This export is the **raw 12-output** graph with a static
  /// 640×640 input; the decode (anchors at grid corners, score = √(cls·obj),
  /// NMS) lives in Dart in `FaceDetectionPipeline` and was verified against
  /// `cv2.FaceDetectorYN` on real photos.
  static const yunet = ModelSpec(
    id: 'yunet',
    task: AiTask.faceDetection,
    displayName: 'YuNet – face detection (5 landmarks)',
    url:
        'https://github.com/opencv/opencv_zoo/raw/48b10fa505aeb51fbd127fc60a5c660040e823b7/models/face_detection_yunet/face_detection_yunet_2023mar.onnx',
    sha256: '8f2383e4dd3cfbb4553ea8718107fc0423210dc964f9f4280604804ed2552fa4',
    sizeBytes: 232589,
    license: 'Apache-2.0 (OpenCV Zoo)',
    source: 'https://github.com/opencv/opencv_zoo/tree/main/models/face_detection_yunet',
    inputNames: ['input'],
    outputName: 'cls_8',
    fixedInputSize: 640,
    notes:
        'Static 1x3x640x640 float32 **BGR 0..255** (no normalisation). Twelve raw outputs cls_/obj_/bbox_/kps_{8,16,32}: '
        'score = sqrt(cls·obj), centre = anchor + bbox[:,:2]·stride, wh = exp(bbox[:,2:])·stride, kps = anchor + kps·stride; '
        'threshold 0.6, NMS IoU 0.3. Decode verified against cv2.FaceDetectorYN.',
    mirrorUrl: 'https://github.com/CTO-DRS/lumora-studio/releases/download/models-1.4/yunet.onnx',
  );

  /// MediaPipe Face Mesh exported to ONNX (478 landmarks = 468 mesh + 10
  /// iris points). URL pinned to the repo revision that carries the exact
  /// file; SHA-256 verified locally before registration.
  static const faceMesh = ModelSpec(
    id: 'facemesh',
    task: AiTask.faceLandmarks,
    displayName: 'MediaPipe Face Mesh – 478 landmarks',
    url:
        'https://huggingface.co/senty-au/face_landmarks_detector-ONNX/resolve/337d58218b5b1cc597ca3c67360880b920f6ce7b/onnx/model.onnx',
    sha256: '7d6e82dee82a1dca5fbddb282b3cc74571833a530de317fc22ae325c3358beeb',
    sizeBytes: 4920995,
    license: 'Apache-2.0 (Google MediaPipe)',
    source: 'https://github.com/google-ai-edge/mediapipe',
    inputNames: ['input_12'],
    outputName: 'Identity',
    notes:
        'NHWC float32 **RGB 0..1** [N,256,256,3] eyes-level aligned face crop. '
        'Identity [N,1,1434] = 478 landmarks × (x,y,z) in crop pixels; Identity_1 = face-presence logit (sigmoid); Identity_2 scalar.',
    mirrorUrl: 'https://github.com/CTO-DRS/lumora-studio/releases/download/models-1.4/facemesh.onnx',
  );

  /// SkySeg – a U²-Net fine-tune for sky segmentation (JianyuanWang/skyseg).
  /// The fp32 weights (sha256 ab9c34c6…, 176 MB) are far too heavy for
  /// phones, so this project ships a **static QOperator int8** quantisation
  /// (QUInt8 activations, QInt8 per-channel weights) calibrated on synthetic
  /// skies; IoU vs fp32 ≈ 0.99 on held-out scenes at ≈ 3× the speed. No
  /// upstream serves the int8 file, so the project release is the primary
  /// source – see the mirror workflow (`tool/mirror_models.py`).
  static const skysegInt8 = ModelSpec(
    id: 'skyseg_int8',
    task: AiTask.skySegmentation,
    displayName: 'SkySeg (U²-Net) – sky segmentation (int8)',
    url: 'https://github.com/CTO-DRS/lumora-studio/releases/download/models-1.4/skyseg_int8.onnx',
    sha256: '01c60b73595450b6ceac707055b8315dacbd5019344f1ecbb1b8becaebef2076',
    sizeBytes: 44247982,
    license: 'Apache-2.0 (U²-Net / JianyuanWang/skyseg)',
    source: 'https://huggingface.co/JianyuanWang/skyseg',
    inputNames: ['input.1'],
    outputName: '1959',
    fixedInputSize: 320,
    notes:
        'Static 1x3x320x320, ImageNet-normalised RGB. First output (d0): min-max normalise → soft sky matte, > 0.5 = sky. '
        'Locally quantised int8 of the fp32 weights (pinned HF revision 3ba8c6df…).',
  );

  static const List<ModelSpec> all = [
    u2netp,
    modnet,
    realEsrgan,
    migan,
    lama,
    mobileSamEncoder,
    mobileSamDecoderMulti,
    depthAnythingSmall,
    yunet,
    faceMesh,
    skysegInt8,
  ];

  /// Mirror release that carries every model with the identical SHA-256.
  static const mirrorReleaseUrl = 'https://github.com/CTO-DRS/lumora-studio/releases/tag/models-1.3';

  /// Mirror release for the v1.4 models.
  static const mirrorReleaseUrl14 = 'https://github.com/CTO-DRS/lumora-studio/releases/tag/models-1.4';

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
  // v1.4 – faces & sky.
  faceSkin,
  eyeBrighten,
  teethWhiten,
  skyEdit,
  skyReplace,
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
  AiTool.faceSkin || AiTool.eyeBrighten || AiTool.teethWhiten => const [
    ModelRegistry.yunet,
    ModelRegistry.faceMesh,
  ],
  AiTool.skyEdit || AiTool.skyReplace => const [ModelRegistry.skysegInt8],
};
