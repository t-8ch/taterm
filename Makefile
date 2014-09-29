PREFIX=/usr
DESTDIR=

VALAC=valac
VALAFLAGS=--pkg vte-2.91 --pkg gtk+-3.0 --fatal-warnings
INSTALL=install -D

.PHONY: all install install_taterm

all: taterm
install: install_taterm

% : %.vala
	$(VALAC) $(VALAFLAGS) $^

%.c : %.vala
	$(VALAC) -C $(VALAFLAGS) $^

install_taterm: taterm
	$(INSTALL) -m755 $^ $(DESTDIR)$(PREFIX)/bin/$^
