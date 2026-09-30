ARTICLE := rust-sim-the-book.md
CHAPTER_MANIFEST := chapters.txt
CHAPTERS := $(shell cat $(CHAPTER_MANIFEST))
PDF := rust-sim-the-book.pdf
PREAMBLE := preamble.tex
LOCAL_PREAMBLE := preamble-local.tex
STYLE := article-style.yaml
FIG_SRC := $(shell grep -l '^\\documentclass.*{standalone}' figures/*.tex 2>/dev/null)
FIG_INPUTS := $(wildcard figures/*.tex figures/*.sty)
FIG_ASSETS := $(wildcard figures/*.pdf figures/*.png figures/*.jpg figures/*.jpeg figures/*.svg figures/*.eps)
FIGURES := $(FIG_SRC:.tex=.pdf)
BUILD_DIR ?= build
BUILD_ABS := $(shell realpath -m -- "$(BUILD_DIR)")

.PHONY: pdf figures clean
pdf: $(PDF)
figures: $(FIGURES)

$(PDF): $(ARTICLE) $(CHAPTER_MANIFEST) $(CHAPTERS) $(PREAMBLE) $(LOCAL_PREAMBLE) $(STYLE) $(FIGURES) $(FIG_ASSETS) Makefile
	mkdir -p "$(BUILD_ABS)"
	printf '\\newcommand{\\pdfbuildtimestamp}{%s}\n' "$$(date -u '+%Y-%m-%d %H:%M:%S UTC')" > "$(BUILD_ABS)/pdf-build-time.tex"
	TMPDIR="$(BUILD_ABS)" pandoc "$(ARTICLE)" $(CHAPTERS) --from markdown+tex_math_dollars \
		--top-level-division=chapter --table-of-contents --toc-depth=1 \
		--metadata-file="$(STYLE)" --pdf-engine=xelatex --include-in-header="$(PREAMBLE)" \
		--include-in-header="$(LOCAL_PREAMBLE)" \
		--include-in-header="$(BUILD_ABS)/pdf-build-time.tex" -o "$@"

figures/%.pdf: figures/%.tex $(FIG_INPUTS)
	mkdir -p "$(BUILD_ABS)"
	cd figures && xelatex -interaction=nonstopmode -halt-on-error \
		-output-directory="$(BUILD_ABS)" "$*.tex" > /dev/null
	cp "$(BUILD_ABS)/$*.pdf" "$@"

clean:
	rm -rf -- "$(BUILD_ABS)"
