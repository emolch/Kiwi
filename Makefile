#
#                --- Makefile for Kiwi Core Tools ---
#
#          Override default settings in file 'Makefile.local'
#                   (see 'Makefile.local.example')
#

#### Basic settings ------------------------------------------------------------

SHELL = /bin/sh
MAKEDEPEND = ./fdepend.pl -g -d -i hdf5.mod -i omp_lib.mod -i kiwi_home.mod
OBJDEPEND = ./objdepend.pl
FORTRANC := gfortran
INSTALL := /usr/bin/install

#### Preset selection ----------------------------------------------------------

# Can use 'fast' or 'debug' with gfortran, g95 and ifort. You may have to create
# a custom preset when using a different compiler (see below and example in
# Makefile.local.example).

PRESET := fast


#### Installation prefixes -----------------------------------------------------

prefix = /usr/local
datarootdir = $(prefix)/share
datadir = $(datarootdir)
exec_prefix = $(prefix)
bindir = $(exec_prefix)/bin


#### Default library includes and linker settings ------------------------------

INCDUMMYOMP = -Idummy_omp_lib
LIBDUMMYOMP = dummy_omp_lib/omp_lib.o

INCMSEED = 
LIBMSEED = mseed/mseed_simple.o -lmseed

INCHDF = $(shell pkg-config hdf5 --cflags)
LIBHDF = $(shell pkg-config hdf5 --libs-only-L) -lhdf5_fortran -lhdf5 -lz

INCSAC = 
LIBSAC = -lsacio

INCFFTW = 
LIBFFTW = -lfftw3f 

LIBSMINPACK = -Lsminpack -lsminpack


#### Compiler and linker flag defaults -----------------------------------------

CFLAGS =  $(INCMSEED) $(INCHDF) $(INCSAC) $(INCFFTW) \
	      $(CFLAGS_$(FORTRANC)_$(PRESET))  #
LDFLAGS = $(LIBMSEED) $(LIBSAC)  $(LIBHDF) $(LIBSMINPACK) $(LIBFFTW) \
          $(LDFLAGS_$(FORTRANC)_$(PRESET)) #


#### Compiler specific presets  ------------------------------------------------

CFLAGS_ifort_fast   = -openmp 
LDFLAGS_ifort_fast  = -openmp

CFLAGS_ifort_debug  = -openmp -g -warn all -ftrapuv -debug all
LDFLAGS_ifort_debug = -openmp

CFLAGS_g95_fast     = $(INCDUMMYOMP) -O3
LDFLAGS_g95_fast    = $(LIBDUMMYOMP)

CFLAGS_g95_debug    = $(INCDUMMYOMP) -g -Wall -ftrace=full -fbounds-check
LDFLAGS_g95_debug   = $(LIBDUMMYOMP) -g -Wall -ftrace=full -fbounds-check 

CFLAGS_gfortran_fast   = $(INCDUMMYOMP) -O3
LDFLAGS_gfortran_fast  = $(LIBDUMMYOMP) 

CFLAGS_gfortran_debug  = $(INCDUMMYOMP) -g -Wall
LDFLAGS_gfortran_debug = $(LIBDUMMYOMP) 


#### ---------------------------------------------------------------------------

MACHINE := $(shell ./hostinfo.pl --machine)
OS := $(shell ./hostinfo.pl --os)

-include Makefile.local

# communicate compiler settings to submake (for sminpack)
export FORTRANC

SRCS := $(shell ls *.f90)

TARGETS := eulermt source_info minimizer gfdb_build gfdb_extract gfdb_redeploy \
		  gfdb_info gfdb_specialextract gfdb_build_ahfull differential_azidist \
		  eikonal_benchmark crust ahfull

TESTS_SRCS := $(shell ls test_*.f90)
TESTS = $(TESTS_SRCS:.f90=)

.PHONY : clean clean-deps tests targets all check install uninstall

# reset make's default suffix list for implicit rules, set our own
.SUFFIXES :
.SUFFIXES : .f90 .o .d .mod

all : targets 

$(TARGETS) $(TESTS) : .sminpackdone .mseedsimple .dummyomplib .dummysacio

kiwi_home.f90 :
	echo -e "module kiwi_home\n\
		character (len=*), parameter :: kiwi_home_dir = \"$(datadir)/kiwi\"\n\
	end module\n" > kiwi_home.f90

.sminpackdone :
	$(MAKE) -C sminpack/ && touch .sminpackdone

.mseedsimple :
	$(MAKE) -C mseed/ && touch .mseedsimple

.dummyomplib :
	$(MAKE) -C dummy_omp_lib/ && touch .dummyomplib

.dummysacio :
	$(MAKE) -C dummy_sacio/ && touch .dummysacio

targets : $(TARGETS)


install : targets
	$(INSTALL) -d $(bindir)
	$(INSTALL) $(TARGETS) $(bindir)
	$(INSTALL) -d $(datadir)/kiwi
	for f in `find aux -type d -and -not -path '*/.svn*'` ; do \
	    $(INSTALL) -d $(datadir)/kiwi/$$f ; done
	for f in `find aux -type f -and -not -path '*/.svn/*'` ; do \
	    $(INSTALL) $$f $(datadir)/kiwi/$$f ; done

	@echo 
	@echo '-----------------------------------------------------------------------'
	@echo '  Installation complete.'
	@echo '  Please adjust your environment variables:'
	@echo
	@echo '   * PATH should contain:'
	@echo '      ' $(bindir)
	@echo '-----------------------------------------------------------------------'

uninstall :
	rm -rf -d $(datadir)/kiwi
	cd $(bindir) ; rm -f $(TARGETS)

tests : $(TESTS)

printvars :
	@echo FORTRANC = $(FORTRANC)
	@echo CFLAGS = $(CFLAGS)
	@echo LDFLAGS = $(LDFLAGS)

check : tests
	@for t in $(TESTS); do ./$$t ; done


$(TARGETS) $(TESTS) : 
	$(FORTRANC) $(filter %.o,$^) $(OMPLIB_$(FORTRANC)) $(LDFLAGS) -o $@


# implicit rules for generating depfiles
%.d : %.f90
	@$(MAKEDEPEND) $<
	@echo determining dependencies for $<...

progobjects.do : $(SRCS:.f90=.d)
	@$(OBJDEPEND) $(TARGETS) $(TESTS) -- $(SRCS:.f90=.d) > $@
	@echo determining dependencies for executables...

# implicit rule for compiling
%.o : %.f90
	$(FORTRANC) -c $(CFLAGS) $<

kiwi_home.o kiwi_home.mod : kiwi_home.f90
	$(FORTRANC) -c $(CFLAGS) $<

minimizer.o : kiwi_home.mod

clean :
	rm -f *.o *.mod $(TESTS) $(TARGETS) .sminpackdone .mseedsimple .dummysacio .dummyomplib dummy_omp_lib/omp_lib.o dummy_omp_lib/omp_lib.mod kiwi_home.f90
	$(MAKE) -C sminpack/ clean
	$(MAKE) -C mseed/ clean
	$(MAKE) -C dummy_omp_lib/ clean
	$(MAKE) -C dummy_sacio/ clean

    
clean-deps : clean
	rm -f *.d *.do

# include auto-created dependencies

-include progobjects.do
-include $(SRCS:.f90=.d) 
