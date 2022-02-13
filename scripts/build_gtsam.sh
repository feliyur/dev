#! /usr/env bash

echo Downloading and installing gtsam
pushd ${HOME}/Research/
mkdir Libraries 
cd Libraries
git clone git@github.com:borglab/gtsam.git
cd gtsam
git checkout tags/4.1.1
mkdir build && cd build
cmake .. -DCMAKE_INSTALL_PREFIX="`pwd`/install" -DALLOW_DEPRECATED_SINCE_V4=OFF -DGTSAM_BUILD_PYTHON=ON -DGTSAM_POSE3_EXPMAP=ON -DGTSAM_ROT3_EXPMAP=ON -DGTSAM_PYTHON_VERSION=3.8 
make check -j 14 
make install -j 14

