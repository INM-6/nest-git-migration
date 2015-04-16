#!/bin/sh

set -e
set -x

mkdir -p $HOME/.matplotlib
cat > $HOME/.matplotlib/matplotlibrc <<EOF
    # ZYV
    backend : svg
EOF

# for static code analysis
# Extracting changed files between two commits

file_names=`git diff --name-only $TRAVIS_COMMIT_RANGE`

for f in $file_names; do
  if [ $f != *.h ] || [ $f != *.hpp ] || [ $f != *.cc ] || [ $f != *.cpp ] || [ $f != *.c ]; then
    continue
  fi
  echo "Checking file $f:"
  # filter .cpp .c .h .hpp
 
# clang format creates formatted file
  clang-format $f > tmp_out_"${arr_sha[1]}".txt
# clang compares the committed file and formatted file and writes the differences to another file
  diff $f tmp_out_"${arr_sha[1]}".txt > format_diff_"${arr_sha[1]}".diff
  if [ $? -ne 0 ]; then
    echo "There are differences in the formatting:"
    cat format_diff_"${arr_sha[1]}".diff
  fi
  rm format_diff_"${arr_sha[1]}".diff tmp_out_"${arr_sha[1]}".txt

# Vera++ checks the specified list of rules given in the profile nest which is placed in the <vera++ home>/lib/vera++/profile
  vera++ --profile nest $f
  cppcheck --enable=all --inconclusive --std=c++03 $f
done

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

