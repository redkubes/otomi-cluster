#!/usr/bin/env bash
set -e
. bin/common.sh

# build files
readonly build_loc=$ENVC_DIR/build/$CLOUD/$CLUSTER
readonly build_loc_rel=./build/$CLOUD/$CLUSTER
readonly create_script=$build_loc/create.sh
mkdir -p $build_loc &>/dev/null

# build the command script
. tpl/$CLOUD-create.sh >$create_script

chmod 744 $create_script

if [ -z "$DRY" ]; then
  # source the script
  pushd $ENVC_DIR
  . $create_script
  popd
else
  # dry run so just cat the script
  cat $create_script
fi
