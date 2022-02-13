#! /bin/bash


pushd ~

if [ ! -f .ssh/id_rsa.pub ]; then
    printf "SSH key not found. Generating a new one. "
    sudo apt-get install xclip -y 
    ssh-keygen -t rsa -b 4096 -C "yurif@cs.technion.ac.il"
    cat .ssh/id_rsa.pub | xclip -selection clipboard
    printf "New SSH key was copied to clipboard (if you're on the local machine). Add it to bitbucket account and re-run script."
    popd 
    exit 0
fi


echo "source ${HOME}/scripts/set_env_yuri.sh" >> ${HOME}/.bashrc

mkdir Research
pushd Research
git clone git@bitbucket.org:feliyur/yuriresearchcode.git code
popd


# Install virtualenvwrapper 
echo Installing virtualenvwrapper...
sudo pip3 install virtualenvwrapper

WORKON_HOME=${HOME}/virtualenvs
echo "export WORKON_HOME="${WORKON_HOME} >> ${HOME}/.bashrc
echo "export VIRTUALENVWRAPPER_PYTHON="`which python3` >> ${HOME}/.bashrc
echo "source /usr/local/bin/virtualenvwrapper.sh" >> ${HOME}/.bashrc

echo Installed virtualenvwrapper
popd

source ~/.bashrc

echo Setting up a virtual environment for development
mkvirtualenv lsmi -p python3.8
pushd ${HOME}/Research/code
pip install -r lsmi/src/requirements.txt
pip install -e .
cd lsmi
setvirtualenvproject
popd
deactivate
echo Finished setting up virtual environment.


echo Building and installing gtsam
workon lsmi
source ${HOME}/scripts/build_gtsam.sh
pushd ${HOME}/Research/Libraries/gtsam/build/python
pip install -e .
popd
deactivate

