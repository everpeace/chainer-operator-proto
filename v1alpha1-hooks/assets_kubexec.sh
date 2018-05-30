#! /bin/sh

pod=$1
shift

if [ "$pod" = $(hostname) ]; then
  $@
else
  ${KUBCTL} exec -i $pod -- $@
fi
