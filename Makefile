VIRTUALENVDIR := resumecv/bin
resume_yaml = $(wildcard *.yaml)
 
render_all: activate | *.yaml classic markdown
	for yaml in $(resume_yaml) ; do \
		rendercv render $$yaml ; \
		mv rendercv_output/$${yaml//yaml/pdf} . ; \
	done

classic markdown: | *.yaml

*.yaml: 
	echo "You need a rendercv yaml before being able to make render_all"

activate: | $(VIRTUALENVDIR)
	. $(VIRTUALENVDIR)/activate

.PHONY: install
install: $(VIRTUALENVDIR)

$(VIRTUALENVDIR):
	pip install virtualenv
	virtualenv resumecv
	. $(VIRTUALENVDIR)/activate
	pip install -r requirements.txt