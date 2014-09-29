VALAC=valac
VALA_FLAGS=--pkg vte-2.90 --fatal-warnings

all: taterm

% : %.vala
	$(VALAC) $(VALAFLAGS) $^

%.c : %.vala
	$(VALAC) -C $(VALAFLAGS) $^
