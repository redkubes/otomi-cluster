#!/usr/bin/env bash
set -e
. bin/common.sh

! check_env && exit 1

# build files
readonly build_loc=$ENVC_DIR/build/$CLOUD/$CLUSTER
readonly create_script=$build_loc/$CLOUD-create.sh
mkdir -p $build_loc &>/dev/null

# build the command script
. tpl/$CLOUD-create.sh >$create_script

echo  "DRY: $DRY"
exit
if [ -z "$DRY" ]; then
  # source the script
  . $create_script
else
  # dry run so just cat the script
  cat $create_script
fi