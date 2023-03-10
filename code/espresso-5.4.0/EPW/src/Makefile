# Makefile for EPW

include ../../make.sys
include make.libs

#
# use recursive definitions in Makefile to modify the PATH for modules
#

IFLAGS   = -I../../include  
MODFLAGS = -I../../iotk/src -I../../Modules -I../../LAXlib -I../../iotk/src \
	   -I../../FFTXlib -I../../PW/src -I../../LR_Modules -I../../PHonon/PH -I../../PP/src -I.

#
# The above is in alphabetical order except when order matter during compilation
#

EPWOBJS = \
io_epw.o\
elph2.o \
epw.o \
a2f.o \
allocate_epwq.o \
printout_base.o \
bcast_epw_input.o \
broyden.o \
close_epw.o \
constants_epw.o \
create_mesh.o \
createkmap.o \
dasmio.o \
deallocate_epw.o \
deallocate_eliashberg.o \
distribution.o \
dmebloch2wan.o \
dmewan2bloch.o \
dvanqq2.o \
dvqpsi_us3.o \
dvqpsi_us_only3.o \
dynbloch2wan.o \
dynwan2bloch.o \
eimpbloch2wane.o \
eimpbloch2wanp.o \
eimpmat_shuffle.o \
eimpwan2bloche.o \
eimpwan2bloch2.o \
eliashberg.o \
eliashbergcom.o \
eliashberg_aniso_cont_raxis.o \
eliashberg_aniso_iaxis.o \
eliashberg_iso_cont_raxis.o \
eliashberg_iso_iaxis.o \
eliashberg_iso_raxis.o \
eliashberg_pp.o \
eliashberg_readfiles.o \
eliashberg_setup.o \
eliashberg_write.o \
elphel2_shuffle.o \
elphon_shuffle.o \
elphon_shuffle_wrap.o \
ephbloch2wane.o \
ephbloch2wanp.o \
ephwan2bloch.o \
ephwan2blochp.o \
ephwann_shuffle.o \
epwcom.o \
epw_init.o \
bte.o \
epw_readin.o \
epw_setup.o \
epw_summary.o \
evcbloch2wan.o \
evcwan2bloch.o \
fermiwindow.o \
gen_freqgrid.o \
gmap_sym.o \
hambloch2wan.o \
hamwan2bloch.o \
io_dyn_mat2.o \
kernels_aniso_iaxis.o \
kernels_iso_iaxis.o \
kernels_raxis.o \
kfold.o \
kpointdivision.o \
ktokpmq.o \
loadkmesh.o \
loadqmesh.o \
loadumat.o \
nesting_fn.o \
openfilepw.o \
pade.o \
plot_band.o \
poolgather.o \
print_clock_epw.o \
readdvscf.o \
readgmap.o \
readigk.o \
readmat_shuffle2.o \
readwfc.o \
refold.o \
reset_sym.o \
rigid_epw.o \
rotate_eigenm.o \
rotate_epmat.o \
set_ndnmbr.o \
setphases.o \
setphases_wrap.o \
sgama2.o \
sgam_at2.o \
sort.o \
spectral_func.o \
star_q2.o \
stop_epw.o \
velwan2bloch.o \
vmebloch2wan.o \
vmewan2bloch.o \
wannier.o \
wannierize.o \
pw2wan90epw.o \
wigner_seitz2.o \
wigner_seitz.o \
write_ephmat.o \
para_thl.o \
bte_symm.o \
bte_io.o \
bte_driver.o \
bte_iteration.o \
bte_transpt.o \
bte_export.o \
bte_check.o \
epw_explore.o \
vgwan2bloch.o\
edos.o \
tetra.o \
fermilocation.o \
ephwan2bloche.o \
ephwan2bloch2.o \
wsweight.o \
selfen_elec.o \
selfen_phon.o \
interp_thl.o \
phdrag_shuffle.o \
bte_phcheck.o

#default : epw


PHOBJS = ../../PHonon/PH/libph.a
PWOBJS = ../../PW/src/libpw.a
W90LIB = ../../wannier90-2.0.1/libwannier.a
LRMODS = ../../LR_Modules/liblrmod.a
PWOBJS = ../../PW/src/libpw.a
QEMODS = ../../Modules/libqemod.a ../../FFTXlib/libqefft.a ../../LAXlib/libqela.a
LIBOBJS = ../../clib/clib.a ../../iotk/src/libiotk.a

TLDEPS= bindir mods libs pw-lib pw ph

all :   pw ph wannier wcorr pp ld1 upf libepw.a epw.x 

libepw.a : $(EPWOBJS)
	$(AR) $(ARFLAGS) $@ $?
	$(RANLIB) $@

epw.x : epw.o libepw.a $(PHOBJS) $(LRMODS) $(PWOBJS) $(W90LIB) $(QEMODS) $(LIBOBJS)
	$(LD) $(LDFLAGS) -o $@ \
	epw.o  libepw.a	$(PHOBJS) $(LRMODS) $(W90LIB) $(PWOBJS) $(QEMODS) $(LIBOBJS) $(LIBS) 
	- ( cd ../bin ; ln -fs ../src/epw.x . )

# SP: Here to correct bugs in wannier 2.0.1

wcorr : 
	sed -i "s/allocate(fermi_energy_list(nfermi),stat=ierr)/if (.not. allocated(fermi_energy_list) ) allocate(fermi_energy_list(nfermi))/g" ../../wannier90-2.0.1/src/parameters.F90 ; sed -i "s/allocate(kubo_freq_list(kubo_nfreq),stat=ierr)/if (.not. allocated(kubo_freq_list) ) allocate(kubo_freq_list(kubo_nfreq)) /g" ../../wannier90-2.0.1/src/parameters.F90 ; cp wannier_lib.f90 wannier_lib.F90 ; cp wannier_lib.F90 ../../wannier90-2.0.1/src/ 

pw : 
	cd ../../ ; make pw

ph : 
	cd ../../ ; make ph

wannier :
	cd ../../ ; make w90

pp : 
	cd ../../ ; make pp

ld1 :
	cd ../../ ; make ld1

upf :
	cd ../../ ; make upf

clean :
	- /bin/rm -f  *.o *~ *.d *.mod *.i libepw.a liblr.a epw.x ../bin/epw.x

include make.depend
