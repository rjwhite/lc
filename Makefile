BIN_DIR	= ${HOME}/bin
MAN_DIR	= ${HOME}/man/man1

OWNER	= ${USER}
GROUP	= ${USER}

BIN_MODE	= 755
CONFIG_MODE	= 744
MAN_MODE	= 744

lc:
	@echo do a 'make install' to install lc

directories:
	@if [ ! -d ${BIN_DIR} ]; then \
		mkdir -p ${BIN_DIR} ; \
	fi 
	@if [ ! -d ${MAN_DIR} ]; then \
		mkdir -p ${MAN_DIR} ; \
	fi

bin: lc.plx
	install -p -m ${BIN_MODE} -o ${OWNER} -g ${GROUP} \
		lc.plx ${BIN_DIR}/lc

manpage: lc.1
	install -p -m ${MAN_MODE} -o ${OWNER} -g ${GROUP} \
		lc.1 ${MAN_DIR}/lc.1

install: directories bin manpage
