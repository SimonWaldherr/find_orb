# Make file for console Find_Orb,  using regular Curses
# Use 'bsdmake' for BSD
# GNU MAKE Makefile for Find_Orb
#
# Usage: make -f [path/]linmake [CLANG=Y] [W32=Y] [W64=Y] [MSWIN=Y] [X=Y] [VT=Y] [tgt]
#
#	where tgt can be any of:
# [all|find_orb|fo|fo_serve|clean|clean_temp|eph2tle|cssfield|neat_xvt]
#
#	'W32'/'W64' = cross-compile for 32- or 64-bit Windows,  using MinGW-w64,
#      on a Linux box
#	'MSWIN' = compile for Windows,  using MinGW and PDCurses,  on a Windows machine
#	'CLANG' = use clang instead of GCC;  Linux only
# 'X' = use PDCurses instead of ncurses
# 'VT' = use PDCurses with VT platform (see github.com/Bill-Gray/PDCurses/vt)
# 'CXX=g++-4.8' = use that version of g++;  helpful when testing older compilers
# None of these: compile using g++ on Linux,  for Linux
#
# 'clean_temp' removes various temporary files made by Find_Orb and friends:
# orbital elements,  covariance matrices,  etc.  'clean' removes these _and_
# the more usual object and executable files.

# As CXX is an implicit variable, a simple CXX?=g++ doesn't work.
# We have to use this trick from https://stackoverflow.com/a/42958970
ifeq ($(origin CXX),default)
	ifdef CLANG
		CXX=clang++
	else
		CXX=g++
	endif
endif
LIBSADDED=-L $(INSTALL_DIR)/lib -lm
EXE=
RM=rm -f

ifeq ($(OS),Windows_NT)
    detected_OS := Windows
else
    detected_OS := $(shell sh -c 'uname 2>/dev/null || echo Unknown')
endif

ifeq ($(detected_OS),Linux)
    CP = cp -u
else
    CP = cp
endif

# I'm using 'mkdir -p' to avoid error messages if the directory exists.
# It may fail on very old systems,  and will probably fail on non-POSIX
# systems.  If so,  change to '-mkdir' and ignore errors.

ifdef MSWIN
	LIBSADDED=-static-libgcc
	EXE=.exe
	CURSES_LIB=-lpdcurses
	MKDIR=-mkdir
else
	MKDIR=mkdir -p
endif

# You can have your include files in ~/include and libraries in
# ~/lib,  in which case only the current user can use them;  or
# (with root privileges) you can install them to /usr/local/include
# and /usr/local/lib for all to enjoy.

PREFIX?=~
ifdef GLOBAL
	INSTALL_DIR=/usr/local
else
	INSTALL_DIR=$(PREFIX)
endif
ifneq ($(PREFIX),~)
	# enable the automatic setup of ~/.find_orb dir from
	# $PREFIX/share/openorb.  This at the moment requires C++17 features
	# and works on Linux and macOS
	CXXFLAGS+=-DCONFIG_DIR_AUTOCOPY=1 -std=c++17
endif

ifdef X
	CURSES_FLAGS=-DXCURSES -I../PDCursesMod
	CURSES_LIB=-lXCurses -lXaw -lXmu -lXt -lX11 -lSM -lICE -lXext -lXpm
endif

ifdef VT
	CURSES_FLAGS=-DVT -I$(HOME)/PDCursesMod
	CURSES_LIB=-lpdcurses
endif

LIB_DIR=$(INSTALL_DIR)/lib

ifdef W64
	MINGW=x86_64-w64-mingw32-
	LIB_DIR=$(INSTALL_DIR)/win_lib
	BITS=64
endif

ifdef W32
	MINGW=i686-w64-mingw32-
	LIB_DIR=$(INSTALL_DIR)/win_lib32
	BITS=32
endif

ifdef MINGW
	CXX=$(MINGW)gcc
	WINDRES=$(MINGW)windres
	CURSES_FLAGS=-I $(INSTALL_DIR)/include -I../PDCursesMod
	EXE=.exe
	CURSES_LIB=-lpdcurses
	LIBSADDED=-L $(LIB_DIR) -lm -lgdi32 -luser32 -mwindows -static-libgcc
	FO_EXE=fo$(BITS).exe
	FIND_ORB_EXE=find_o$(BITS).exe
	RES_FILENAME=find_orb.res
endif

ifndef FO_EXE
	FO_EXE=fo
	FIND_ORB_EXE=find_orb
endif

all: $(FO_EXE) $(FIND_ORB_EXE) fo_serve.cgi eph2tle$(EXE)

CXXFLAGS+=-c -Wall -pedantic -Wextra -Werror $(ADDED_CXXFLAGS) -I $(INSTALL_DIR)/include

ifdef DEBUG
	CXXFLAGS += -g -O0
else
	CXXFLAGS += -O3
endif

OBJS=ades_out.o b32_eph.o bc405.o bias.o collide.o conv_ele.o details.o eigen.o \
	elem2tle.o elem_out.o elem_ou2.o ephem0.o errors.o expcalc.o gauss.o \
	geo_pot.o healpix.o lsquare.o miscell.o         monte0.o \
	mpc_obs.o nanosecs.o orb_func.o orb_fun2.o pl_cache.o roots.o  \
	runge.o shellsor.o sigma.o simplex.o sm_vsop.o sr.o stackall.o

miscell.o: prefix.h

LIBS=$(LIBSADDED) -llunar -ljpl -lsatell
FIND_ORB_OBJS = clipfunc.o getstrex.o

# If no Curses library has been specified,  we use ncursesw if it's
# available.  Otherwise,  we use the ncurses lib and hope it actually
# supports wide characters (Unicode).

ifeq ($(CURSES_LIB),)
	ifeq ($(shell $(CXX) -lncursesw 2>&1 > /dev/null | grep -E '(find|found)'),)
		CURSES_LIB=-lncursesw
	else
		CURSES_LIB=-lncurses
	endif
endif

#
# This magic is from https://stackoverflow.com/a/26147844
# (with mjuric's modifications to support POSIX sh).
# It ensures the code gets rebuilt if $PREFIX changes.
#
define DEPENDABLE_VAR

.PHONY: phony
$1: phony
	@if [ "$$$$(cat $1 2>&1)"x != '$($1)'x ]; then \
		/bin/echo -n '$($1)' > $1 ; \
	fi

endef

#declare PREFIX to be dependable
$(eval $(call DEPENDABLE_VAR,PREFIX))

prefix.h: PREFIX
	@echo "// AUTOGENERATED BY makefile; DONT EDIT BY HAND!!!" > prefix.h
	@echo '#define PREFIX "$(PREFIX)"' >> prefix.h
	@echo "Generated prefix.h"

$(FIND_ORB_EXE):          findorb.o $(FIND_ORB_OBJS) $(OBJS) $(RES_FILENAME)
	$(CXX) -o $(FIND_ORB_EXE) findorb.o $(FIND_ORB_OBJS) $(OBJS) $(LIBS) $(CURSES_LIB) $(RES_FILENAME) $(LDFLAGS)

findorb.o:         findorb.cpp
	$(CXX) $(CXXFLAGS) $(CURSES_FLAGS) $<

clipfunc.o:        clipfunc.cpp
	$(CXX) $(CXXFLAGS) $(CURSES_FLAGS) $<

getstrex.o:        getstrex.c
	$(CXX) $(CXXFLAGS) $(CURSES_FLAGS) $<

$(FO_EXE):          fo.o $(OBJS) $(RES_FILENAME)
	$(CXX) -o $(FO_EXE) fo.o $(OBJS) $(LIBS) $(RES_FILENAME) $(LDFLAGS)

eph2tle$(EXE):          eph2tle.o conv_ele.o elem2tle.o simplex.o lsquare.o
	$(CXX) -o eph2tle$(EXE) eph2tle.o conv_ele.o elem2tle.o simplex.o lsquare.o $(LIBS)

cssfield$(EXE):          cssfield.o
	$(CXX) -o cssfield$(EXE) cssfield.o $(LIBS)

expcalc$(EXE):          expcalc.cpp
	$(CXX) -o expcalc$(EXE) -Wall -Wextra -pedantic -DTEST_CODE expcalc.cpp

roottest$(EXE):          roottest.o
	$(CXX) -o roottest$(EXE) roottest.o roots.o

neat_xvt$(EXE):          neat_xvt.o
	$(CXX) -o neat_xvt$(EXE) neat_xvt.o

fo_serve.cgi:          fo_serve.o $(OBJS)
	$(CXX) -o fo_serve.cgi fo_serve.o $(OBJS) $(LIBS)

IDIR=$(PREFIX)/share/findorb/data
ifeq ($(PREFIX),~)
	# backwards compatibility
	IDIR=~/.find_orb
endif

clean:
	$(RM) $(OBJS) fo.o findorb.o fo_serve.o $(FIND_ORB_EXE) $(FO_EXE)
	$(RM) fo_serve.cgi eph2tle.o eph2tle$(EXE) cssfield$(EXE)
	$(RM) $(FIND_ORB_OBJS) cssfield.o neat_xvt.o neat_xvt$(EXE)
	$(RM) prefix.h PREFIX
ifdef RES_FILENAME
	$(RM) $(RES_FILENAME)

$(RES_FILENAME): find_orb.ico find_orb.rc
	$(WINDRES) find_orb.rc -O coff -o $(RES_FILENAME)
endif

clean_temp:
	$(RM) $(IDIR)/artsat.json
	$(RM) $(IDIR)/bc405pre.txt
	$(RM) $(IDIR)/cmt_sof.txt
	$(RM) $(IDIR)/combined.json
	$(RM) $(IDIR)/covar.txt
	$(RM) $(IDIR)/covar.json
	$(RM) $(IDIR)/covar?.txt
	$(RM) $(IDIR)/covar?.json
	$(RM) $(IDIR)/debug.txt
	$(RM) $(IDIR)/dummy.txt
	$(RM) $(IDIR)/elem_?.json
	$(RM) $(IDIR)/eleme?.txt
	$(RM) $(IDIR)/eleme?.json
	$(RM) $(IDIR)/elements.txt
	$(RM) $(IDIR)/elements.json
	$(RM) $(IDIR)/elem_short.json
	$(RM) $(IDIR)/ephemeri.txt
	$(RM) $(IDIR)/ephemeri.json
	$(RM) $(IDIR)/eph_json.txt
	$(RM) $(IDIR)/gauss.out
	$(RM) $(IDIR)/guide.txt
	$(RM) $(IDIR)/guide?.txt
	$(RM) $(IDIR)/linkage.json
	$(RM) $(IDIR)/lock.txt
	$(RM) $(IDIR)/monte.txt
	$(RM) $(IDIR)/monte?.txt
	$(RM) $(IDIR)/mpcorb.dat
	$(RM) $(IDIR)/mpc_f?.txt
	$(RM) $(IDIR)/mpc_fmt.txt
	$(RM) $(IDIR)/mpc_s?.txt
	$(RM) $(IDIR)/mpec.htm
	$(RM) $(IDIR)/obser?.txt
	$(RM) $(IDIR)/observe.txt
	$(RM) $(IDIR)/observe.xml
	$(RM) $(IDIR)/obs_temp.txt
	$(RM) $(IDIR)/residual.txt
	$(RM) $(IDIR)/sof.txt
	$(RM) $(IDIR)/sof?.txt
	$(RM) $(IDIR)/sofv?.txt
	$(RM) $(IDIR)/sr_el?.txt
	$(RM) $(IDIR)/sr_elems.txt
	$(RM) $(IDIR)/state.txt
	$(RM) $(IDIR)/state?.txt
	$(RM) $(IDIR)/total.json
	$(RM) $(IDIR)/total?.json
	$(RM) $(IDIR)/vectors.txt
	$(RM) $(IDIR)/virtu?.txt
	$(RM) $(IDIR)/virtual.txt

install:
	$(MKDIR) $(IDIR)
ifdef EXE
	$(CP) $(FIND_ORB_EXE) $(IDIR)
	$(CP) $(FO_EXE)       $(IDIR)
else
	$(CP) $(FIND_ORB_EXE) $(INSTALL_DIR)/bin
	$(CP) $(FO_EXE)       $(INSTALL_DIR)/bin
endif
	$(CP) command.txt details.txt dosephem.txt dos_help.txt ?findorb.txt           $(IDIR)
	$(CP) environ.def eph2tle.txt eph_expl.txt frame_he.txt                        $(IDIR)
	$(CP) geo_rect.txt header.htm jpl_eph.txt                                      $(IDIR)
	$(CP) link_def.json mpc_area.txt mpcorb.hdr mu1.txt nongravs.txt               $(IDIR)
	$(CP) observer.txt obslinks.htm ObsCodes.htm ObsCodesF.html                    $(IDIR)
	$(CP) obj_help.txt obj_name.txt odd_name.txt openfile.txt                      $(IDIR)
	$(CP) orbitdef.sof previous.def progcode.txt radecfmt.txt residfmt.txt         $(IDIR)
	$(CP) rovers.txt sat_xref.txt scope.json scopes.txt sigma.txt site_310.txt     $(IDIR)
	$(CP) timehelp.txt xdesig.txt bright.pgm bright2.pgm elem_pop.txt              $(IDIR)

uninstall:
ifdef EXE
	rm -f $(IDIR)/$(FIND_ORB_EXE)
	rm -f $(IDIR)/$(FO_EXE)
else
	rm -f $(INSTALL_DIR)/bin/$(FIND_ORB_EXE)
	rm -f $(INSTALL_DIR)/bin/$(FO_EXE)
endif
	rm -f $(IDIR)/*
	rmdir $(IDIR)

.cpp.o:
	$(CXX) $(CXXFLAGS) $<
