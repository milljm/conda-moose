#!/bin/bash
function exitIfReturnCode()
{
  if [ "$1" != "0" ]; then
    echo "ERROR: exiting with code $1"
    exit $1
  fi
}
function print_cmd()
{
  local p="$PWD/"
  local b="$BUILD_ROOT/"
  local cwd=${p/#$b/BUILD_ROOT/}
  # Use terminal color codes. 33 is yellow. 32 is green
  printf "\e[33m$cwd\e[0m: \e[32m$*\e[0m\n"
}

function print_and_run()
{
  print_cmd $*
  "$@"
}

##### Sanity checks #####
if ! conda build --help > /dev/null 2>&1; then
    printf "conda build not available\n"
    exit 1
fi

if ! [ -d "recipes" ]; then
    printf "recipes directory not found. This script must be executed while in the staged-recipes repository.\n"
    exit 1
fi

if [ -z "$CONDA_PREFIX" ]; then
    printf "CONDA_PREFIX not set.\n"
    exit 1
fi

# Get a topological sort of formulas we need to build
FORMULAS=`./get_formulas.py`
exitIfReturnCode $?
NECESSARY=`./get_formulas.py -d`
exitIfReturnCode $?
if [ -z "${FORMULAS}" ]; then
    printf "Nothing to do?!\n"
    exit 1
fi

# Warn if recipe changes may result in broken dependencies (not necessarily bad...
# As this can mean we have a libMesh update, that we do not wish to force on the
# public yet)

if [ "${FORMULAS}" != "${NECESSARY}" ]; then
    printf "Warning:
\tNot all recipes necessary in the dependency chain are going to
\tbe built! This may be fine if intentionally preventing something
\tfrom reaching certain users (like a libMesh update to moose-env
\tusers).\n\nBuilding only:\n"

    for formula in ${FORMULAS}; do
        printf "\t$(basename $formula)\n"
    done
    printf "\nWhile the dependency chain is:\n"
    for formula in ${NECESSARY}; do
        printf "\t$(basename $formula)\n"
    done
    printf "\n"
fi

# Clear any previous build environment
print_and_run conda build purge-all
exitIfReturnCode $?

for formula in ${FORMULAS}; do
    printf "Building $(basename $formula)...\n"
    print_and_run conda build -c https://mooseframework.org/conda/moose $formula
    exitIfReturnCode $?
done


if [ `uname` = 'Linux' ]; then
    ARCH='linux-64'
else
    ARCH='osx-64'
fi
printf "Uploading packages to server\n"
for formula in ${FORMULAS}; do
    echo DRYRUN: scp "${CONDA_PREFIX}/conda-bld/${ARCH}/${formula}"*.bz2 mooseframework.org:/var/moose/conda/moose/${ARCH}-64/
done
