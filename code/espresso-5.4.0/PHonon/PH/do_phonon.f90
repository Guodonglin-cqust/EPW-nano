!
! Copyright (C) 2001-2013 Quantum ESPRESSO group
! This file is distributed under the terms of the
! GNU General Public License. See the file `License'
! in the root directory of the present distribution,
! or http://www.gnu.org/copyleft/gpl.txt .
!
!-----------------------------------------------------------------------
SUBROUTINE do_phonon(auxdyn)
  !-----------------------------------------------------------------------
  !
  ! ... This is the main driver of the phonon code.
  ! ... It assumes that the preparatory stuff has been already done.
  ! ... When the code calls this routine it has already read input
  ! ... decided which irreducible representations have to be calculated
  ! ... and it has set the variables that decide which work this routine
  ! ... will do. The parallel stuff has been already setup by the calling
  ! ... codes. This routine makes the two loops over
  ! ... the q points and the irreps and does only the calculations
  ! ... that have been decided by the driver routine.
  ! ... At a generic q, if necessary it recalculates the band structure 
  ! ... calling pwscf again.
  ! ... Then it can calculate the response to an atomic displacement,
  ! ... the dynamical matrix at that q, and the electron-phonon
  ! ... interaction at that q. At q=0 it can calculate the linear response
  ! ... to an electric field perturbation and hence the dielectric
  ! ... constant, the Born effective charges and the polarizability
  ! ... at imaginary frequencies.
  ! ... At q=0, from the second order response to an electric field,
  ! ... it can calculate also the electro-optic and the raman tensors.
  !

  USE disp,            ONLY : nqs
  USE control_ph,      ONLY : epsil, trans, qplot, only_init, &
                              only_wfc, rec_code, where_rec, &
                              xk_eph, nks_eph
  USE el_phon,         ONLY : elph, elph_mat, elph_simple
  use io_global, only : stdout
  use klist, only : nkstot, xk

  !
  ! YAMBO >
  USE YAMBO,           ONLY : elph_yambo
  ! YAMBO <
  !
  IMPLICIT NONE
  !
  CHARACTER (LEN=256), INTENT(IN) :: auxdyn
  INTEGER :: iq, ik, ipol
  LOGICAL :: do_band, do_iq, setup_pw

  !
  ! Here we save the bare list of k-point from nscf calculation,
  ! because these are the k-points we care, later run_pwscf will
  ! update this list and add a few more points we don't care
  !
  write(stdout,*) ' before do_phonon..'
  write(stdout,*) ' nkstot =', nkstot
  WRITE( stdout, '(23x,"cart. coord. in units 2pi/alat")')
  do ik = 1, nkstot
     WRITE( stdout, '(8x,"k(",i5,") = (",3f12.7,")")') ik, &
          (xk (ipol, ik) , ipol = 1, 3)
  enddo
  !
  nks_eph = nkstot
  do ik = 1, nkstot
     xk_eph(1:3,ik) = xk(1:3,ik)
  enddo

  !
  DO iq = 1, nqs
     !
     CALL prepare_q(auxdyn, do_band, do_iq, setup_pw, iq)
     !
     !  If this q is not done in this run, cycle
     !
     IF (.NOT.do_iq) CYCLE
     !
     !  If necessary the bands are recalculated
     !
     IF (setup_pw) CALL run_nscf(do_band, iq)
     !
     !  If only_wfc=.TRUE. the code computes only the wavefunctions 
     !
     IF (only_wfc) THEN
        where_rec='only_wfc'
        rec_code=-1000
        GOTO 100
     ENDIF
     !
     !  Initialize the quantities which do not depend on
     !  the linear response of the system
     !
     CALL initialize_ph()
     !
     !  electric field perturbation
     !
     IF (epsil) CALL phescf()
     !
     !  IF only_init is .true. the code computes only the 
     !  initialization parts.
     !
     IF (only_init) THEN
        where_rec='only_init'
        rec_code=-1000
        GOTO 100
     ENDIF
     !
     !  phonon perturbation
     !
     IF ( trans ) THEN
        !
        CALL phqscf()
        CALL dynmatrix_new(iq)
        !
     END IF
     !
     CALL rotate_dvscf_star(iq)
     !
     !  electron-phonon interaction
     !
     IF ( elph ) THEN
        !
        IF ( .NOT. trans ) THEN
           !
           CALL dvanqq()
           IF ( elph_mat ) THEN
              CALL ep_matrix_element_wannier()
           ELSE
              CALL elphon()
           END IF
           !
        END IF
        !
        IF ( elph_mat ) THEN
           CALL elphsum_wannier(iq)
        ELSEIF( elph_simple ) THEN
           CALL elphsum_simple()
        ELSEIF( elph_yambo ) THEN
           CALL elph_yambo_eval_and_IO()
        ELSE 
           CALL elphsum()
        END IF
        !
     END IF
     !
     ! ... cleanup of the variables for the next q point
     !
100  CALL clean_pw_ph(iq)
     !
  END DO

END SUBROUTINE do_phonon
