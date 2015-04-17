#!/bin/sh

set -e
set -x

mkdir -p $HOME/.matplotlib
cat > $HOME/.matplotlib/matplotlibrc <<EOF
    # ZYV
    backend : svg
EOF

# initialize vera++
mkdir -p vera_home

# on ubuntu vera++ is installed to /usr/
# copy all scripts/rules/ ... into ~/.vera++
cp -r /usr/lib/vera++/* ./vera_home
cat > ./vera_home/profiles/nest <<EOF
#!/usr/bin/tclsh
# This profile includes all the rules for checking NEST

set rules {
  F001
  F002
  L001
  L002
  L003
  L005
  L006
  T001
  T002
  T004
  T005
  T006
  T007
  T010
  T011
  T012
  T013
  T017
  T018
  T019
}
EOF

# Extracting changed files between two commits
file_names=`git diff --name-only $TRAVIS_COMMIT_RANGE`

for f in $file_names; do
   # filter files
  case $f in
    *.h | *.c | *.cc | *.hpp | *.cpp )
      echo "Checking file $f:"
      # Vera++ checks the specified list of rules given in the profile 
      # nest which is placed in the <vera++ home>/lib/vera++/profile
      vera++ --root ./vera_home --profile nest $f
      cppcheck --enable=all --inconclusive --std=c++03 $f
      
      # clang format creates tempory formatted file
      clang-format-3.6 $f > ${f}_formatted_$TRAVIS_COMMIT.txt
      # compare the committed file and formatted file and 
      # writes the differences to DIFF
      DIFF=$(diff $f ${f}_formatted_$TRAVIS_COMMIT.txt)
      if [ "$DIFF" != "" ]; then
        echo "There are differences in the formatting:"
        echo $DIFF
      fi
      # remove temporary files
      rm ${f}_formatted_$TRAVIS_COMMIT.txt
      ;;
    *)
      echo "$f : not a C/CPP file. Do not do static analysis / formatting checking."
      continue
  esac
done

exit 0

if [ "$xMPI" = "MPI+" ] ; then

   #openmpi
   export LD_LIBRARY_PATH="/usr/lib/openmpi/lib:$LD_LIBRARY_PATH"
   export CPATH="/usr/lib/openmpi/include:$CPATH"
   export PATH="/usr/include/mpi:$PATH"
   
cat > $HOME/.nestrc <<EOF
    % ZYV: NEST MPI configuration
    /mpirun
    [/integertype /stringtype]
    [/numproc     /slifile]
    {
     () [
      (mpirun -np ) numproc cvs ( ) statusdict/prefix :: (/bin/nest )  slifile
     ] {join} Fold
    } Function def
EOF
 
    CONFIGURE_MPI="--with-mpi"

else
    CONFIGURE_MPI="--without-mpi"
fi

if [ "$xPYTHON" = "PYTHON+" ] ; then
    CONFIGURE_PYTHON="--with-python"
else
    CONFIGURE_PYTHON="--without-python"
fi

if [ "$xGSL" = "GSL+" ] ; then
    CONFIGURE_GSL="--with-gsl"
else
    CONFIGURE_GSL="--without-gsl"
fi

./bootstrap.sh

NEST_VPATH=build
NEST_RESULT=result

mkdir "$NEST_VPATH" "$NEST_RESULT"

NEST_RESULT=$(readlink -f $NEST_RESULT)

cd "$NEST_VPATH"

../configure \
    --prefix="$NEST_RESULT"  CC=mpicc CXX=mpic++ \
    $CONFIGURE_MPI \
    $CONFIGURE_PYTHON \
    $CONFIGURE_GSL \


make
make install
make installcheck

# static code analysis
cd .. # go back to source dir

