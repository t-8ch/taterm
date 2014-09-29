VALAC=valac
VALAFLAGS=--pkg vte-2.91 --pkg gtk+-3.0 --fatal-warnings

all: taterm

% : %.vala
	$(VALAC) $(VALAFLAGS) $^

%.c : %.vala
	$(VALAC) -C $(VALAFLAGS) $^
