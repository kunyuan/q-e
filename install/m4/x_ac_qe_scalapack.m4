# Copyright (C) 2001-2016 Quantum ESPRESSO Foundation

AC_DEFUN([X_AC_QE_SCALAPACK], [

have_scalapack=0

AC_ARG_WITH(scalapack,
   [AS_HELP_STRING([--with-scalapack],
       [(yes|no|intel) Use scalapack if available. Set to "intel" to use Intel MPI and blacs (default: use openMPI)])],
   [if  test "$withval" = "yes" ; then
      with_scalapack=1
   elif  test "$withval" = "intel" ; then
      with_scalapack=2
   elif  test "$withval" = "no" ; then
      with_scalapack=0
   fi],
   [with_scalapack=1])

# final check on availability of parallel environment
for dummy in x # to allow simple 'break'
do
    test "$have_mpi" -eq 0 && break

    F77=$mpif90
    LIBS="$mpi_libs"

# look for scalapack if required
    test "$with_scalapack" -eq 0 && break
    if test "$scalapack_libs" = "" ; then
# no additional libraries needed
       AC_SEARCH_LIBS(pdgemr2d, "" , have_scalapack=1
                   try_dflags="$try_dflags -D__SCALAPACK")
       test "$have_scalapack" -eq 1 && break

if test "$have_mkl" -eq 1
   then
      unset ac_cv_search_pdgemr2d # clear cached value
      LIBS="$mpi_libs $blas_libs"
      if test $with_scalapack -eq 1; then
         scalapack_libs=-lmkl_blacs_openmpi_lp64
      else
         scalapack_libs=-lmkl_blacs_intelmpi_lp64
      fi
      AC_SEARCH_LIBS(pdgemr2d, "mkl_scalapack_lp64" , have_scalapack=1
                     try_dflags="$try_dflags -D__SCALAPACK"
                     scalapack_libs="-lmkl_scalapack_lp64 $scalapack_libs",
                     ,
                     "$scalapack_libs" )
      test "$have_scalapack" -eq 1 && break
fi 
#
# sci libraries (e.g. cray xt)
       unset ac_cv_search_pdgemr2d # clear cached value
       scalapack_libs="-lsci"
       LIBS="$mpi_libs $scalapack_libs"
       AC_SEARCH_LIBS(pdgemr2d, "" , have_scalapack=1
                      try_dflags="$try_dflags -D__SCALAPACK")
       test "$have_scalapack" -eq 1 && break
# scalapack (including blacs), no -L options
       unset ac_cv_search_pdgemr2d # clear cached value
       scalapack_libs="-lscalapack"
       LIBS="$mpi_libs $scalapack_libs"
       LDFLAGS=""
       AC_SEARCH_LIBS(pdgemr2d, "" , have_scalapack=1
                   try_dflags="$try_dflags -D__SCALAPACK")
       test "$have_scalapack" -eq 1 && break
# scalapack + blacs, no -L options
       unset ac_cv_search_pdgemr2d # clear cached value
       blacs_libs="-lblacs -lblacsF77init -lblacs"
       scalapack_libs="-lscalapack $blacs_libs"
       LIBS="$mpi_libs $scalapack_libs"
       LDFLAGS=""
       AC_SEARCH_LIBS(pdgemr2d, "" , have_scalapack=1
                   try_dflags="$try_dflags -D__SCALAPACK")
       test "$have_scalapack" -eq 1 && break
# scalapack + blacs with -L options
       unset ac_cv_search_pdgemr2d # clear cached value
       if test "$scalapack_dir" = ""; then scalapack_dir="/bgsys/local/scalapack/lib"; fi
       if test "$blacs_dir" = ""; then blacs_dir="/bgsys/local/blacs/lib"; fi
       blacs_libs="-L$blacs_dir -lblacs -lblacsF77init -lblacs"
       scalapack_libs="-L$scalapack_dir -lscalapack $blacs_libs"
       LIBS="$mpi_libs $scalapack_libs"
       LDFLAGS=""
       AC_SEARCH_LIBS(pdgemr2d, "" , have_scalapack=1
                   try_dflags="$try_dflags -D__SCALAPACK")
    else
        # scalapack provided in SCALAPACK_LIBS - not checked!
        have_scalapack=1
        try_dflags="$try_dflags -D__SCALAPACK"
    fi
done

# Check Scalapack version with robust routines for computing the QR factorization
# with column pivoting. (Scalapack >= 2.1.0 or MKL >= 2020)
AC_ARG_WITH(scalapack_version,
   [AS_HELP_STRING([--with-scalapack-version=VAL],
       [Specify the version of Scalapack or MKL library, i.e. "2.1.0" for Scalapack or "2020" for MKL (default: 0, no version provided)])],
   [],
   [with_scalapack_version=0])

if test "$have_scalapack" -eq 1 && test "$with_scalapack_version" != "0"; then
   if test $with_scalapack -eq 1; then
      scalapack_major_version=`echo $with_scalapack_version | cut -d. -f1`
      scalapack_minor_version=`echo $with_scalapack_version | cut -d. -f2`
      if test "$scalapack_major_version" -ge 2 && test "$scalapack_major_version" -le 99; then
         if test "$scalapack_minor_version" -ge 1; then
	    try_dflags="$try_dflags -D__SCALAPACK_ROBUST_QR"
	 fi
      fi
   else
      if test "$with_scalapack_version" -ge 2020; then
         try_dflags="$try_dflags -D__SCALAPACK_ROBUST_QR"
      fi
   fi
fi

# Configuring output message
if test "$have_scalapack" -eq 1; then
   scalapack_line="SCALAPACK_LIBS=$scalapack_libs"
else
   scalapack_libs=""
   scalapack_line="@delete@"
fi

  AC_SUBST(scalapack_libs)
  AC_SUBST(scalapack_line)
  
  ]
)
