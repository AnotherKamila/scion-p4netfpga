MAIN_FILE=thesis

all: ## Compile the exported thesis (needs the .tex file exported from thesis.org)
	pdflatex -halt-on-error -shell-escape $(MAIN_FILE)
	bibtex $(MAIN_FILE)
	pdflatex -halt-on-error -shell-escape $(MAIN_FILE)
	pdflatex -halt-on-error -shell-escape $(MAIN_FILE)

clean: clean-gitignore ## Remove generated files

# Note that this does not try to cover all possible cases of .gitignore syntax!
# If using this, check that it does what you need!
clean-gitignore: ## Remove all files listed in ./.gitignore
	for pat in `cat .gitignore | grep -v '^#' | grep -v /`; do find . -name $$pat | xargs rm -rfv; done
	for pat in `cat .gitignore | grep -v '^#' | grep /`; do rm -rfv $$pat; done
