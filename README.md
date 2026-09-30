# SIM: The Book

**Book draft.** Chapters 1 and 2 contain the architectural essay and
kernel account, with their diagrams and references. Chapters 3–9 are headings
for planned work. The `rust-` prefix identifies the repository family.

[Book PDF](rust-sim-the-book.pdf) · [Chapter order](chapters.txt)

## Chapters

1. [SIM: Make the Kernel Explicit](chapters/01-make-the-kernel-explicit.md)
2. [The SIM Kernel](chapters/02-the-sim-kernel.md)
3. [Libraries and the Loader](chapters/03-libraries-and-the-loader.md)
4. [Expressions and Codecs](chapters/04-expressions-and-codecs.md)
5. [Evaluation and Execution](chapters/05-evaluation-and-execution.md)
6. [State, Identity, and Persistence](chapters/06-state-identity-and-persistence.md)
7. [Effects, Capabilities, and Hosts](chapters/07-effects-capabilities-and-hosts.md)
8. [Inspection and Tooling](chapters/08-inspection-and-tooling.md)
9. [Building Applications from Modules](chapters/09-building-applications-from-modules.md)

## Build

Install GNU Make, Pandoc, XeLaTeX, and the TeX Gyre fonts, then run:

```sh
make pdf
```

On Debian/Ubuntu, the relevant packages are `make`, `pandoc`, `texlive-xetex`,
`texlive-latex-extra`, `texlive-fonts-recommended`, and `fonts-texgyre`.

The output is `rust-sim-the-book.pdf`. Build intermediates go in the ignored
`build/` directory. Use `make -B pdf` to rebuild everything. `make clean`
removes intermediates and keeps the book PDF. This checkout builds on its own;
no article-tools installation or implementation sources are needed.

Book metadata is in `rust-sim-the-book.md`. The chapter manifest
`chapters.txt` specifies reading order. Each listed Markdown file starts with
one `# Chapter title {#stable-id}`; future `##` headings become sections.
Changing a listed chapter or the manifest rebuilds the book. Appearance is
configured in `article-style.yaml` and `preamble-local.tex`.

The repository is
[github.com/hobnilre/rust-sim-the-book](https://github.com/hobnilre/rust-sim-the-book).

The title date records the first version. Keep `ARTICLE_DATE` in the Makefile
and the manuscript's `date` fixed across revisions. The separate `PDF created`
timestamp continues to record each PDF rebuild in UTC.
