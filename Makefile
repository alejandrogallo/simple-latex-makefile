# vim:ft=make:
-include config.mk

.PHONY: clean
$(exit)

BIBTEX    ?= bibtex
PYTHON    ?= python
ASYMPTOTE ?= asy
GNUPLOT   ?= gnuplot
MAXIMA    ?= maxima -b
TEXENGINE ?= pdflatex
MAIN_SRC  ?= main.tex
SOURCES   ?=
PACKAGES  ?=
BUILD_DIR ?= build
VIEWER ?= xdg-open

MAIN_TARGET = $(BUILD_DIR)/$(patsubst %.tex,%.pdf,$(MAIN_SRC))
BIBITEM_FILE = $(BUILD_DIR)/$(patsubst %.tex,%.bbl,$(MAIN_SRC))

OBJECTS = $(patsubst %.tex,$(BUILD_DIR)/%.o,$(SOURCES))
OBJECTS_BIBFILES = $(patsubst %.tex,$(BUILD_DIR)/%.obib,$(SOURCES))
OBJECTS_SOURCES = $(patsubst %.tex,$(BUILD_DIR)/%.osrc,$(SOURCES))
OBJECTS_FIGURES = $(patsubst %.tex,$(BUILD_DIR)/%.ofig,$(SOURCES))
OBJECTS_TOC = $(patsubst %.tex,$(BUILD_DIR)/%.otoc,$(SOURCES))
DEP_FILE = $(BUILD_DIR)/$(patsubst %.tex,%.dependency_list,$(MAIN_SRC))
TOC_DEP = $(BUILD_DIR)/toc.d
TOC_DEP_NEW = $(BUILD_DIR)/toc.d.new

FIGS_SUFFIXES = %.pdf %.eps %.png %.jpg %.jpeg %.gif %.dvi %.bmp %.svg %.ps
SCRIPT_SUFFIXES = $(FIGS_SUFFIXES) %.tex

ifdef COLOR
COLOR_R = "\033[0;31m"
COLOR_G = "\033[0;32m"
COLOR_Y = "\033[0;33m"
COLOR_E = "\033[0m"
endif

ifneq ($(MAKECMDGOALS),clean)
ifneq ($(MAKECMDGOALS),config.mk)
-include $(DEP_FILE)
endif
endif

all: $(MAIN_TARGET)


$(MAIN_TARGET): $(TOC_DEP_NEW) $(BIBITEM_FILE) $(PACKAGES)
$(MAIN_TARGET):
	$(_creating)
	@$(tex-command)

view: $(MAIN_TARGET)
	$(VIEWER) $<

$(BIBITEM_FILE): $(shell cat /dev/null $(OBJECTS_BIBFILES))
.NOTPARALLEL:
$(BIBITEM_FILE):
	$(_creating)
	if test -z $^; then \
		touch $@; \
	else \
		{ for i in $^; do cp $$i $(BUILD_DIR)/$$i; done }; \
		( cd $(BUILD_DIR) ; $(BIBTEX) $(patsubst %.tex,%,$(MAIN_SRC)); ); \
	fi

dist: $(shell cat /dev/null \
									$(OBJECTS_SOURCES) \
									$(OBJECTS_FIGURES) \
									$(OBJECTS_BIBFILES) $(PACKAGES) )
	$(_creating)
	@mkdir -p $@
	@$(MAKE) \
		dist/$(MAIN_SRC) \
		dist/$(MAIN_TARGET) \
		$(patsubst %,dist/%,$^) \
		$(patsubst %,dist/%,$(MAKEFILE_LIST)) \

dist/%: %
	$(_creating)
	@mkdir -p $(dir $@)
	@cp $< $@

$(TOC_DEP_NEW): $(OBJECTS_TOC)
	$(_creating)
	@cat $^ > $@
	@if ! diff $(TOC_DEP) $(TOC_DEP_NEW) > /dev/null 2>&1; then $(tex-command); fi
	@cp $(TOC_DEP_NEW) $(TOC_DEP)

$(BUILD_DIR)/%.o: %.tex
	$(_creating)
	@mkdir -p $(dir $@)
	@sed -ne "$$sed_get_all_dependencies" $? > $@

%.osrc: %.o
	$(_creating)
	@echo > $@
	@awk -F'^input ' '{print $$2}' $< | sed "/^\s*$$/d" | sort -u >> $@
	@awk -F'^include  ' '{print $$2}' $< | sed "/^\s*$$/d" | sort -u >> $@

%.obib: %.o
	$(_creating)
	@echo > $@
	@awk -F'^bibliography ' '{print $$2}' $< | sed "/^\s*$$/d" | sed "s/,/ /g" |\
	 	sort -u >> $@

%.ofig: %.o
	$(_creating)
	@echo > $@
	@awk -F'^includegraphics ' '{print $$2}' $< | sed "/^\s*$$/d" | sort -u >> $@
	@awk -F'^includepdf ' '{print $$2}' $< | sed "/^\s*$$/d" | sort -u >> $@

%.otoc: %.o
	$(_creating)
	@echo > $@
	@awk -F'^part ' '{print $$2}' $< | sed "/^\s*$$/d" | sort -u >> $@
	@awk -F'^section ' '{print $$2}' $< | sed "/^\s*$$/d" | sort -u >> $@
	@awk -F'^chapter ' '{print $$2}' $< | sed "/^\s*$$/d" | sort -u >> $@
	@awk -F'^subsection ' '{print $$2}' $< | sed "/^\s*$$/d" | sort -u >> $@
	@awk -F'^subsubsection ' '{print $$2}' $< | sed "/^\s*$$/d" | sort -u >> $@

$(DEP_FILE): $(OBJECTS_SOURCES) $(OBJECTS_FIGURES) $(OBJECTS_BIBFILES)
	$(_creating)
	@echo '$(MAIN_TARGET): \\' > $@
	@cat $^ | sed "/^\s*$$/d" | sed 's_$$_ \\_' >> $@
	@echo '' >> $@

$(BUILD_DIR):
	mkdir -p $@

$(SCRIPT_SUFFIXES): %.mac
	$(_creating)
	@cd $(dir $<) && $(MAXIMA) $(notdir $<)
$(SCRIPT_SUFFIXES): %.py
	$(_creating)
	@cd $(dir $<) && $(PYTHON) $(notdir $<)
$(SCRIPT_SUFFIXES): %.sh
	$(_creating)
	@cd $(dir $<) && $(SHELL) $(notdir $<)
$(FIGS_SUFFIXES): %.asy
	$(_creating)
	@cd $(dir $<) && $(ASYMPTOTE) -f $$(echo $(suffix $@) | tr -d "\.") $(notdir $< )
$(FIGS_SUFFIXES): %.gnuplot
	$(_creating)
	@cd $(dir $<) && $(GNUPLOT) $(notdir $< )
$(FIGS_SUFFIXES): %.tex
	$(_creating)
	@cd $(dir $<) && $(TEXENGINE) $(notdir $< )

PURGE_SUFFIXES = .aux .bbl .blg .fdb_latexmk .fls .log out \
                 .ilg .toc .nav .snm .run.xml .glo .ist -blx.bib
clean:
	@rm -v $(wildcard \
		$(DEP_FILE) $(OBJECTS) $(OBJECTS_SOURCES) \
		$(OBJECTS_BIBFILES) \
		$(OBJECTS_FIGURES) $(TOC_DEP) $(TOC_DEP_NEW) $(MAIN_TARGET) \
		$(OBJECTS_TOC) $(patsubst %,$(BUILD_DIR)/*%,$(PURGE_SUFFIXES)) \
	) 2> /dev/null

.FORCE:
config.mk:
	@echo "Creating a default $@"
	$(file >$@,$(_default_config))

define _default_config
MAIN_SRC  = main.tex
BUILD_DIR = build
# TeX files
SOURCES   = $$(MAIN_SRC) $$(wildcard *.tex)
PACKAGES  = $$(wildcard *.sty)

COLOR     = 1 # use color for output
VIEW      = 1
VIEWER    = xdg-open
BIBTEX    = bibtex
PYTHON    = python3
TEXENGINE = pdflatex
endef

define sed_get_all_dependencies
# remove comments
s/%.*//

# remove empty lines
/^\s*$$/d

/\s*\\\(includegraphics\|\
\|includepdf\|\
\|input\|\
\|include\|\
\|bibliography\|\
\|part\|\
\|chapter\|\
\|section\|\
\|subsection\|\
\|subsubsection\)[*]\?\s*\b\(\[.*\]\)\?\s*/{

  # print the type of section and space
  s//\1 /

  :get_content

  /{\s*\(.*\+\)\s*}/ {
    s//\1/
    s/\n//g
    p
    d
  }

  N

  b get_content

}
endef
export sed_get_all_dependencies

define _creating
@echo $(COLOR_G)$@$(COLOR_E) from $(COLOR_Y)$<$(COLOR_E)
endef

define tex-command
$(TEXENGINE) -output-directory=$(BUILD_DIR) $(MAIN_SRC)
endef
