import os
os.environ['TF_CPP_MIN_LOG_LEVEL'] = '3'
import sys, collections, time
sys.path.insert(0, '/tmp/maxim')
t0=time.time()
import numpy as np, jax.numpy as jnp, flax
import tensorflow as tf
tf.get_logger().setLevel('ERROR')
from jax.experimental import jax2tf
import maxim.models.maxim as M
print('imports', round(time.time()-t0,1), flush=True)

def recover_tree(keys, values):
    tree = {}; sub_trees = collections.defaultdict(list)
    for k, v in zip(keys, values):
        if '/' not in k: tree[k] = v
        else:
            l, r = k.split('/', 1); sub_trees[l].append((r, v))
    for k, kv in sub_trees.items():
        ks, vs = zip(*kv); tree[k] = recover_tree(ks, vs)
    return tree

values = np.load('/tmp/maxim-lol-checkpoint.npz')
params = recover_tree(*zip(*values.items()))['opt']['target']
model = M.Model(variant='S-2', dropout_rate=0.0, num_outputs=3, use_bias=True, num_supervision_scales=3)
fp = flax.core.freeze(params)

def f(x):
    preds = model.apply({'params': fp}, x)
    while isinstance(preds, list): preds = preds[-1]
    return preds

tf_f = jax2tf.convert(f, enable_xla=False)
mod = tf.Module()
mod.f = tf.function(tf_f, input_signature=[tf.TensorSpec([1, 256, 256, 3], tf.float32)], autograph=False)
conc = mod.f.get_concrete_function()  # trace only, no execution
print('traced', round(time.time()-t0,1), flush=True)
from tensorflow.python.framework.convert_to_constants import convert_variables_to_constants_v2
frozen = convert_variables_to_constants_v2(conc)
print('frozen', round(time.time()-t0,1), flush=True)
with open('/tmp/maxim_frozen.pb','wb') as fh:
    fh.write(frozen.graph.as_graph_def().SerializeToString())
print('pb written', round(time.time()-t0,1), flush=True)
with open('/tmp/maxim_io.txt','w') as fh:
    fh.write(','.join(t.name for t in frozen.inputs)+'\n')
    fh.write(','.join(t.name for t in frozen.outputs)+'\n')
print('inputs', [t.name for t in frozen.inputs], 'outputs', [t.name for t in frozen.outputs], flush=True)
