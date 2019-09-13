  !                                                                            
  ! Copyright (C) 2010-2016 Samuel Ponce', Roxana Margine, Carla Verdi, Feliciano Giustino 
  ! Copyright (C) 2007-2009 Jesse Noffsinger, Brad Malone, Feliciano Giustino  
  !                                                                            
  ! This file is distributed under the terms of the GNU General Public         
  ! License. See the file `LICENSE' in the root directory of the               
  ! present distribution, or http://www.gnu.org/copyleft.gpl.txt .             
  !                                                                            
  !---------------------------------------------------------------------------
  SUBROUTINE rotate_epmat(cz1, cz2, xq, iq, lwin, lwinq, exband)
  !---------------------------------------------------------------------------
  !!
  !! 1). rotate the electron-phonon matrix from the cartesian representation
  !!    of the first qpoint of the star to the eigenmode representation 
  !!    (using cz1).
  !! 
  !! 2). rotate the electron-phonon matrix from the eigenmode representation
  !!     to the cartesian representation of the qpoint iq (with cz2).
  !!
  !! SP - Sep. 2019: Cleaning. 
  !--------------------------------------------------------------------------
  USE kinds,         ONLY : DP
  USE elph2,         ONLY : epmatq, zstar, epsi, bmat
  USE epwcom,        ONLY : lpolar, nqc1, nqc2, nqc3
  USE modes,         ONLY : nmodes
  USE constants_epw, ONLY : cone, czero, one, ryd2mev, eps8
  USE pwcom,         ONLY : nbnd, nks
  USE ions_base,     ONLY : amass, ityp
  USE rigid_epw,     ONLY : rgd_blk_epw
  ! 
  IMPLICIT NONE
  !
  LOGICAL, INTENT(in) :: lwin(nbnd, nks)
  !! Bands at k within outer energy window
  LOGICAL, INTENT(in) :: lwinq(nbnd, nks)
  !! Bands at k+q within outer energy window
  LOGICAL, INTENT(in) :: exband(nbnd)
  !! Bands excluded from the calculation of overlap and projection matrices
  INTEGER, INTENT(in) :: iq
  !!  Current qpoint
  REAL(KIND = DP), INTENT(in) :: xq(3)
  !  Rotated q vector
  COMPLEX(KIND = DP), INTENT(inout) :: cz1(nmodes, nmodes)
  !! eigenvectors for the first q in the star
  COMPLEX(KIND = DP), INTENT(inout) :: cz2(nmodes, nmodes)
  !!  Rotated eigenvectors for the current q in the star
  !
  ! Local variables 
  INTEGER :: mu
  !! Counter on phonon branches
  INTEGER :: na
  !! Counter on atoms
  INTEGER :: ik
  !! Counter of k-point index
  INTEGER :: ibnd
  !! Counter on band index
  INTEGER :: jbnd
  !! Counter on band index
  INTEGER :: i
  !! Counter on band index
  INTEGER :: j
  !! Counter on band index
  INTEGER :: nexband_tmp
  !! Number of excluded bands
  REAL(KIND = DP) :: massfac
  !! square root of mass 
  COMPLEX(KIND = DP) :: eptmp(nmodes)
  !! temporary e-p matrix elements
  COMPLEX(KIND = DP) :: epmatq_opt(nbnd, nbnd, nks, nmodes)
  !! e-p matrix elements in the outer window
  COMPLEX(KIND = DP) :: epmatq_tmp(nbnd, nbnd, nks, nmodes)
  !! temporary e-p matrix 
  COMPLEX(KIND = DP) :: cz_tmp(nmodes, nmodes)
  !! temporary variables
  COMPLEX(KIND = DP) :: cz2t(nmodes, nmodes)
  !! temporary variables
  !
  ! the mass factors: 
  !  1/sqrt(M) for the  direct transform
  !  SQRT(M)   for the inverse transform 
  !
  ! if we set cz1 = cz2 here and we calculate below
  ! cz1 * cz2 we find the identity
  !
  cz2t = cz2
  !
  DO mu = 1, nmodes
    na = (mu - 1) / 3 + 1
    massfac = SQRT(amass(ityp(na)))
    cz1(mu, :) = cz1(mu, :) / massfac
    cz2(mu, :) = cz2(mu, :) * massfac
    cz2t(mu, :) = cz2t(mu, :) / massfac
  ENDDO
  !
  ! the inverse transform also requires the hermitian conjugate
  !
  cz_tmp = CONJG(TRANSPOSE(cz2))
  cz2 = cz_tmp
  !
  nexband_tmp = 0
  DO i = 1, nbnd
    IF (exband(i)) THEN
      nexband_tmp = nexband_tmp + 1
    ENDIF
  ENDDO
  ! 
  ! slim down to the first ndimwin(ikq), ndimwin(ik) states within the outer window
  !
  epmatq_opt = czero
  epmatq_tmp = czero
  IF (nexband_tmp > 0) THEN
    DO ik = 1, nks
      jbnd = 0
      DO j = 1, nbnd
        IF (exband(j)) CYCLE
        IF (lwin(j, ik)) THEN
          jbnd = jbnd + 1
          ibnd = 0
          DO i = 1, nbnd
            IF (exband(i)) CYCLE
            IF (lwinq(i, ik)) THEN
              ibnd = ibnd + 1
              epmatq_tmp(ibnd, jbnd, ik, :) = epmatq(i, j, ik, :, iq)
            ENDIF
          ENDDO
        ENDIF
      ENDDO
    ENDDO
    DO ik = 1,nks
      jbnd = 0
      DO j = 1, nbnd
        IF (exband(j)) CYCLE
          jbnd = jbnd + 1
          ibnd = 0
          DO i = 1, nbnd
            IF (exband(i)) CYCLE
              ibnd = ibnd + 1
              epmatq_opt(i, j, ik, :) = epmatq_tmp(ibnd, jbnd, ik, :)
          ENDDO
      ENDDO
    ENDDO
  ELSE
    DO ik = 1, nks
      jbnd = 0
      DO j = 1, nbnd
        IF (lwin(j, ik)) THEN
          jbnd = jbnd + 1
          ibnd = 0
          DO i = 1, nbnd
            IF (lwinq(i, ik)) THEN
              ibnd = ibnd + 1
              epmatq_opt(ibnd, jbnd, ik, :) = epmatq(i, j, ik, :, iq)
            ENDIF
          ENDDO
        ENDIF
      ENDDO
    ENDDO
  ENDIF
  ! 
  ! ep_mode(j) = cfac * sum_i ep_cart(i) * u(i,j)
  !
  epmatq(:, :, :, :, iq) = czero
  DO ik = 1, nks
    DO jbnd = 1, nbnd
      DO ibnd = 1, nbnd
        !
        ! bring e-p matrix from the cartesian representation of the
        ! first q in the star to the corresponding eigenmode representation
        !
        CALL ZGEMV('t', nmodes, nmodes, cone, cz1, nmodes,  &
                   epmatq_opt(ibnd, jbnd, ik, :), 1, czero, eptmp, 1)
        !
        IF (lpolar) THEN
          IF ((ABS(xq(1)) > eps8) .OR. (ABS(xq(2)) > eps8) .OR. (ABS(xq(3)) > eps8)) THEN
            CALL rgd_blk_epw(nqc1, nqc2, nqc3, xq, cz2t, eptmp, &
                     nmodes, epsi, zstar, bmat(ibnd, jbnd, ik, iq), -one)
          ENDIF
        ENDIF
        !
        ! rotate epmat in the cartesian representation for this q in the star
        !
        CALL ZGEMV('t', nmodes, nmodes, cone, cz2, nmodes, &
                  eptmp, 1, czero, epmatq(ibnd, jbnd, ik, :, iq), 1)
      ENDDO
    ENDDO
  ENDDO
  !
  !---------------------------------------------------------------------------
  END SUBROUTINE rotate_epmat
  !---------------------------------------------------------------------------
