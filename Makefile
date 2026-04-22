MAIN = main
LATEX = pdflatex
BIBTEX = bibtex

.PHONY: all paper diagrams tables benchmarks update clean

all: diagrams tables benchmarks training_plots paper

paper: $(MAIN).pdf

$(MAIN).pdf: $(MAIN).tex references.bib $(wildcard tables/*.tex)
	$(LATEX) $(MAIN)
	$(BIBTEX) $(MAIN)
	$(LATEX) $(MAIN)
	$(LATEX) $(MAIN)

diagrams:
	bash scripts/export_diagrams.sh

tables:
	julia scripts/generate_tables.jl
	python3 scripts/analyze_trained_qft.py

training_plots:
	julia scripts/plot_training_curves.jl

benchmarks:
	bash scripts/copy_benchmarks.sh

update:
	git submodule update --remote
	$(MAKE) all

clean:
	rm -f $(MAIN).aux $(MAIN).bbl $(MAIN).blg $(MAIN).log $(MAIN).out \
	      $(MAIN).toc $(MAIN).pdf $(MAIN).fdb_latexmk $(MAIN).fls $(MAIN).synctex.gz
	rm -rf figures/diagrams/ figures/benchmarks/ tables/
