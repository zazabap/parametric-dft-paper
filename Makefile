MAIN = main
LATEX = pdflatex
BIBTEX = bibtex

.PHONY: all paper diagrams tables benchmarks update clean distclean

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
	julia scripts/generate_cumulative_energy_0390.jl
	julia scripts/generate_extra_spectra_0390.jl
	/opt/conda/envs/pdft/bin/python scripts/plot_ar1_histogram.py

update:
	git submodule update --remote
	$(MAKE) all

clean:
	rm -f $(MAIN).aux $(MAIN).bbl $(MAIN).blg $(MAIN).log $(MAIN).out \
	      $(MAIN).toc $(MAIN).pdf $(MAIN).fdb_latexmk $(MAIN).fls $(MAIN).synctex.gz

distclean: clean
	rm -rf figures/diagrams/ figures/benchmarks/ tables/
