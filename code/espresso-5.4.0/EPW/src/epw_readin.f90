  !                                                                            
  ! Copyright (C) 2010-2016 Samuel Ponce', Roxana Margine, Carla Verdi, Feliciano Giustino 
  ! Copyright (C) 2007-2009 Jesse Noffsinger, Brad Malone, Feliciano Giustino  
  !                                                                            
  ! This file is distributed under the terms of the GNU General Public         
  ! License. See the file `LICENSE' in the root directory of the               
  ! present distribution, or http://www.gnu.org/copyleft.gpl.txt .             
  !                                                                            
  ! Adapted from the code PH/phq_readin - Quantum-ESPRESSO group               
  !-----------------------------------------------------------------------
  SUBROUTINE epw_readin
  !-----------------------------------------------------------------------
  !
  !    This routine reads the control variables for the program epw.
  !    from standard input (unit 5).
  !    A second routine readfile reads the variables saved on a file
  !    by the self-consistent program.
  !
#include "f_defs.h"
  !
  USE ions_base,     ONLY : nat, ntyp => nsp
  USE io_global,     ONLY : ionode_id
  USE mp,            ONLY : mp_bcast 
  USE pwcom,         ONLY : xqq
  USE wvfct,         ONLY : nbnd
  USE klist,         ONLY : nks 
  USE lsda_mod,      ONLY : lsda
  USE fixed_occ,     ONLY : tfixed_occ
  USE check_stop,    ONLY : time_max => max_seconds
  USE qpoint,        ONLY : xq
  USE disp,          ONLY : nq1, nq2, nq3
  USE output,        ONLY : fildvscf, fildrho
  USE epwcom,        ONLY : deltaeabs, emaxabs, eminabs, delta_smear, &
                            nsmear, dis_win_min, dis_win_max, wannierize, &
                            ngaussw, dvscf_dir, eptemp, wdata, spinors, &
                            num_iter, dis_froz_max, fsthick, dis_froz_min, &
                            vme, degaussw, epexst, eig_read, kmaps, &
                            epwwrite, epbread, phonselfen, elecselfen, &
                            twophoton, a2f, rand_k, rand_nq, rand_q, &
                            parallel_q, parallel_k, selfen_type, nkf1, &
                            nkf2, nkf3, nqf1, nqf2, nqf3, rand_nk, indabs, &
                            nest_fn, eps_acustic, nw, wmax, wmin, filelph, &
                            mp_mesh_q, filqf, filkf, delta_qsmear, degaussq, &
                            band_plot, ephwrite, mp_mesh_k, nstemp, broyden_beta, &
                            conv_thr_raxis, tempsmax, tempsmin, temps, broyden_ndim, &
                            wscut, wsfc, nqstep, limag, lreal, muc, gap_edge, &
                            conv_thr_iaxis, nqsmear, iprint, wepexst, epwread, & 
                            eliashberg, imag_read, kerread, kerwrite, lunif, specfun, &
                            fermi_energy, efermi_read, max_memlt, fila2f, &
                            ep_coupling, nw_specfun, wmax_specfun, &
                            wmin_specfun, laniso, lpolar, epstrict, tphases, elinterp, &
                            proj, write_wfn, phinterp, iswitch, neptemp, &
                            ntempxx, liso, lacon, lpade, etf_mem, epbwrite, &
                            tshuffle2, tshuffle, nsiter, conv_thr_racon, &
                            pwc, nswc, nswfc, nswi, filukq, filukk, fildvscf0, &
                            nbndsub, nbndskip, system_2d, delta_approx, &
                            ! THL
                            nqf1_ph, nqf2_ph, nqf3_ph, nkf1_ph, nkf2_ph, nkf3_ph, &
                            dis_num_iter, num_cg_steps, trial_step, guiding_centres, &
                            egap_rbm, edos_read, epdope, nepdope, ndopexx, smearing, epdim, mixing, &
                            bte, asr_eph, ph_read, ephl_read, dt, run, efield, gradt, &
                            nptype, save_m_mat, save_m_matw, save_m_ph, save_t_el, nkfdos1, nkfdos2, nkfdos3, &
                            vg_el, vg_ph, relax_time, fscheck, ifc_read, eimp_mode, bte_o, &
                            dielec, imp_charge, eimpbread, eimpbwrite, defectname, dvimpsr, &
                            defectdens, epcheck, nbnd_c, nbnd_v, xk_c, xk_v, epbjump, &
                            epbrestore, eimp_sr, elop, screen_polar, dvimpq, eimp_ls_mode, &
                            eph_interp, &
                            epthick, phdrag, phwmax, phkmax, shengbte_read, alloy_read, alloy_pot, frac_type

  USE elph2,         ONLY : elph
  USE start_k,       ONLY : nk1, nk2, nk3
  USE constants_epw, ONLY : ryd2mev, ryd2ev, ev2cmm1, kelvin2eV, au2fs, kB, au2ps, ryd2thz
  USE io_files,      ONLY : tmp_dir, prefix
  USE control_flags, ONLY : iverbosity, modenum, gamma_only
  USE printout_base, ONLY : title
  USE ions_base,     ONLY : amass
  USE mp_world,      ONLY : world_comm
  USE partial,       ONLY : atomo, nat_todo
  USE constants,     ONLY : AMU_RY
  USE control_lr,    ONLY : lgamma
#ifdef __PARA
  USE mp_global,     ONLY : my_pool_id, me_pool
#endif
#ifdef __NAG
  USE F90_UNIX_ENV,  ONLY : iargc, getarg
#endif

  implicit none

#ifndef __NAG
  integer :: iargc
#endif
  integer :: ios, na, it
  ! integer variable for I/O control
  ! counter on polarizations
  ! counter on iterations
  ! counter on atoms
  ! counter on types
  integer :: modenum_aux, i 
  ! auxilary variable for saving the modenum
  integer :: nk1tmp,nk2tmp,nk3tmp   ! temp vars for saving kgrid info
  character(len=256) :: outdir
  namelist / inputepw / &
       amass, outdir, prefix, iverbosity, time_max, fildvscf,                  &
       tshuffle, tshuffle2, phinterp, elinterp, epstrict,                      &
       elph, nq1, nq2, nq3, nk1, nk2, nk3, nbndskip,  nbndsub,                 &
       tphases, fildvscf0, filukk, filukq,                                     &
       epbread, epbwrite, epwread, epwwrite, etf_mem, kmaps,                   &
       eig_read, wepexst, epexst, vme,                                         &
       degaussw, fsthick, eptemp,  nsmear, delta_smear, eminabs, emaxabs,      &
       deltaeabs, dvscf_dir, ngaussw,                                          &
       wannierize, dis_win_max, dis_win_min, dis_froz_min, dis_froz_max,       &
       num_iter, proj, spinors, wdata, iprint, write_wfn, wmin, wmax, nw,      &
       eps_acustic, a2f, nest_fn, indabs, twophoton,                           & 
       selfen_type, elecselfen, phonselfen, parallel_k, parallel_q,            &
       rand_q, rand_nq, rand_k, rand_nk,                                       &
       nqf1, nqf2, nqf3, nkf1, nkf2, nkf3,                                     &
       mp_mesh_k, mp_mesh_q, filqf, filkf, filelph, ephwrite,                  & 
       band_plot, degaussq, delta_qsmear, nqsmear, nqstep,                     &
       nswfc, nswc, nswi, pwc, wsfc, wscut,                                    &
       broyden_beta, broyden_ndim, nstemp, tempsmin, tempsmax, temps,          &
       conv_thr_raxis, conv_thr_iaxis, conv_thr_racon,                         &
       gap_edge, nsiter, muc, lreal, limag, lpade, lacon, liso, laniso, lpolar,& 
       lunif, kerwrite, kerread, imag_read, eliashberg,                        & 
       ep_coupling, fila2f, max_memlt, efermi_read, fermi_energy,              &
       specfun, wmin_specfun, wmax_specfun, nw_specfun, system_2d, delta_approx, &
       ! THL-
       nqf1_ph, nqf2_ph, nqf3_ph, nkf1_ph, nkf2_ph, nkf3_ph, &
       dis_num_iter, num_cg_steps, trial_step, guiding_centres, &
       egap_rbm, edos_read, epdope, smearing, epdim, &
       bte, asr_eph, ph_read, ephl_read, dt, run, efield, gradt, &
       nptype, save_m_mat, save_m_matw, save_m_ph, save_t_el, &
       nkfdos1, nkfdos2, nkfdos3, vg_el, vg_ph, relax_time, &
       fscheck, ifc_read, mixing, eimp_mode, bte_o, dielec, imp_charge, &
       eimpbread, eimpbwrite, defectname, dvimpsr, defectdens, &
       epcheck, nbnd_c, nbnd_v, xk_c, xk_v, epbjump, epbrestore, &
       eimp_sr, elop, screen_polar, dvimpq, eimp_ls_mode, eph_interp, &
       epthick, phdrag, phwmax, phkmax, shengbte_read, alloy_read, alloy_pot, frac_type
  !
  ! amass    : atomic masses
  ! iverbosity   : verbosity control
  ! outdir   : directory where input, output, temporary files reside
  ! elph     : if true calculate electron-phonon coefficients
  ! time_max : maximum cputime for this run
  ! prefix   : the prefix of files produced by pwscf
  ! filelph  : output file for electron-phonon coefficients
  ! fildvscf : output file containing deltavsc
  ! fildrho  : output file containing deltarho
  !
  ! added by @ FG
  !
  ! tshuffle : elphel2 calculates e-ph matrix elements by using kpoints
  !            of the 1st BZ only (k+q folded back into k+q+G_0)
  ! phinterp : if true perform phonon interpolation of e-p matrix
  ! elinterp : if true perform electron interpolation of e-p matrix
  ! ngaussw  : smearing type for FS average after wann interp
  ! degaussw : corresponding width (units of eV)
  ! filqf    : file with fine q kmesh for interpolation
  ! filkf    : file with fine kmesh for interpolation
  ! filukk   : file with rotation matrix U(k) for interpolation
  ! filukq   : file with rotation matrix U(k+q) for interpolation
  ! tphases  : if true set absolute unitary gauge for eigenvectors
  ! epstrict : if true use strict selection rule for phonon linewidht calculation
  ! fsthick  : the thickness of the Fermi shell for averaging the e-ph matrix elements (units of eV)
  ! eptemp   : temperature for the electronic Fermi occupations in the e-p calculation (units of Kelvin)
  ! fildvscf0: file containing deltavscf to be used as fake perturbation to set phases
  ! nw       : nr. of bins for frequency scan in \delta( e_k - e_k+q - w ) (units of eV)
  ! wmin     : min frequency for frequency scan in \delta( e_k - e_k+q - w ) (units of eV)
  ! wmax     : max    "  "  "                                    (units of eV)                   
  ! selfen_type : choice of real/imag part of phonon selfenergy calcuation when epstrict = .true.
  ! nbndsub  : number of bands in the optimal subspace (when disentanglement is used)
  ! tshuffle2: shuffle mode for electrons + load all phonons at once
  ! elecselfen: if .TRUE. calculate imaginary part of electron selfenergy due to e-p interaction
  ! phonselfen: if .TRUE. calculate imaginary part of phonon selfenergy due to e-p interaction
  ! dvscf_dir: the dir containing all the .dvscf and .dyn files
  ! epbread  : read epmatq array from .epb files
  ! epbwrite : write epmatq array to .epb files
  ! nbndskip : number of bands to be skipped from the original Hamitonian (nfirstwin-1 in Marzari's notation)
  ! epwread  : read all quantities in Wannier representation from file epwdata.fmt
  ! epwwrite : write all quantities in Wannier representation to file epwdata.fmt
  !
  !  added by @jn
  !
  ! wannierize : if .TRUE. run the wannier90 code to maximally localize the WFs
  ! dis_win_min : lower bound on wannier90 disentanglement window
  ! dis_win_max : upper bound on wannier90 disentanglement window
  ! dis_froz_min : lower bound on frozen wannier90 disentanglement window
  ! dis_froz_max : upper bound on frozen wannier90 disentanglement window
  ! num_iter     : number of iterations used in the wannier90 minimisation
  ! proj         : initial projections (states) of the wannier functions before minimization
  ! spinors      : twice as many wannier functions are expected as initial projections 
  ! wdata        : Empty array that can be used to pass extra info to prefix.win file, for things not explicitly declared here 
  ! iprint       : verbosity of the wannier90 code
  ! write_wfn    : writes out UNK files from pwscf run for plotting of XSF files
  ! etf_mem      : if .true., the fine Bloch-space e-ph matrix elements are stored in memory
  ! kmaps        : if true, read kmap and kgmap from disk (prior run)
  ! eig_read     : if .true. then readin a set of electronic eigenvalues in eV to replace the calcualted ones
  ! wepexst      : if .TRUE. prefix.epmatwe files are already on disk. don't recalculate. debugging param
  ! epexst       : if .TRUE. prefix.epmatwp files are already on disk. don't recalculate  debugging param
  ! vme          : if .TRUE. calculate velocity matrix elements
  ! nest_fn      : if true, calculate the nesting function for a given set of q's
  ! nsmear       : number of smearing values to use for the selfen_phon call
  ! delta_smear  : change in energy for each additional nsmear ( units of eV)
  !
  ! added by @ RM
  !
  ! ephwrite : if true write el-phonon matrix elements on the fine mesh to file
  ! eps_acustic : min phonon frequency for e-p and a2f calculations (units of cm-1)
  ! band_plot : if true write files to plot band structure and phonon dispersion
  ! degaussq : smearing for sum over q in e-ph coupling (units of meV)
  ! delta_qsmear : change in energy for each additional smearing in the a2f (units of meV)
  ! nqsmear : number of smearings used to calculate a2f
  ! nqstep : number of bins for frequency used to calculate a2f
  ! nswfc    : nr. of grid points between (0,wsfc) in Eliashberg equations 
  ! nswc     : nr. of grid points between (wsfc,wscut)
  ! pwc      : power used to define nswc for non-uniform grid real-axis calculations
  ! wsfc     : intermediate freqeuncy used for integration in Eliashberg equations (at least 2-3 times wsphmax) 
  ! wscut    : upper limit for frequency integration in Eliashberg equations (at least 5 times wsphmax) (units of eV)
  ! broyden_beta : mixing factor for broyden mixing
  ! broyden_ndim : number of iterations used in mixing scheme
  ! nstemp   : number of temperature points for which the Eliashberg equations are solved
  ! tempsmin : minimum temperature for which the Eliashberg equations are solved
  ! tempsmax : maximum temperature " "
  ! conv_thr_raxis : convergence threshold for iterative solution of real-axis Eliashberg equations
  ! conv_thr_iaxis : convergence threshold for iterative solution of imag-axis Eliashberg equations 
  ! conv_thr_racon : convergence threshold for iterative solution of analytic continuation of  
  !                  Eliashberg equations from imag- to real-axis
  ! gap_edge : initial guess of the superconducting gap (in eV)
  ! nsiter   : nr of iterations for self-consitency cycle
  ! muc     : effective Coulomb potential
  ! lreal   : if .true. solve the real-axis Eliashberg eqautions
  ! limag   : if .true. solve the imag-axis Eliashberg eqautions
  ! lpade   : if .true. use pade approximants to continue imag-axis 
  !           Eliashberg equtions to real-axis
  ! lacon   : if .true. use analytic continuation to continue imag-axis 
  !           Eliashberg equtions to real-axis
  ! liso    : if .true. solve isotropic case
  ! laniso  : if .true. solve anisotropic case
  ! lunif   : if .true. a uniform grid is defined between wsfc and wscut for real-axis calculations
  ! kerwrite: if .true. write Kp and Km to files .ker for real-axis calculations
  ! kerread : if .true. read Kp and Km from files .ker for real-axis calculations
  ! imag_read : if .true. read from files Delta and Znorm on the imaginary-axis
  ! eliashberg : if .true. solve the Eliashberg equations
  ! ep_coupling : if .true. run e-p coupling calculation
  ! fila2f  : input file with eliashberg spectral function 
  ! max_memlt : maximum memory that can be allocated per pool 
  ! efermi_read : if. true. read from input file
  ! fermi_energy : fermi eneergy read from input file (units of eV)
  ! specfun  : if .TRUE. calculate electron spectral function due to e-p interaction
  ! wmin_specfun : min frequency in electron spectral function due to e-p interaction (units of eV)
  ! wmax_specfun : max frequency in electron spectral function due to e-p interaction (units of eV)
  ! nw_specfun   : nr. of bins for frequency in electron spectral function due to e-p interaction 
  !
  ! added by @ CV & SP
  ! lpolar : if .true. enable the correct Wannier interpolation in the case of polar material.  
  ! 
  CHARACTER (LEN=80)  :: input_file
  INTEGER             :: nargs, iiarg, ierr
  !
  nk1tmp = 0
  nk2tmp = 0
  nk3tmp = 0
#ifdef __PARA
  IF (me_pool /=0 .or. my_pool_id /=0) goto 400 
#endif
  !
  !
  ! ... Input from file ?
  !
  nargs = iargc() 
  !
  DO iiarg = 1, ( nargs - 1 )
     !
     CALL getarg( iiarg, input_file )  
     IF ( TRIM( input_file ) == '-input' .OR. &
          TRIM( input_file ) == '-inp'   .OR. &
          TRIM( input_file ) == '-in' ) THEN
        !
        CALL getarg( ( iiarg + 1 ) , input_file )  
        OPEN ( UNIT = 5, FILE = input_file, FORM = 'FORMATTED', &
               STATUS = 'OLD', IOSTAT = ierr )
        CALL errore( 'iosys', 'input file ' // TRIM( input_file ) // &
                   & ' not found' , ierr )
        !
     END IF
     !
  END DO
  !
  !
  !    Read the first line of the input file
  !
  READ (5, '(a)', err = 100, iostat = ios) title
100 CALL errore ('epw_readin', 'reading title ', abs (ios) )
  !
  !   set default values for variables in namelist
  !
  amass(:)     = 0.d0
  iverbosity   = 0
  elph         = .false.
  tshuffle     = .false.
  tshuffle2    = .true.
  elecselfen   = .false.
  phonselfen   = .false.
  specfun      = .false.
  epbread      = .false.
  epbwrite     = .false.
  epwread      = .false.
  epwwrite     = .false.
  phinterp     = .true.
  wannierize   = .false.
  write_wfn    = .false.
  kmaps        = .false.
  nest_fn      = .false.
  wepexst      = .false.
  epexst       = .false.
  indabs       = .false.
  twophoton    = .false.
  eig_read     = .false.
  dis_win_max  = 1d3
  dis_win_min  = -1d3
  dis_froz_max = -0.9d3
  dis_froz_min = -1d3
  num_iter     = 200
  proj(:)      = ''
  spinors      = .false.
  wdata(:)     = ''
  iprint       = 2
  wmin         = 0.d0
  wmax         = 0.3d0
  eps_acustic  = 5.d0 ! cm-1
  nw           = 10
  eptemp(:)    = 0.000d0
  eptemp(1)    = 300.0d0
  epstrict     = .false.
  selfen_type  = 2
  elinterp     = .true.
  tphases      = .false.
  parallel_k   = .true.
  parallel_q   = .false.
  a2f          = .false.
  etf_mem      = .true.
  fildvscf0    = ' '
  ngaussw      = 1
  time_max     = 10000000.d0
  outdir       = '.'
  dvscf_dir    = '.'
  prefix       = 'pwscf'
  filqf        = ' '
  filkf        = ' '
  filelph      = ' '
  fildrho      = ' '
  fildvscf     = ' '
  filukk       = ' '
  rand_q       = .false.
  delta_approx = .false.
  rand_nq      = 1
  rand_k       = .false.
  rand_nk      = 1
  nq1          = 0
  nq2          = 0
  nq3          = 0
  nk1          = 0
  nk2          = 0
  nk3          = 0
  nqf1         = 0
  nqf2         = 0
  nqf3         = 0
  nkf1         = 0
  nkf2         = 0
  nkf3         = 0
  mp_mesh_k    = .false.
  mp_mesh_q    = .false.
  nbndsub      = 0
  nbndskip     = 0
  nsmear       = 1
  delta_smear  = 0.01d0 ! eV
  modenum = 0 ! Was -1 previously and read from Modules/input_parameters.f90
              ! INTEGER :: modenum = 0. In QE 5, modenum variable does not exist
              ! anymore. Change the default EPW value to match the previous QE
              ! one. 
  vme = .false.
  eminabs = 0.d0
  emaxabs = 3.d0
  deltaeabs = 0.05d0
  ephwrite = .false.
  band_plot = .false.
  nqsmear = 10
  nqstep = 500
  delta_qsmear = 0.05d0 ! meV 
  degaussq = 0.05d0 ! meV
  lreal   = .false.
  lunif   = .true.
  limag   = .false.
  lpade   = .false.
  lacon   = .false.
  liso    = .false.
  laniso  = .false.
  lpolar  = .false.
  kerwrite= .false.
  kerread = .false.
  imag_read = .false.
  eliashberg = .false.
  ep_coupling = .true.
  nswfc    = 0
  nswc     = 0
  nswi     = 0 
  pwc      = 1.d0
  wscut    = 0.d0
  wsfc     = 0.5d0 * wscut 
  broyden_beta = 0.7d0
  broyden_ndim = 8
  conv_thr_raxis = 5.d-04
  conv_thr_iaxis = 1.d-05
  conv_thr_racon = 5.d-04
  gap_edge = 0.d0
  nstemp   = 1
  tempsmin = 0.d0
  tempsmax = 0.d0
  temps(:) = 0.d0
  nsiter   = 40
  muc     = 0.d0
  fila2f  = ' '
  max_memlt = 2.85d0
  wmin_specfun = 0.d0 ! eV
  wmax_specfun = 0.3d0 ! eV
  nw_specfun = 100
  system_2d = .false.
  ! THL
  fsthick  = 0.0d0   ! eV
  fscheck  = .TRUE.
  degaussw = 1.0d-2  ! eV
  ! wannier
  dis_num_iter    =  1000
  num_cg_steps    =  5
  trial_step      =  2.0d0
  guiding_centres = .FALSE.
  ! other
  nqf1_ph      =  0
  nqf2_ph      =  0
  nqf3_ph      =  0
  nkf1_ph      =  0
  nkf2_ph      =  0
  nkf3_ph      =  0
  epdim        =  3
  smearing     = 'tetra'
  vg_el        = 'linear'
  vg_ph        = 'linear'
  save_m_mat   = .FALSE.
  save_m_matw  = .FALSE.
  save_m_ph    = .FALSE.
  save_t_el    = .FALSE.
  edos_read    = .FALSE.
  nkfdos1      =  0
  nkfdos2      =  0
  nkfdos3      =  0
  ifc_read     = .FALSE.
  asr_eph      = .FALSE.
  ph_read      = .FALSE.
  ephl_read    = .FALSE.
  nptype       = ''
  bte          =  0
  relax_time   =  1000.0 ! 1000 fs = 1 THz, only used in cRTA
  egap_rbm     =  0.0d0
  efermi_read  = .FALSE.
  fermi_energy = -9.9d100
  epdope(:)    = -9.9d100
  run          =  0
  dt           =  0.0d0
  efield       =  1.0d-10
  gradt        =  1.0d-10
  mixing       =  1.0d0
  eimp_mode    =  0
  eimp_ls_mode =  0
  bte_o        = .FALSE.
  dielec       =  1.d0
  imp_charge   =  0.d0
  eimpbread    = .false.
  eimpbwrite   = .false.
  defectname   = ''
  dvimpsr      = .false.
  dvimpq       = .false.
  defectdens   =  0.d0
  epcheck      = .false.
  nbnd_c       =  1
  nbnd_v       =  3
  xk_c         = 'G'
  xk_v         = 'G' 
  epbjump      = .false.
  epbrestore   = .false.
  eimp_sr      = .false.
  elop         = .true.
  screen_polar = .false.
  eph_interp   = .false.
  epthick      =  0.0d0   ! eV
  phdrag       = .FALSE.
  shengbte_read= .FALSE.
  alloy_read   = .FALSE.
  alloy_pot    = .FALSE.
  frac_type    =  0.0d0
  phwmax       =  9.9d10 ! THz
  phkmax       =  10.0   ! length in the units of [2*pi/a]
  !
  !     reading the namelist inputepw
  !
#ifdef CRAYY
  !   The Cray does not accept "err" and "iostat" together with a namelist
  READ (5, inputepw)
  ios = 0
#else
  !
  READ (5, inputepw, err = 200, iostat = ios)
#endif
200 CALL errore ('epw_readin', 'reading input_epw namelist', abs (ios) )
  !
  nk1tmp = nk1
  nk2tmp = nk2
  nk3tmp = nk3
  !
  !     Check all namelist variables
  !
  IF (filukk .EQ. ' ') filukk = TRIM(outdir)//TRIM(prefix)//'.ukk'
  !
  IF (nsmear .lt. 1) CALL errore ('epw_readin', &
       & 'Wrong number of nsmears',1)
  IF (iverbosity.ne.0.and.iverbosity.ne.1.and.iverbosity.ne.2.and.iverbosity.ne.3) CALL errore ('epw_readin', &
       &' Wrong  iverbosity ', 1)
  IF (time_max.lt.1.d0) CALL errore ('epw_readin', ' Wrong time_max', 1)
  IF (tphases.and.fildvscf0.eq.' ') CALL errore ('epw_readin', &
       &' tphases requires fildvscf0', 1)
  IF (epbread.and.epbwrite) CALL errore ('epw_readin', &
       &' epbread cannot be used with epbwrite', 1)
  !IF (degaussw*4.d0.gt.fsthick) CALL errore ('epw_readin', &
  !     &' degaussw too close to fsthick', 1)
  IF ( nbndskip .lt. 0) CALL errore('epw_readin', &
       &' nbndskip must not be less than 0', 1)
  IF ((nw.lt.1).or.(nw.gt.1000)) CALL errore ('epw_readin', &
       &' unreasonable nw', 1)
  IF (parallel_k .and. parallel_q) CALL errore('epw_readin', &
       &'can only parallelize over k OR q',1)
  IF (.not.(parallel_k .or. parallel_q)) CALL errore('epw_readin', &
       &'must parallelize over k OR q',1)
  IF (parallel_k .and. elecselfen) CALL errore('epw_readin', &
       &'Electron selfenergy is more efficient with k_para',-1)
  IF (a2f .and. .not.phonselfen) CALL errore('epw_readin', &
       &'a2f requires phonoselfen',1)
  IF (parallel_q .and. phonselfen) CALL errore('epw_readin', &
       &'Phonon selfenergy is more efficient with q_para',-1)
  IF (parallel_q) CALL errore('epw_readin', &
       &'WARNING: Parallel q not tested!', -1)
  IF (elph .and. .not.ep_coupling ) CALL errore('epw_readin', &
      &'elph requires ep_coupling=.true.',1)
  IF ( (elph.and.wannierize) .and. (epwread) ) CALL errore('epw_readin', &
       & 'must use same w90 rotation matrix for entire run', 1)
  IF (wannierize .and. .not.ep_coupling ) CALL errore('epw_readin', &
      &'wannierize requires ep_coupling=.true.',1)
  IF ((wmin.gt.wmax)) &
       CALL errore ('epw_readin', ' check wmin, wmax ', 1)
  IF ((wmin_specfun.gt.wmax_specfun)) &
       CALL errore ('epw_readin', ' check wmin_specfun, wmax_specfun ', 1)
  IF ((nw_specfun.lt.2)) CALL errore ('epw_readin', &
       &' nw_specfun must be at least 2', 1)
  IF ((nqstep.lt.2)) CALL errore ('epw_readin', &
       &' nqstep must be at least 2', 1)
  IF ((nbndsub.gt.200)) CALL errore ('epw_readin', & 
       ' too many wannier functions increase size of projx', 1)
  IF (indabs .and. twophoton)  CALL errore ('epw_readin', 'twophoton and indabs not used together',1 )
  IF (( phonselfen .or. elecselfen .or. indabs .or. twophoton .or. specfun ) .and. ( mp_mesh_k .or. mp_mesh_q )) & 
     CALL errore('epw_readin', 'can only work with full uniform mesh',1)
  IF (ephwrite .and. .not.ep_coupling .and. .not.elph ) CALL errore('epw_readin', &
      &'ephwrite requires ep_coupling=.true., elph=.true.',1)
  IF (ephwrite .and. (rand_k .OR. rand_q ) ) &
     CALL errore('epw_readin', 'ephwrite requires a uniform grid',1) 
  IF (ephwrite .and. (mod(nkf1,nqf1) .ne. 0 .OR. mod(nkf2,nqf2) .ne. 0 .OR. mod(nkf3,nqf3) .ne. 0 ) ) &
     CALL errore('epw_readin', 'ephwrite requires nkf1,nkf2,nkf3 to be multiple of nqf1,nqf2,nqf3',1)
  IF (band_plot .and. filkf .eq. ' ' .and. filqf .eq. ' ') CALL errore('epw_readin', &
      &'plot band structure and phonon dispersion requires k- and q-points read from filkf and filqf files',1)
  IF ( filkf .ne. ' ' .and. .not.efermi_read ) CALL errore('epw_readin', &
      &'WARNING: if k-points are along a line, then efermi_read=.true. and fermi_energy must be given in the input file',-1)
  !
  ! THL
  dt = dt / au2fs ! fs to AU
  epthick = epthick / ryd2ev
  phwmax = phwmax / ryd2thz
  !
  IF (fsthick .EQ. 0.0d0) fsthick = 15.0d0*kB*MAXVAL(eptemp(:))*ryd2ev
  fsthick = fsthick / ryd2ev
  ! 100 cm^-1 = 0.01240 eV
  ! 10 THz    = 0.04136 eV
  ! 100 K     = 0.00862 eV
  !
  ! THL: error report for smearing
  IF (smearing .NE. 'tetra' .AND. smearing .NE. 'gauss' .AND. &
      smearing .NE. 'adapt' .AND. smearing .NE. 'lortz') CALL errore ('epw_readin','wrong smearing',1)
  !
  IF (nptype .NE. 'n' .AND. nptype .NE. 'p') nptype = 'i' ! intrinsic
  !
  IF (epdim .GT. 3) CALL errore ('epw_readin','"epdim" should be less equal to 3',1)
  !
  IF (save_t_el .EQ. .TRUE.) THEN
     !
     IF ( ( ABS(DBLE(nkf1)/DBLE(nqf1)-NINT(DBLE(nkf1)/DBLE(nqf1))) .GT. 1.0d-6 ) .OR. &
          ( ABS(DBLE(nkf2)/DBLE(nqf2)-NINT(DBLE(nkf2)/DBLE(nqf2))) .GT. 1.0d-6 ) .OR. &
          ( ABS(DBLE(nkf3)/DBLE(nqf3)-NINT(DBLE(nkf3)/DBLE(nqf3))) .GT. 1.0d-6 ) ) THEN
        CALL errore ('epw_readin','k grid should be a multiple of q grid in iterative BTE calculation when save_t_el = .TRUE.',1)
     ENDIF
     !
     IF ( (nkf1 .LT. nqf1) .OR. (nkf2 .LT. nqf2) .OR. (nkf3 .LT. nqf3) ) THEN
        CALL errore ('epw_readin','k grid should be larger than q grid when save_t_el = .TRUE.',1)
     ENDIF
     !
  ENDIF
  !
  nepdope = 0
  DO i = 1, ndopexx
     IF (epdope(i) .NE. -9.9d100) nepdope = i
     IF (nepdope .GT. ndopexx) CALL errore ('epw_readin','Maximun number of "epdope" is 50',1)
  ENDDO
  !
  IF (fermi_energy .NE. -9.9d100 .AND. nepdope .LT. 0) THEN
     CALL errore ('epw_readin','"epdope" and "fermi_energy" cannot be set simultaneously',1)
  ENDIF
  !
  !
  ! thickness and smearing width of the Fermi surface  
  ! from eV to Ryd
  degaussw = degaussw / ryd2ev 
  delta_smear = delta_smear / ryd2ev 
  !
  ! smearing of phonon in a2f
  ! from meV to Ryd 
  degaussq = degaussq / ryd2mev
  delta_qsmear = delta_qsmear / ryd2mev
  !
  ! fermi_energy read from the input file
  ! from eV to Ryd
  IF (fermi_energy .GT. -9.9d99) THEN
     efermi_read = .TRUE.
     fermi_energy = fermi_energy / ryd2ev
  ENDIF
  ! eptemp : temperature for the electronic Fermi occupations in the e-p calculation (units of Kelvin)
  DO i = 1, ntempxx
     IF (eptemp(i) .gt. 0.d0) THEN
        neptemp = i
        ! 1 K in eV = 8.6173423e-5
        ! from K to Ryd
        eptemp(i) = eptemp(i) * kelvin2eV / ryd2ev
     ENDIF
  ENDDO
  !
  ! from cm-1 to Ryd
  eps_acustic = eps_acustic / ev2cmm1 / ryd2ev 
  !
  !    reads the q point (just if ldisp = .false.)
  !
  ! wmin and wmax from eV to Ryd
  wmin = wmin / ryd2ev
  wmax = wmax / ryd2ev
  !
  ! wmin_specfun and wmax_specfun from eV to Ryd
  wmin_specfun = wmin_specfun / ryd2ev
  wmax_specfun = wmax_specfun / ryd2ev
  !
  xq(:) = 0.d0
  !
300 CALL errore ('epw_readin', 'reading xq', abs (ios) )
  lgamma = .false.
  tmp_dir = trim(outdir)
  dvscf_dir = trim(dvscf_dir)//'/'
  !
#ifdef __PARA
400 continue
  CALL bcast_ph_input
#endif
  xqq(:) = xq(:) 
  !
  !   Here we finished the reading of the input file.
  !   Now allocate space for pwscf variables, read and check them.
  !
  modenum_aux = modenum
  !
  ! SP: This initialized nspin and nspin_mag
  CALL read_file
  !
  ! nbnd comes out of readfile
  IF (nbndsub.eq.0) nbndsub = nbnd
  !
#ifdef __PARA
  IF (.not.(me_pool /=0 .or. my_pool_id /=0)) THEN
     nk1 = nk1tmp
     nk2 = nk2tmp
     nk3 = nk3tmp
  ENDIF
#else
     nk1 = nk1tmp
     nk2 = nk2tmp
     nk3 = nk3tmp
#endif

  !
  IF (gamma_only) CALL errore('epw_readin',&
     'cannot start from pw.x data file using Gamma-point tricks',1)
  !
  IF (modenum_aux .ne. -1) THEN
     modenum = modenum_aux
     iswitch = -4
  ELSE IF (modenum .eq. 0) THEN
     iswitch = -2
  ELSE
     iswitch = -4
  END IF
  !
  CALL mp_bcast ( iswitch, ionode_id, world_comm )
  CALL mp_bcast ( modenum, ionode_id, world_comm)
  !
  IF (tfixed_occ) &
     CALL errore('epw_readin','phonon with arbitrary occupations not tested',1)
  !
  IF (elph.and.lsda) CALL errore ('epw_readin', 'El-ph and spin not &
       &implemented', 1)
  !
  !   There might be other variables in the input file which describe
  !   partial computation of the dynamical matrix. Read them here
  !
  CALL allocate_part ( nat )
#ifdef __PARA
   IF (me_pool /= 0 .or. my_pool_id /=0) goto 800 
#endif
  IF (nat_todo < 0 .OR. nat_todo > nat) CALL errore ('epw_readin', &
       'nat_todo is wrong', 1)
  IF (nat_todo.NE.0) THEN
     read (5, *, err = 700, iostat = ios) (atomo (na), na = 1, nat_todo)
700  CALL errore ('epw_readin', 'reading atomo', abs (ios) )
     CALL mp_bcast(atomo, ionode_id, world_comm )
  ENDIF
#ifdef __PARA
800 continue
  CALL bcast_ph_input1
#endif


  DO it = 1, ntyp
     IF (amass (it) <= 0.d0) CALL errore ('epw_readin', 'Wrong masses', it)
  ENDDO

! No k+q anymore, can we cut?
  IF (mod (nks, 2) .ne.0) CALL errore ('epw_readin', &
      'k-points are odd', 0)
  !
#ifdef __PARA
  !
  !
  !
  ! THL: error report for iterative BTE
  IF (neptemp .GT. 1 .AND. (bte .EQ. 3 .OR. bte .EQ. 30)) &
     CALL errore ('epw_readin','multiple temperature cannot be used when bte = 3 and 30',1)
  IF (nepdope .GT. 1 .AND. (bte .EQ. 3 .OR. bte .EQ. 30)) &
     CALL errore ('epw_readin','multiple doping concentration cannot be used when bte = 3 and 30 or phdrag = TRUE',1)
  !
  !
  IF (alloy_pot) THEN
     IF (.not. (eimp_mode .EQ. 6)) CALL errore('epw_readin', 'eimp_mode should = 6 when input perturbed potential dv_tot',1)
  ENDIF
  !
  IF (alloy_read .and. alloy_pot) CALL errore('epw_readin', 'can either input alel_rate or input perturbed potential dv_tot',1)
  !
  IF (phdrag .EQ. .TRUE.) THEN
     !
     IF (.NOT. (bte .EQ. 0 .OR. bte .EQ. 1))  &
        CALL errore ('epw_readin','"bte" must be 0 or 1 when "phdrag" is TRUE',1)
     !
     IF (nkf1 .NE. nqf1 .OR. nkf2 .NE. nqf2 .OR. nkf3 .NE. nqf3) &
        CALL errore ('epw_readin','fine k and fine q grid should be identical when "phdrag" is TRUE',1)
     !
  ENDIF
  ! 
  IF (shengbte_read .EQ. .TRUE.) THEN
     !
     IF (.NOT. (phdrag .EQ. .TRUE.))  &
        CALL errore ('epw_readin','"phdrag" must be TRUE when "shengbte_read" is TRUE',1)
  ENDIF
  !
  IF (bte .EQ. 1 .OR. bte .EQ. 10 .OR. &
      bte .EQ. 3 .OR. bte .EQ. 30        ) THEN
     !
     IF ( ( ABS(DBLE(nkf1)/DBLE(nqf1)-NINT(DBLE(nkf1)/DBLE(nqf1))) .GT. 1.0d-6 ) .OR. &
          ( ABS(DBLE(nkf2)/DBLE(nqf2)-NINT(DBLE(nkf2)/DBLE(nqf2))) .GT. 1.0d-6 ) .OR. &
          ( ABS(DBLE(nkf3)/DBLE(nqf3)-NINT(DBLE(nkf3)/DBLE(nqf3))) .GT. 1.0d-6 ) ) THEN
        CALL errore ('epw_readin','k grid should be a multiple of q grid in iterative BTE calculation',1)
     ENDIF
     !
     IF ( (rand_k .EQ. .TRUE.) .OR. (rand_q .EQ. .TRUE.) ) THEN
        CALL errore ('epw_readin','cannot use a random mesh',1)
     ENDIF
     !
     IF ( (nkf1 .LT. nqf1) .OR. (nkf2 .LT. nqf2) .OR. (nkf3 .LT. nqf3) ) THEN
        CALL errore ('epw_readin','k grid should be larger than q grid',1)
     ENDIF
     !
     IF (.NOT. etf_mem)  CALL errore ('epw_readin','"etf_mem" should be TRUE in BTE calculation',1)
     !
  ELSEIF (bte .EQ. 0) THEN
     !
     IF ( (rand_k .EQ. .TRUE.) .OR. (rand_q .EQ. .TRUE.) ) &
        CALL errore ('epw_readin','q and k meshes should be uniform in BTE calculation',1)
     IF (.NOT. etf_mem)  CALL errore ('epw_readin','"etf_mem" should be TRUE in BTE calculation',1)
     !
  ELSEIF (bte .EQ. -1) THEN
     !
  ELSEIF (bte .EQ. 2 .OR. bte .EQ. 29) THEN
     !
     IF (save_m_ph .EQ. .TRUE.) CALL errore ('epw_readin','save_m_ph cannot set to be true when bte = 2 or 29',1)
     !
  ELSEIF (bte .EQ. 19 .OR. bte .EQ. 18) THEN
     !
     IF (save_t_el .EQ. .TRUE.) CALL errore ('epw_readin','save_t_el cannot set to be true when bte = 18 or 19',1)
     !
  ELSE
     !
     CALL errore ('epw_readin','wrong bte number',1)
     !
  ENDIF
  !
  IF (bte .EQ. 3 .OR. bte .EQ. 30) THEN
     !
     IF (run .EQ. 0) CALL errore ('epw_readin','the number of timestep "run" should be set when bte=3',1)
     IF (dt .EQ. 0.0d0) CALL errore ('epw_readin','the timestep "dt" should be set when bte=3',1)
     !
  ENDIF
  !
  !
  !
  !
  !  broadcast the values of nq1, nq2, nq3
  !
  CALL mp_bcast( nq1, ionode_id, world_comm )
  CALL mp_bcast( nq2, ionode_id, world_comm )
  CALL mp_bcast( nq3, ionode_id, world_comm )
  CALL mp_bcast( nk1, ionode_id, world_comm )
  CALL mp_bcast( nk2, ionode_id, world_comm )
  CALL mp_bcast( nk3, ionode_id, world_comm )
#endif
  !
  amass = AMU_RY * amass
  !
  END SUBROUTINE epw_readin
