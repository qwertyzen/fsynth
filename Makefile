clean:
	rm -rf fsynth/*.so fsynth/_fsynth.c

install: clean
	pip install -v .
