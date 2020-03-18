!
MODULE beef
  !
  ! BEEF-vdW Module
  !
  USE kinds
  !
  PRIVATE
  PUBLIC :: beef_energies, beef_print, beefxc, energies
  !
  !real(DP), allocatable, save :: beefxc(:), energies(:)
  !real(DP), save              :: ldaxc
  !
  !
  real(DP), allocatable       :: beefxc(:), energies(:)
  real(DP)                    :: ldaxc

 CONTAINS
!

!
! obtain xc ensemble energies from non-selfconsistent calculations
! of the xc energies for perturbed BEEF expansion coefficents
! (provided by libbeef)
!
!-------------------------------------------------------------------------
SUBROUTINE beef_energies(iprint)
!-------------------------------------------------------------------------

  USE io_global,         ONLY  : stdout, ionode
  USE funct,             ONLY  : dft_is_meta
  USE input_parameters,  ONLY  : print_ensemble_energies
  USE control_flags,     ONLY  : io_level
  !USE exx_band,             ONLY : change_data_structure !MY ATTEMPTS
  !TO
  !FIX ERRORS

  USE ener,                 ONLY : vtxc, etxc
  USE scf,                  ONLY : rho, rho_core, rhog_core, v

  implicit none
  logical                     ::  iprint
  !real(DP), allocatable      :: beefxc(:), energies(:)
  real(DP)                    :: ldaxc
  integer                     :: i

  if (.not. allocated(beefxc)) allocate(beefxc(32))
  if (.not. allocated(energies)) allocate(energies(2000))

  !if(calc) then
     !CALL change_data_structure(.true.) MY ATTEMPT TO FIX IT
  if (.not. dft_is_meta()) then
     do i=1,30
        !calculate exchange contributions in Legendre polynomial
        !basis
        call beefsetmode(i-1)
        CALL v_xc( rho, rho_core, rhog_core, beefxc(i), vtxc, v%of_r)
     enddo
        !calculate lda correlation contribution
        call beefsetmode(-3)
        CALL v_xc( rho, rho_core, rhog_core, beefxc(31), vtxc, v%of_r)
        !calculate pbe correlation contribution
        call beefsetmode(-2)
        CALL v_xc( rho, rho_core, rhog_core, beefxc(32), vtxc, v%of_r)
        !calculate lda xc energy
        call beefsetmode(-4)
        CALL v_xc( rho, rho_core, rhog_core, ldaxc, vtxc, v%of_r )
        !restore original, unperturbed xc potential and energy
        call beefsetmode(-1)
        CALL v_xc( rho, rho_core, rhog_core, etxc, vtxc, v%of_r )
  else
     do i=1,30
        !calculate exchange contributions in Legendre polynomial
        !basis
        call beefsetmode(i-1)
        CALL v_xc_meta( rho, rho_core, rhog_core, beefxc(i), vtxc,v%of_r,v%kin_r )
     enddo
       !calculate lda correlation contribution
       call beefsetmode(-3)
       CALL v_xc_meta( rho, rho_core, rhog_core, beefxc(31), vtxc,v%of_r,v%kin_r )
       !calculate pbe correlation contribution
       call beefsetmode(-2)
       CALL v_xc_meta( rho, rho_core, rhog_core, beefxc(32), vtxc,v%of_r,v%kin_r )
       !calculate ldaxc energy
       call beefsetmode(-4)
       CALL v_xc_meta( rho, rho_core, rhog_core, ldaxc, vtxc,v%of_r,v%kin_r )
       !restore original, unperturbed xc potential and energy
       call beefsetmode(-1)
       CALL v_xc_meta( rho, rho_core, rhog_core, etxc, vtxc,v%of_r,v%kin_r )
  endif
  call beefrandinitdef
  !subtract LDA xc from exchange contributions
  do i=1,32
     beefxc(i) = beefxc(i)-ldaxc
  enddo
  beefxc(32) = beefxc(32)+beefxc(31)

  call beefensemble(beefxc, energies)
  !if (ionode .AND iprint) then
  if (.NOT. ionode) RETURN

  if (iprint .AND. ionode) then
     call beef_print( )
  endif

END SUBROUTINE beef_energies

!-------------------------------------------------------------------------
SUBROUTINE beef_print( )
!-------------------------------------------------------------------------

  USE io_global,         ONLY  : stdout, ionode
  USE control_flags,     ONLY  : io_level
  
  implicit none
  integer                     :: i

  !if (ionode .AND iprint) then
  if (.NOT. ionode) RETURN

  WRITE(*,*) "BEEFens 2000 ensemble energies"
  do i=1,2000
     WRITE(*, "(E35.15)"), energies(i)
  enddo
  WRITE(*,*)
  WRITE(*,*) "BEEF-vdW xc energy contributions"
  do i=1,32
     WRITE(*,*) i, ": ", beefxc(i)
  enddo

END SUBROUTINE beef_print

END MODULE beef
