"""Static int8 quantization of the skyseg (U-2-Net sky segmentation) model,
with calibration images and a quality/latency comparison against fp32.

Outputs: skyseg_int8.onnx (static, QOperator), metrics printed.
"""
import numpy as np
import onnxruntime as ort
from PIL import Image, ImageDraw

MEAN = np.array([0.485, 0.456, 0.406], np.float32)
STD = np.array([0.229, 0.224, 0.225], np.float32)
SZ = 320


def prep(img_rgb):
    x = img_rgb.astype(np.float32) / 255.0
    x = (x - MEAN) / STD
    return np.ascontiguousarray(x.transpose(2, 0, 1)[None].astype(np.float32))


def sky_mask(out0):
    m = out0[0, 0]
    m = (m - m.min()) / (m.max() - m.min() + 1e-9)
    return m > 0.5


def synth(seed, sky_frac, sky_top, sky_bottom, ground, buildings=True, overcast=False):
    rng = np.random.default_rng(seed)
    img = np.zeros((SZ, SZ, 3), np.uint8)
    h = int(SZ * sky_frac)
    top = np.array(sky_top, np.float32)
    bot = np.array(sky_bottom, np.float32)
    for y in range(h):
        t = y / max(1, h - 1)
        img[y, :] = (top * (1 - t) + bot * t).astype(np.uint8)
    if overcast:
        noise = rng.integers(-8, 9, (h, SZ, 1))
        img[:h] = np.clip(img[:h].astype(np.int16) + noise, 0, 255).astype(np.uint8)
    img[h:] = np.array(ground, np.uint8)
    if buildings:
        x = 0
        while x < SZ:
            w = rng.integers(24, 70)
            bh = rng.integers(30, 110)
            img[max(0, h - bh):, x:x + w] = rng.integers(40, 110, 3)
            x += w + rng.integers(4, 20)
    return img


def make_calibration():
    imgs = []
    combos = [
        (0.45, [120, 190, 250], [230, 200, 150], [70, 90, 60], False, False),
        (0.35, [60, 120, 200], [140, 180, 220], [80, 70, 55], True, False),
        (0.55, [200, 205, 210], [225, 225, 230], [60, 65, 60], True, True),
        (0.30, [25, 60, 120], [80, 110, 160], [90, 80, 65], True, False),
        (0.50, [250, 170, 110], [255, 220, 160], [60, 80, 70], False, False),
        (0.40, [40, 40, 60], [90, 90, 120], [35, 40, 35], True, True),
    ]
    for i, (f, a, b, g, bld, ovc) in enumerate(combos):
        imgs.append(synth(1000 + i, f, a, b, g, bld, ovc))
    return imgs


def main():
    so = ort.SessionOptions()
    so.intra_op_num_threads = 2

    calib = make_calibration()

    # Tests: two held-out synthetic scenes
    t1 = synth(7, 0.42, [110, 170, 240], [220, 210, 170], [75, 85, 60], True, False)
    t2 = synth(9, 0.55, [230, 230, 235], [245, 245, 248], [55, 70, 50], True, True)
    Image.fromarray(t1).save("test_a.png")
    Image.fromarray(t2).save("test_b.png")
    tests = [t1, t2]

    s32 = ort.InferenceSession("skyseg.onnx", so, ["CPUExecutionProvider"])

    def iou(a, b):
        return (a & b).sum() / max(1, (a | b).sum())

    fp32_masks, fp32_ms = [], []
    for t in tests:
        x = prep(t)
        o = s32.run(None, {"input.1": x})[0]
        fp32_masks.append(sky_mask(o))
        t0 = time_count = __import__("time").time()
        for _ in range(3):
            s32.run(None, {"input.1": x})
        fp32_ms.append((__import__("time").time() - t0) / 3 * 1000)

    # Calibration data for static quantization
    from onnxruntime.quantization import CalibrationDataReader, quantize_static, QuantType

    class ListReader(CalibrationDataReader):
        def __init__(self, xs):
            self.it = iter(xs)

        def get_next(self):
            v = next(self.it, None)
            return None if v is None else {"input.1": v}

    calib_inputs = [prep(c) for c in calib]
    quantize_static(
        "skyseg.onnx",
        "skyseg_int8.onnx",
        ListReader(calib_inputs),
        quant_format=__import__("onnxruntime.quantization", fromlist=["QuantFormat"]).QuantFormat.QOperator,
        activation_type=QuantType.QUInt8,
        weight_type=QuantType.QInt8,
        per_channel=True,
    )

    import os
    print("int8 size:", os.path.getsize("skyseg_int8.onnx"), "bytes")

    s8 = ort.InferenceSession("skyseg_int8.onnx", so, ["CPUExecutionProvider"])
    ious, ms = [], []
    for t, mref in zip(tests, fp32_masks):
        x = prep(t)
        o = s8.run(None, {"input.1": x})[0]
        ious.append(iou(sky_mask(o), mref))
        t0 = __import__("time").time()
        for _ in range(3):
            s8.run(None, {"input.1": x})
        ms.append((__import__("time").time() - t0) / 3 * 1000)

    print("fp32 latencies (ms):", [f"{v:.0f}" for v in fp32_ms])
    print("int8 latencies (ms):", [f"{v:.0f}" for v in ms])
    print("IoU int8 vs fp32:", [f"{v:.3f}" for v in ious])


if __name__ == "__main__":
    main()
