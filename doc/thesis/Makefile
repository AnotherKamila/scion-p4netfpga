MAIN_FILE=thesis.tex

all:
	pdflatex -halt-on-error -shell-escape $(MAIN_FILE)
	pdflatex -halt-on-error -shell-escape $(MAIN_FILE)

clean:
	rm -f *.log *.aux *.toc *.pdf
