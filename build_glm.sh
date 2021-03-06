#!/bin/bash

if [ "$GLM_CONFIGURED" != "true" ] ; then
  . ./GLM_CONFIG
fi

while [ $# -gt 0 ] ; do
  case $1 in
    --debug)
      export DEBUG=true
      ;;
    --fence)
      export FENCE=true
      ;;
    --fabm)
      export FABM=true
      ;;
    --ifort)
      export FC=ifort
      ;;
    *)
      ;;
  esac
  shift
done

export OSTYPE=`uname -s`
if [ "$OSTYPE" == "Darwin" ] ; then
  if [ "$HOMEBREW" = "" ] ; then
    brew -v >& /dev/null
    if [ $? != 0 ] ; then
      which port >& /dev/null
      if [ $? != 0 ] ; then
        echo no ports and no brew
      else
        export MACPORTS=true
      fi
    else
      export HOMEBREW=true
    fi
  fi
fi


# if FC is not defined we look for gfortran-8 first because some systems
# will have gfortran at version 7 but also gfortran version 8 as gfortran-8
# if we can't find gfortran default to ifort
if [ "$FC" = "" ] ; then
  gfortran-8 -v >& /dev/null
  if [ $? != 0 ] ; then
    gfortran -v >& /dev/null
    if [ $? != 0 ] ; then
      export FC=ifort
    else
      VERS=`gfortran -dumpversion | cut -d\. -f1`
      if [ $VERS -ge 8 ] ; then
        export FC=gfortran
      else
        export FC=ifort
      fi
    fi
  else
    export FC=gfortran-8
  fi
fi

if [ "$FC" = "ifort" ] ; then
   if [ -d /opt/intel/bin ] ; then
      . /opt/intel/bin/compilervars.sh intel64
   fi
   which ifort >& /dev/null
   if [ $? != 0 ] ; then
      echo ifort compiler requested, but not found
      exit 1
   fi
fi

export F77=$FC
export F90=$FC
export F95=$FC

export MPI=OPENMPI

if [ "$PLOTDIR" = "" ] ; then
  export PLOTDIR=../libplot
fi
if [ "$UTILDIR" = "" ] ; then
  export UTILDIR=../libutil
fi

if [ "$FABM" = "true" ] ; then
  if [ ! -d $FABMDIR ] ; then
    echo "FABM directory not found"
    export FABM=false
  else
    which cmake >& /dev/null
    if [ $? != 0 ] ; then
      echo "cmake not found - FABM cannot be built"
      export FABM=false
    fi
  fi
  if [ "$FABM" = "false" ] ; then
    echo build with FABM requested but FABM cannot be built
    exit 1
  fi

  export FABMHOST=glm
  cd ${FABMDIR}
  if [ ! -d build ] ; then
    mkdir build
  fi
  cd build
  export FFLAGS+=-fPIC
  if [ "${USE_DL}" = "true" ] ; then
    cmake ${FABMDIR}/src -DBUILD_SHARED_LIBS=1 || exit 1
  else
    cmake ${FABMDIR}/src || exit 1
  fi
  make || exit 1
fi

if [ "${AED}" = "true" ] ; then
  cd  ${CURDIR}/../libaed-water
  make || exit 1
  DAEDWATDIR=`pwd`
  if [ -d ${CURDIR}/../libaed-benthic ] ; then
    echo build libaed-benthic
    cd  ${CURDIR}/../libaed-benthic
    make || exit 1
    DAEDBENDIR=`pwd`
  fi
  if [ -d ${CURDIR}/../libaed-riparian ] ; then
    echo build libaed-riparian
    cd  ${CURDIR}/../libaed-riparian
    make || exit 1
    DAEDRIPDIR=`pwd`
  fi
  if [ -d ${CURDIR}/../libaed-demo ] ; then
    echo build libaed-demo
    cd  ${CURDIR}/../libaed-demo
    make || exit 1
    DAEDDMODIR=`pwd`
  fi
  if [ -d ${CURDIR}/../libaed-dev ] ; then
    echo build libaed-dev
    cd  ${CURDIR}/../libaed-dev
    make || exit 1
    DAEDDEVDIR=`pwd`
  fi
fi

if [ "$WITH_PLOTS" = "true" ] ; then
  cd ${PLOTDIR}
  make || exit 1
fi

cd ${UTILDIR}
make || exit 1

cd ${CURDIR}
/bin/rm obj/aed_external.o
make AEDBENDIR=$DAEDBENDIR AEDDMODIR=$DAEDDMODIR || exit 1
/bin/rm obj/aed_external.o
make glm+ AEDBENDIR=$DAEDBENDIR AEDDMODIR=$DAEDDMODIR AEDRIPDIR=$DAEDRIPDIR AEDDEVDIR=$DAEDDEVDIR || exit 1

exit 0
