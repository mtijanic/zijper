#!/bin/bash

modroot=$(dirname $0)

echo "-r $modroot/filters/clean_locstrs.rb \
-r $modroot/filters/fix_are_version.rb \
-r $modroot/filters/fix_facings.rb \
-r $modroot/filters/truncate_floats.rb"
