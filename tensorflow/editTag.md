### Tensorflow


1. Install Tensorflow
2. Install [Models repo](https://www.tensorflow.org/tutorials/image_recognition#usage_with_python_api)

### Classify images

An entire directory can be classified recursively

Run `run_classifier.sh` setting correctly the `root_dir` and `path_pattern` arguments

When the script completes, the directory `results` contains the classified files, optionally tar and save it

	tar zcvf classify.tgz results

#### File format

The file contains 6 lines, the first is the relative path to image, the others contain the score ordered from most relevant to less relevant

	image: relative image path
	score 1: best result
	...
	score 5: worst result

### Browse images by category

Suppose you want to view only the images classified under the category `panda`, this is possible creating symbolic links to the original images all in the same directory (to make easy browsing)

Run the script `mk_syms.sh` passing the pattern to search, for example the best result (score equals to `1`) for panda

	mk_syms.sh -i directory -p "score 1:.*panda"
	
Could be important to setup directories used by the script

### Create post ids list

The choosen images can be saved as list then passed to Photoshelf app

	ls -1R matching/ | sed 's/.jpg//' > postIdList.txt
