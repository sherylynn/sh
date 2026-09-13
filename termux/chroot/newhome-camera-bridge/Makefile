CC ?= cc
PKG_CONFIG ?= pkg-config
CFLAGS ?= -O2 -g
CPPFLAGS += $(shell $(PKG_CONFIG) --cflags libpipewire-0.3)
CFLAGS += -std=c11 -Wall -Wextra -Wpedantic
LDLIBS += $(shell $(PKG_CONFIG) --libs libpipewire-0.3) -pthread

PREFIX ?= /usr/local
BINDIR ?= $(PREFIX)/bin

all: newhome-camera-pipewire

newhome-camera-pipewire: newhome_camera_pipewire.c
	$(CC) $(CPPFLAGS) $(CFLAGS) $< -o $@ $(LDFLAGS) $(LDLIBS)

install: newhome-camera-pipewire
	install -Dm755 newhome-camera-pipewire $(DESTDIR)$(BINDIR)/newhome-camera-pipewire

clean:
	rm -f newhome-camera-pipewire

.PHONY: all install clean
