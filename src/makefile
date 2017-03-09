.PHONY: all clean purge

PREFIX=../bin/
SUFFIX=

TARGETS= \
	cat \
	clipboard \

all: $(addprefix $(PREFIX),$(addsuffix $(SUFFIX),$(TARGETS)))

$(PREFIX)%$(SUFFIX): %.c
	gcc -Wall -std=gnu99 -o $@ $? -lX11

clean:
	-bash -c "/bin/rm *.o"

purge: clean
	-bash -c "/bin/rm $(addprefix $(PREFIX),$(addsuffix $(SUFFIX),$(TARGETS)))"
