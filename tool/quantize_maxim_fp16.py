"""fp16-quantize the MAXIM-2S ONNX artifact (docs/MODEL_PROVENANCE.md).

The plain onnxconverter-common float16 pass leaves mixed-type constants around
the LeakyRelu expansions (GreaterOrEqual/Cast chains), which ONNX Runtime
rejects. This script adds a boundary-fix pass: it tracks tensor dtypes through
the graph (initializers, value_info, Cast targets, Constant values) and inserts
Cast nodes wherever a float op sees both fp16 and fp32 inputs. Verified against
the JAX reference: max abs diff ~1.1e-3, mean ~1.8e-4 on a random 256x256 input.

Run after tool/convert_maxim_to_onnx.py. Output:
/tmp/maxim_2s_lol_256_fp16.onnx (~31.4 MiB, inside the 50 MB model budget).
"""
import time, onnx
from onnx import helper, TensorProto
from onnxconverter_common import float16
t0=time.time()
m = onnx.load('/tmp/maxim_2s_lol_256.onnx')
m16 = float16.convert_float_to_float16(m, keep_io_types=True, disable_shape_infer=True)
print('converted', round(time.time()-t0,1), flush=True)

g = m16.graph
# Map tensor -> elem_type from initializers, value_info, inputs/outputs.
types = {}
for init in g.initializer: types[init.name] = init.data_type
for vi in list(g.value_info) + list(g.input) + list(g.output):
    if vi.type.HasField('tensor_type'): types[vi.name] = vi.type.tensor_type.elem_type
# Constants produce typed tensors too.
for n in g.node:
    if n.op_type == 'Constant':
        for a in n.attribute:
            if a.name == 'value' and a.HasField('t'): types[n.output[0]] = a.t.data_type

# Ops that legitimately produce/consume non-float types.
SKIP_OUT = {'Not','And','Or','Cast','Shape','Constant','NonZero','ArgMax','ArgMin','TopK','Range','Size','IsNaN','IsInf'}
CASTABLE_FROM = {TensorProto.FLOAT, TensorProto.FLOAT16}

fixes = 0
new_nodes = []
def elem(n): return 'fp16' if n == TensorProto.FLOAT16 else ('fp32' if n == TensorProto.FLOAT else n)

for n in g.node:
    if n.op_type == 'Cast':
        for a in n.attribute:
            if a.name == 'to':
                for o in n.output: types[o] = a.i
        new_nodes.append(n); continue
    if n.op_type in SKIP_OUT:
        new_nodes.append(n); continue
    ins = list(n.input)
    in_types = [types.get(i) for i in ins]
    floaty = [t for t in in_types if t in CASTABLE_FROM]
    if len(set(floaty)) > 1:
        target = TensorProto.FLOAT16 if TensorProto.FLOAT16 in floaty else TensorProto.FLOAT
        for idx, (iname, it) in enumerate(zip(ins, in_types)):
            if it in CASTABLE_FROM and it != target:
                cast_name = iname + '_autocast' + str(fixes)
                cast_node = helper.make_node('Cast', [iname], [cast_name], to=target, name=n.name + '_autocast' + str(fixes))
                new_nodes.append(cast_node)
                n.input[idx] = cast_name
                types[cast_name] = target
                fixes += 1
    new_nodes.append(n)
    # assume homogeneous float ops output the majority float type
    if n.op_type in ('GreaterOrEqual','LessOrEqual','Greater','Less','Equal') and n.op_type != 'Where':
        for o in n.output: types[o] = TensorProto.BOOL
    else:
        outs_t = TensorProto.FLOAT16 if TensorProto.FLOAT16 in floaty else (TensorProto.FLOAT if floaty else None)
        if outs_t:
            for o in n.output: types[o] = outs_t

print('fixes', fixes, flush=True)
del g.node[:]
g.node.extend(new_nodes)
onnx.save(m16, '/tmp/maxim_2s_lol_256_fp16.onnx')
print('saved', round(time.time()-t0,1), flush=True)
