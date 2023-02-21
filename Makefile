FRAMEBUFFER_COMMIT=20187c24fec68a9f094c30c09d32257299cc1a11
FUSE_URL=https://ftp.halifax.rwth-aachen.de/debian/pool/main/f/fuse/fuse_2.9.9-1+deb10u1_armhf.deb
FUSE_FILENAME=fuse_2.9.9-1+deb10u1_armhf.deb
FUSE_CHECKSUM=610b19c800bd7624b19b34de8eb2030c4596a64b2ce6f9efe074d844e3fb798b
ROOTDIR=/home/crypto
prefix=/usr/local
DESTDIR=
bindir=$(prefix)/bin
sbindir=$(prefix)/sbin
libdir=$(prefix)/lib
exec_prefix=$(prefix)
libexecdir=$(exec_prefix)/libexec
LIBEXECDIR_CRYPTODAEMON=$(libexecdir)/cryptodaemon
sysconfdir=$(prefix)/etc
SYSTEMD_SYSCONFDIR=/etc/systemd
INTDIR=.build
DISTDIR=dist
DISTBINDIR=$(DISTDIR)/$(ROOTDIR)/bin
DISTLIBDIR=$(DISTDIR)/$(ROOTDIR)/lib
DISTETCDIR=$(DISTDIR)/etc
DISTLIBRM2FB_CLIENT_SO_PATH=$(ROOTDIR)/lib/librm2fb_client.so
LIBRM2FB_CLIENT_SO_PATH=librm2fb_server.so.1
SBINARIES=\
	cryptodaemon
LIBEXECBINARIES=\
	password_prompt \
	print
BINARIES_GO=\
	cryptodaemon \
	gocryptfs
SBINARIES_GO=\
	cryptodaemon
BINARIES_QT=\
	password_prompt \
	print
BINARIES_REST=\
	fusermount
BINARIES_DEPS=\
	gocryptfs \
	fusermount
LIBS_QT=\
	librm2fb_client.so \
	librm2fb_server.so
LIBS_DEPS=\
	$(LIBS_QT)

.DEFAULT: dist

.PHONY: cryptodaemon gocryptfs password_prompt print framebuffer dist dist_bin dist_tar dist_go dist_qt dist_rest install uninstall

dist: dist_bin dist_systemd dist_deps

dist_bin: $(addprefix $(DISTBINDIR)/,$(SBINARIES) $(LIBEXECBINARIES))

dist_deps: $(addprefix $(DISTBINDIR)/,$(BINARIES_DEPS)) $(addprefix $(DISTLIBDIR)/,$(LIBS_DEPS))

dist_go: $(addprefix $(DISTBINDIR)/,$(BINARIES_GO))

dist_qt: $(addprefix $(DISTBINDIR)/,$(BINARIES_QT)) $(addprefix $(DISTLIBDIR)/,$(LIBS_QT))

dist_rest: $(addprefix $(DISTBINDIR)/,$(BINARIES_REST))

dist_tar: dist
	tar cvzf remarkable-crypto-files.tar.gz -C $(DISTDIR) .

dist_systemd: $(DISTETCDIR)/systemd/system/cryptodaemon.service
	install -Dm0644 systemd/rm2fb.service $(DISTETCDIR)/systemd/system

$(INTDIR):
	mkdir -p $(INTDIR)

cryptodaemon: $(DISTBINDIR)/cryptodaemon

$(DISTBINDIR)/cryptodaemon: $(INTDIR)/cryptodaemon
	install -Dm0755 $< $@

$(INTDIR)/cryptodaemon:
	GOARCH=arm CGO_ENABLED=0 go build -o $(INTDIR)/cryptodaemon ./cryptodaemon

fusermount: $(DISTBINDIR)/fusermount

$(DISTBINDIR)/fusermount: $(INTDIR)/fusermount
	install -Dm0755 $< $@

$(INTDIR)/fusermount: $(INTDIR) Makefile $(FUSE_FILENAME)
	ar -p $(FUSE_FILENAME) data.tar.xz | tar --to-stdout -Jx ./bin/fusermount > $@
	chmod +x $@
	
$(FUSE_FILENAME):
	wget $(FUSE_URL) -O $(FUSE_FILENAME)
	echo "$(FUSE_CHECKSUM) $(FUSE_FILENAME)" | sha256sum -c || (echo "Fuse Package Checksum Mismatch" && rm $(FUSE_FILENAME) && exit 1)

gocryptfs: $(DISTBINDIR)/gocryptfs

$(DISTBINDIR)/gocryptfs: $(INTDIR)/gocryptfs
	install -Dm0755 $< $@

$(INTDIR)/gocryptfs: $(INTDIR)
	GOARCH=arm CGO_ENABLED=0 go build -tags without_openssl -o $@ "github.com/rfjakob/gocryptfs"

password_prompt: $(INTDIR)/password_prompt

$(DISTBINDIR)/password_prompt: $(INTDIR)/password_prompt
	install -Dm0755 $< $@

gui/password_prompt/Makefile: $(wildcard gui/password_prompt/*.pro)
	(cd gui/password_prompt && qmake)

$(INTDIR)/password_prompt: $(INTDIR) gui/password_prompt/Makefile
	$(MAKE) -C gui/password_prompt
	cp gui/password_prompt/password_prompt $@

print: $(DISTBINDIR)/print

$(DISTBINDIR)/print: $(INTDIR)/print
	install -Dm0755 $< $@

gui/print/Makefile: $(wildcard gui/print/*.pro)
	(cd gui/print && qmake)

$(INTDIR)/print: $(INTDIR) gui/print/Makefile
	$(MAKE) -C gui/print
	cp gui/print/print $@

remarkable2-framebuffer:
	[ -d "remarkable2-framebuffer" ] || git clone https://github.com/ddvk/remarkable2-framebuffer.git
	(cd remarkable2-framebuffer && git checkout $(FRAMEBUFFER_COMMIT))

framebuffer: $(DISTLIBDIR)/librm2fb_client.so $(DISTLIBDIR)/librm2fb_server.so

remarkable2-framebuffer/Makefile: remarkable2-framebuffer
	(cd remarkable2-framebuffer && qmake)

remarkable2-framebuffer/src/client/librm2fb_client.so.1.0.1: remarkable2-framebuffer/Makefile
	$(MAKE) -C remarkable2-framebuffer sub-src-client
	arm-linux-gnueabihf-strip $@

remarkable2-framebuffer/src/server/librm2fb_server.so.1.0.1: remarkable2-framebuffer/Makefile
	$(MAKE) -C remarkable2-framebuffer sub-src-server

$(DISTLIBDIR)/librm2fb_client.so: remarkable2-framebuffer/src/client/librm2fb_client.so.1.0.1
	install -Dm0755 remarkable2-framebuffer/src/client/librm2fb_client.so.1.0.1 $@

$(DISTLIBDIR)/librm2fb_server.so: remarkable2-framebuffer/src/server/librm2fb_server.so.1.0.1
	install -Dm0755 remarkable2-framebuffer/src/server/librm2fb_server.so.1.0.1 $@

$(DISTETCDIR)/systemd/system/cryptodaemon.service: Makefile systemd/cryptodaemon.service.in
	mkdir -p $(dir $@)
	sed \
		-e 's#@sbindir@#'$(abspath $(ROOTDIR)/bin)'#g' \
		-e 's#@LIBEXECDIR_CRYPTODAEMON@#'$(abspath $(ROOTDIR)/bin)'#g' \
		-e 's#@LIBRM2FB_CLIENT_SO_PATH@#'$(abspath $(DISTLIBRM2FB_CLIENT_SO_PATH))'#g' \
		systemd/cryptodaemon.service.in > $@

$(INTDIR)/cryptodaemon.service: Makefile systemd/cryptodaemon.service.in
	mkdir -p $(dir $@)
	sed \
		-e 's#@sbindir@#'$(abspath $(sbindir))'#g' \
		-e 's#@LIBEXECDIR_CRYPTODAEMON@#'$(abspath $(LIBEXECDIR_CRYPTODAEMON))'#g' \
		-e 's#@LIBRM2FB_CLIENT_SO_PATH@#'$(LIBRM2FB_CLIENT_SO_PATH)'#g' \
		systemd/cryptodaemon.service.in > $@

clean:
	git clean -f -X dist
	rm -rf $(INTDIR) remarkable2-framebuffer
	$(MAKE) -C gui/password_prompt clean
	$(MAKE) -C gui/print clean

install: install-go install-qt 

install-go: $(addprefix $(INTDIR)/,$(SBINARIES_GO)) $(INTDIR)/cryptodaemon.service
	mkdir -p \
		$(DESTDIR)$(sbindir) \
		$(DESTDIR)$(SYSTEMD_SYSCONFDIR)/system
	install -Dm0755 $(addprefix $(INTDIR)/,$(SBINARIES_GO)) $(DESTDIR)$(sbindir)
	install -Dm0644 $(INTDIR)/cryptodaemon.service $(DESTDIR)$(SYSTEMD_SYSCONFDIR)/system/

install-qt: $(addprefix $(INTDIR)/,$(LIBEXECBINARIES))
	mkdir -p \
		$(DESTDIR)$(LIBEXECDIR_CRYPTODAEMON)
	install -Dm0755 $(addprefix $(INTDIR)/,$(LIBEXECBINARIES)) $(DESTDIR)$(LIBEXECDIR_CRYPTODAEMON)

uninstall:
	$(RM) $(addprefix $(sbindir)/,$(BINARIES))
	$(RM) -r $(LIBEXECDIR_CRYPTODAEMON)
	$(RM) $(SYSTEMD_SYSCONFDIR)/system/cryptodaemon.service

docker-dist:
	docker build -t remarkable-crypto-toolchain .
	docker run --rm -it -u $(shell id -u):$(shell id -g) \
		-e GOPATH=/var/tmp/go \
		-e HOME=/var/tmp/home \
		-w $(CURDIR) -v $(CURDIR):$(CURDIR) \
		remarkable-crypto-toolchain $(MAKE) dist $(MAKEFLAGS)

docker-install:
	docker build -t remarkable-crypto-toolchain .
	docker run --rm -it -u $(shell id -u):$(shell id -g) \
		-e GOPATH=/var/tmp/go \
		-e HOME=/var/tmp/home \
		-w $(CURDIR) -v $(CURDIR):$(CURDIR) \
		remarkable-crypto-toolchain $(MAKE) install $(MAKEFLAGS)
