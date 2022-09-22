#!/bin/bash



RED='\033[0;31m'
GREEN='\033[0;32m'
BLACK='\033[0m'


# while getopts r:b: flag
# do
#     case "${flag}" in
#         r) repo=${OPTARG};;
#         b) branch=${OPTARG};;
#           exit;;
#     esac
# done

# while getopts ":h" option; do
#    case $option in
#       h) # display Help
#          Help
#          exit;;
#    esac
# done

# Help()
# {
#    echo "Add description of the script functions here."
#    echo
#    echo "Syntax: scriptTemplate [-r|b]"
#    echo "options:"
#    echo "r     Give the Repo on which you want to work."
#    echo "b     Give the Branch Name."
#    echo
# }

# while getopts ":h" option; do
#    case $option in
#       h) # display Help
#          Help
#          exit;;
#    esac
# done

Clone_Magma () {

echo -e ${GREEN}#########################################
echo -e ${GREEN}#    **MAGMA REPO**                 
echo -e ${GREEN}#########################################${BLACK}

  DIR="$HOME/workspace-1/magma"
  if [ -d "$DIR" ]; then
    echo "Directory Exists ${DIR}"
  else
    mkdir $HOME/workspace-1 && cd $HOME/workspace-1
    sudo rm -rf magma
    git clone $repo
  fi

}

# while getopts r:b: flag
# do
#     case "${flag}" in
#         r) repo=${OPTARG};;
#         b) branch=${OPTARG};;
#     esac
# done

Magma_Branch () {
  cd magma
  git checkout $branch
  export MAGMA_ROOT=$HOME/workspace-1/magma
}

prerequisites() {

echo -e ${GREEN}#########################################
echo -e ${GREEN}#    *Pre-requisites**
echo -e ${GREEN}#########################################${BLACK}

  sudo curl -O https://releases.hashicorp.com/vagrant/2.2.19/vagrant_2.2.19_x86_64.deb
  sudo apt update
  sudo apt install ./vagrant_2.2.19_x86_64.deb
  vagrant plugin install vagrant-vbguest vagrant-disksize vagrant-vbguest vagrant-mutate vagrant-scp
  sudo apt install python3-pip
  pip3 install --upgrade pip
  pip3 install ansible fabric3 jsonpickle requests PyYAML firebase_admin
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> $HOME/.bashrc
  source $HOME/.bashrc
}

Open_network_interfaces () {
  sudo mkdir -p /etc/vbox/
  sudo touch /etc/vbox/networks.conf
  sudo sh -c "echo '* 192.168.0.0/16' > /etc/vbox/networks.conf"
  sudo sh -c "echo '* 3001::/64' >> /etc/vbox/networks.conf"
}

help()
{
   # Display Help
   echo "Add description of the script functions here."
   echo
   echo "Syntax: scriptTemplate [-r|b]"
   echo "options:"
   echo "r     Clone the repo."
   echo "h     For help."
   echo
}

SHORT=r:,b
LONG=help
OPTS=$(getopt -a -n magma --options $SHORT --longoptions $LONG -- "$@")

# VALID_ARGUMENTS=$# # Returns the count of arguments that are in short or long options

# if [ $# -eq 0 ]; then
#   echo "Hi"
# fi

if [[ $# -eq 0 ]] ; then
    echo 'Use "-h or --h flag"'
    exit 1
fi



eval set -- "$OPTS"

while :
do
  case "$1" in
    -r | --repo )
      repo="$2"
      shift 2
      ;;
    -b | --branch )
      branch="$2"
      shift 2
      ;;
    -h | --help)
      help
      exit
      ;;
    --)
      shift;
      break
      ;;
    *)
      echo "Unexpected option: $1"
      help
      ;;
  esac
done

Orc8r_build () {
  cd
  cd $MAGMA_ROOT/orc8r/cloud/docker
  ./build.py --deployment all
}

Save_Images () {
  cd
  rm -rf Image
  mkdir Image
  cd Image
  docker save orc8r_nginx:latest | gzip > fed_orc8r_nginx.tar.gz
  docker save orc8r_controller:latest  | gzip > fed_orc8r_controller.tar.gz
  docker save orc8r_fluentd:latest  | gzip > fed_orc8r_fluentd.tar.gz
  docker save orc8r_test:latest  | gzip > fed_orc8r_test.tar.gz
}

Build_feg () {
  cd
  cd $MAGMA_ROOT && mkdir -p .cache/test_certs/ && mkdir -p .cache/feg/
  cd $MAGMA_ROOT/.cache/feg/ && touch snowflake
  cd
  cd $MAGMA_ROOT/lte/gateway
  sed -i "s/-i ''/-i/" fabfile.py                        # to make fab-script work on linux/ubuntu system
  cd
  cd $MAGMA_ROOT/feg/gateway/docker
  docker-compose build --force-rm --parallel
  cd
  cd Image
  docker save feg_gateway_go:latest  | gzip > fed_feg_gateway_go.tar.gz
  docker save feg_gateway_python:latest  | gzip > fed_feg_gateway_python.tar.gz
}

Vagrant_host_prerequisites () {
  cd
  cd $MAGMA_ROOT/lte/gateway && fab open_orc8r_port_in_vagrant
}

Build_test_vms () {
  echo -e ${GREEN} Build test vms ${BLACK}
  cd
  cd $MAGMA_ROOT/lte/gateway && fab build_test_vms
  cd $MAGMA_ROOT/lte/gateway && vagrant halt magma_test && vagrant halt magma_trfserver
} 

Build_agw () {
  cd
  cd $MAGMA_ROOT/lte/gateway/python/integ_tests/federated_tests
  export MAGMA_DEV_CPUS=3
  export MAGMA_DEV_MEMORY_MB=9216
  fab build_agw
}

Load_Docker_Images (){ 
  set -x
  cd
  cd Image
  cp *.gz $MAGMA_ROOT/lte/gateway
  cd
  cd $MAGMA_ROOT/lte/gateway
  for IMAGE in `ls -a1 *.gz`
  do
    echo Image being loaded $IMAGE
    gzip -cd $IMAGE > image.tar
    vagrant ssh magma -c 'cat $MAGMA_ROOT/lte/gateway/image.tar | docker load'
    rm image.tar
  done
  mkdir -p /tmp/fed_integ_test-images
}

Fed_Integ_Test () {

echo -e ${GREEN}#########################################
echo -e ${GREEN}#    **FED INTEG TEST**                 
echo -e ${GREEN}#########################################${BLACK}

  cd $MAGMA_ROOT/lte/gateway
  export MAGMA_DEV_CPUS=3
  export MAGMA_DEV_MEMORY_MB=9216
  fab federated_integ_test:build_all=False,orc8r_on_vagrant=True
}


Clone_Magma
Magma_Branch
#Install_prerequisites
#Open_network_interfaces
Orc8r_build
Save_Images
Build_feg
Vagrant_host_prerequisites
Build_test_vms
Build_agw
Load_Docker_Images
Fed_Integ_Test