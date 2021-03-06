from __future__ import absolute_import
from __future__ import division
from __future__ import print_function

import argparse
import os.path
import re
import sys
import tarfile
import glob

import numpy as np
from six.moves import urllib
import tensorflow as tf

FLAGS = None

# pylint: disable=line-too-long
DATA_URL = 'http://download.tensorflow.org/models/image/imagenet/inception-2015-12-05.tgz'
# pylint: enable=line-too-long

# https://stackoverflow.com/questions/38096689/edit-tensorflow-inceptionv3-retraining-example-py-for-multiple-classificiations/38233104#38233104

def make_full_path(relative_path, dest_dir):
  (dirname, filename) = os.path.split(relative_path)
  (filename, _) = os.path.splitext(filename)
  dirname = os.path.join(dest_dir, dirname)
  if not os.path.exists(dirname):
    os.makedirs(dirname)
  return os.path.join(dirname, filename + '.txt')

def process_directory(root_dir, path_pattern, dest_dir, overwrite):
  full_path = os.path.join(root_dir, path_pattern)

  # Creates graph from saved GraphDef.
  create_graph()

  with tf.Session() as sess:
    # Some useful tensors:
    # 'softmax:0': A tensor containing the normalized prediction across
    #   1000 labels.
    # 'pool_3:0': A tensor containing the next-to-last layer containing 2048
    #   float description of the image.
    # 'DecodeJpeg/contents:0': A tensor containing a string providing JPEG
    #   encoding of the image.
    # Runs the softmax tensor by feeding the image_data as input to the graph.
    softmax_tensor = sess.graph.get_tensor_by_name('softmax:0')

    print('Start classification')
    for image_path in sorted(glob.glob(full_path)):
      relative_path = image_path[len(root_dir) + 1:]
      classify_dest_path = make_full_path(relative_path, dest_dir)
      if not overwrite and os.path.exists(classify_dest_path):
        print('File %s already exists, skipped' % (classify_dest_path))
      else:
        print('Classifying %s into %s' % (image_path, classify_dest_path))
        file = open(classify_dest_path, 'wb')
        file.write('image: ' + relative_path + '\n')
        run_inference_on_image(sess, softmax_tensor, image_path, file)
        file.close()

class NodeLookup(object):
  """Converts integer node ID's to human readable labels."""

  def __init__(self,
               label_lookup_path=None,
               uid_lookup_path=None):
    if not label_lookup_path:
      label_lookup_path = os.path.join(
          FLAGS.model_dir, 'imagenet_2012_challenge_label_map_proto.pbtxt')
    if not uid_lookup_path:
      uid_lookup_path = os.path.join(
          FLAGS.model_dir, 'imagenet_synset_to_human_label_map.txt')
    self.node_lookup = self.load(label_lookup_path, uid_lookup_path)

  def load(self, label_lookup_path, uid_lookup_path):
    """Loads a human readable English name for each softmax node.

    Args:
      label_lookup_path: string UID to integer node ID.
      uid_lookup_path: string UID to human-readable string.

    Returns:
      dict from integer node ID to human-readable string.
    """
    if not tf.gfile.Exists(uid_lookup_path):
      tf.logging.fatal('File does not exist %s', uid_lookup_path)
    if not tf.gfile.Exists(label_lookup_path):
      tf.logging.fatal('File does not exist %s', label_lookup_path)

    # Loads mapping from string UID to human-readable string
    proto_as_ascii_lines = tf.gfile.GFile(uid_lookup_path).readlines()
    uid_to_human = {}
    p = re.compile(r'[n\d]*[ \S,]*')
    for line in proto_as_ascii_lines:
      parsed_items = p.findall(line)
      uid = parsed_items[0]
      human_string = parsed_items[2]
      uid_to_human[uid] = human_string

    # Loads mapping from string UID to integer node ID.
    node_id_to_uid = {}
    proto_as_ascii = tf.gfile.GFile(label_lookup_path).readlines()
    for line in proto_as_ascii:
      if line.startswith('  target_class:'):
        target_class = int(line.split(': ')[1])
      if line.startswith('  target_class_string:'):
        target_class_string = line.split(': ')[1]
        node_id_to_uid[target_class] = target_class_string[1:-2]

    # Loads the final mapping of integer node ID to human-readable string
    node_id_to_name = {}
    for key, val in node_id_to_uid.items():
      if val not in uid_to_human:
        tf.logging.fatal('Failed to locate: %s', val)
      name = uid_to_human[val]
      node_id_to_name[key] = name

    return node_id_to_name

  def id_to_string(self, node_id):
    if node_id not in self.node_lookup:
      return ''
    return self.node_lookup[node_id]

def create_graph():
  """Creates a graph from saved GraphDef file and returns a saver."""
  # Creates graph from saved graph_def.pb.
  with tf.gfile.FastGFile(os.path.join(
      FLAGS.model_dir, 'classify_image_graph_def.pb'), 'rb') as f:
    graph_def = tf.GraphDef()
    graph_def.ParseFromString(f.read())
    _ = tf.import_graph_def(graph_def, name='')

def run_inference_on_image(sess, softmax_tensor, image, output_file):
  """Runs inference on an image.

  Args:
    image: Image file name.

  Returns:
    Nothing
  """
  image_data = tf.gfile.FastGFile(image, 'rb').read()

  predictions = sess.run(softmax_tensor,
                         {'DecodeJpeg/contents:0': image_data})
  predictions = np.squeeze(predictions)

  # Creates node ID --> English string lookup.
  node_lookup = NodeLookup()

  top_k = predictions.argsort()[-FLAGS.num_top_predictions:][::-1]
  score_line = 1
  for node_id in top_k:
    human_string = node_lookup.id_to_string(node_id)
    score = predictions[node_id]
    output_file.write('score %d: %s (score = %.5f)\n' % (score_line, human_string, score))
    score_line = score_line + 1

def maybe_download_and_extract():
  """Download and extract model tar file."""
  dest_directory = FLAGS.model_dir
  if not os.path.exists(dest_directory):
    os.makedirs(dest_directory)
  filename = DATA_URL.split('/')[-1]
  filepath = os.path.join(dest_directory, filename)
  if not os.path.exists(filepath):
    def _progress(count, block_size, total_size):
      sys.stdout.write('\r>> Downloading %s %.1f%%' % (
          filename, float(count * block_size) / float(total_size) * 100.0))
      sys.stdout.flush()
    filepath, _ = urllib.request.urlretrieve(DATA_URL, filepath, _progress)
    print()
    statinfo = os.stat(filepath)
    print('Successfully downloaded', filename, statinfo.st_size, 'bytes.')
  tarfile.open(filepath, 'r:gz').extractall(dest_directory)

def main(_):
  # Normalize paths
  FLAGS.root_dir = os.path.expanduser(FLAGS.root_dir)
  FLAGS.dest_dir = os.path.expanduser(FLAGS.dest_dir)
  FLAGS.model_dir = os.path.expanduser(FLAGS.model_dir)
  print('Loading model...')
  maybe_download_and_extract()
  print('Model loaded')
  process_directory(FLAGS.root_dir, FLAGS.path_pattern, FLAGS.dest_dir, False)

if __name__ == '__main__':
  parser = argparse.ArgumentParser()

  parser.add_argument(
    '--root_dir',
    type=str,
    help='Image root directory',
    required=True
  )
  parser.add_argument(
    '--path_pattern',
    type=str,
    help="The path to use to find images (eg. **/250/**.jpg)",
    required=True
  )
  parser.add_argument(
    '--dest_dir',
    type=str,
    help="The directory where to write classification files",
    required=True
  )

  # classify_image_graph_def.pb:
  #   Binary representation of the GraphDef protocol buffer.
  # imagenet_synset_to_human_label_map.txt:
  #   Map from synset ID to a human readable string.
  # imagenet_2012_challenge_label_map_proto.pbtxt:
  #   Text representation of a protocol buffer mapping a label to synset ID.
  parser.add_argument(
      '--model_dir',
      type=str,
      help="""\
      Path to classify_image_graph_def.pb,
      imagenet_synset_to_human_label_map.txt, and
      imagenet_2012_challenge_label_map_proto.pbtxt.\
      """,
      required=True
  )
  parser.add_argument(
      '--num_top_predictions',
      type=int,
      default=5,
      help='Display this many predictions.'
  )
  FLAGS, unparsed = parser.parse_known_args()
  tf.app.run(main=main, argv=[sys.argv[0]] + unparsed)
  # main()
