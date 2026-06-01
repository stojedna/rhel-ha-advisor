PREFIX ?= /usr
DESTDIR ?=

BINDIR = $(DESTDIR)$(PREFIX)/bin
DATADIR = $(DESTDIR)$(PREFIX)/share/rhel-ha-advisor

.PHONY: all install uninstall

all:

install:
	install -d "$(BINDIR)" "$(DATADIR)/lib"
	install -m 755 rhel-ha-advisor "$(BINDIR)/rhel-ha-advisor"
	install -m 644 lib/functions.sh "$(DATADIR)/lib/functions.sh"

uninstall:
	rm -f "$(BINDIR)/rhel-ha-advisor"
	rm -rf "$(DATADIR)"
