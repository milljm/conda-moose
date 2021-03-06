#!/bin/bash
set -eu
export PKG_CONFIG_PATH=$BUILD_PREFIX/lib/pkgconfig:$PKG_CONFIG_PATH
export PETSC_DIR=`pkg-config PETSc --variable=prefix`
if [ -z $PETSC_DIR ]; then
    printf "PETSC not found.\n"
    exit 1
fi

function sed_replace(){
    if [ `uname` = "Darwin" ]; then
        sed -i '' -e "s|${BUILD_PREFIX}|${PREFIX}|g" $PREFIX/libmesh/bin/libmesh-config
    else
        sed -i'' -e "s|${BUILD_PREFIX}|${PREFIX}|g" $PREFIX/libmesh/bin/libmesh-config
    fi
}

mv metaphysicl src/github.com/libMesh/libmesh/contrib/
mkdir -p src/github.com/libMesh/build
cd src/github.com/libMesh/build
unset LIBMESH_DIR
export F90=mpif90
export F77=mpif77
export FC=mpif90
export CC=mpicc
export CXX=mpicxx
if [[ $(uname) == Linux ]]; then
    export LDFLAGS="-pthread -fopenmp $LDFLAGS"
    export LDFLAGS="$LDFLAGS -Wl,-rpath-link,$PREFIX/lib"
else
    export LDFLAGS="$LDFLAGS -Wl,-rpath,$PREFIX/lib"
fi

if [[ $mpi == "openmpi" ]]; then
  export OMPI_MCA_plm=isolated
  export OMPI_MCA_rmaps_base_oversubscribe=yes
  export OMPI_MCA_btl_vader_single_copy_mechanism=none
elif [[ $mpi == "moose-mpich" ]]; then
  export HYDRA_LAUNCHER=fork
fi

BUILD_CONFIG=`cat <<EOF
--prefix=${PREFIX}/libmesh \
--enable-silent-rules \
--enable-unique-id \
--disable-warnings \
--enable-glibcxx-debugging \
--with-thread-model=openmp \
--disable-maintainer-mode \
--enable-petsc-hypre-required \
--enable-metaphysicl-required \
--with-vtk-lib=${BUILD_PREFIX}/libmesh-vtk/lib \
--with-vtk-include=${BUILD_PREFIX}/libmesh-vtk/include/vtk-${SHORT_VTK_NAME}
EOF`

../libmesh/configure ${BUILD_CONFIG} \
                     --with-methods="opt dbg devel"

make -j $CPU_COUNT
make install
sed_replace

# Set LIBMESH_DIR environment variable for those that need it
mkdir -p "${PREFIX}/etc/conda/activate.d" "${PREFIX}/etc/conda/deactivate.d"
cat <<EOF > "${PREFIX}/etc/conda/activate.d/activate_${PKG_NAME}.sh"
export LIBMESH_DIR=${PREFIX}/libmesh
EOF
cat <<EOF > "${PREFIX}/etc/conda/deactivate.d/deactivate_${PKG_NAME}.sh"
unset LIBMESH_DIR
unset MOOSE_NO_CODESIGN
EOF
