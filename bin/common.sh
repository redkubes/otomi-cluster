#!/usr/bin/env bash
set -e
export CLOUD=$1
export CLUSTER=$2
export DRY=$3

[[ -z $ENVC_DIR ]] && echo "ENVC_DIR must be set" && exit 1
# . $ENVC_DIR/clouds/.env
[[ -z $CLOUD || -z $CLUSTER ]] && echo "CLOUD and CLUSTER must be set" && exit 1
. $ENVC_DIR/clouds/$CLOUD/.env


# get the yaml value at a certain path
_y() {
  yq m -x $ENVC_DIR/clouds/$CLOUD/default.yaml $ENVC_DIR/clouds/$CLOUD/$CLUSTER.yaml | yq r - $@ --stripComments
}

m() {
  first=$(_y $1 -j)
  second=$(_y $2 -j)
  [ -z "$first" ] && first="{}"
  [ -z "$second" ] && second="{}"
  echo $first $second | jq -s '.[0] * .[1]'
}

l() {
  local json=$(m $@)
  echo $json | jq -r 'to_entries|map("\(.key)=\(.value|tostring)")|join(",")'
}

# check to see if 'enabled' flag is true for object at path given
ye() {
  [[ $(_y $1 enabled) != 'true' ]] && return 1
}

# y, the YAML selector util
# input: $1 = path, $2 = key
# 1. when both path and key given: returns the value
# 2. when only path is given: return the object properties found and return as one string as flags
#    Exceptions:
#    - when a key has value 'true', that value is omitted
#    - when a key has value 'false', both that key and it's value are omitted
#
# Examples below given below taking following structure into account:
#
# root:
#   prop1: val1
#   prop2: true
#   prop3: false
# emptyRoot:
#
# 1. y root prop1 > val1
# 2. y root > '--prop1 val1 --prop2'
# 3. y emptyRoot > exit 1
y() {
  if [ -n "$2" ]; then
    # key given
    if [ "$1" = '.' ]; then
      val=$(_y "$2")
    else
      val=$(_y "$1[$2]")
    fi
    echo $val
  else
    dict="$(_y "$1" -j)"
    { [ "$dict" = '' ] || [ "$dict" = 'null' ]; } && return 1
    while IFS="=" read -r key val; do
      # not interested in our own flag our boolean false:
      { [ "$key" = "enabled" ] || [ "$val" = 'false' ]; } && continue 
      printf -- "--%s" $key
      # for bools only print key:
      [ "$val" = 'true' ] && continue
      printf " '%s' " $val
    done < <(jq -r "to_entries|map(\"\(.key)=\(.value|tostring)\")|.[]" <<<"$dict")
  fi
}

check_env() {
  envs="$VALID_CLUSTERS"
  if [[ ! $envs == *$CLUSTER* ]]; then
    echo "Error: no such cluster: $CLUSTER. Valid clusters: $VALID_CLUSTERS"
    return 1
  fi
}
