Changelog parsing
==========

Parse an OCaml community style changelog.
Provides a changelog data type, parser, linter, and printer.

`Changes.of_string` and `Changes.of_channel` parse an OCaml community
style changelog and produce a `(Changes.t, string)
result` which can be destructed for the structured changelog or the
parse error if one occurred. `Changes.to_string` serializes a `Changes.t`.

Examples
----------
Representive CHANGELOGs that are supported:

 1. opam-publish style as per [https://raw.githubusercontent.com/ocaml-opam/opam-publish/master/CHANGES]() (SUPPORTED)

```

2.1.0:
* Added an '--output-patch' option to allow use without a Github account
* Use the latest opam libraries (2.1.0~rc) with better format-preserving printing
* Avoid submission of packages without a reachable archive, except if `--force`
  was set or they are `conf` packages
```

 2. Markdown style without sections as per [https://github.com/mirage/ocaml-cohttp/blob/master/CHANGES.md]() (SUPPORTED)

```
## Version (date?)
- change

```

 3. Markdown style with sections as per [https://github.com/mirage/irmin/blob/master/CHANGES.md]() (WIP)

```
## Version (date?)

### Added | Changed
- **component**
- change

```

 4. LWT style as per [https://github.com/ocsigen/lwt/blob/master/CHANGES]() (WIP)

```
===== version (date?) =====

====== section ======
 * change

```


General pattern for markdown CHANGES is:

```
# Heading (Version)

either:
## Sub-heading

```

TODO
----------

Failing tests:
  [FAIL]        parse_print          0   cases/ocaml.
  [FAIL]        parse_print          2   cases/opam.
  [FAIL]        parse_print          3   cases/section_header_2.
  [FAIL]        parse_print         10   cases/dune-release.
  [FAIL]        parse_print         14   cases/ocamlformat.

0. Floating free text section
2. Has a pre-amble section before the first release header
3. Same as 2, trying to parse both as section headers with no changes
10. header with text block including [] and () that isn't version (date), minor whitespace
14. Multi-line changes > 2 lines doesn't parse correctly.

 * prefix paragraphs or generally between headers, probably should make these `Change.t` (opam/CHANGES)
 * dune handle indented lists within a change see `cases/dune/CHANGES`

 * integrate into dune-release, which needs to read the first section in the CHANGELOG,
   modify it, and include it in the PR comment for creating against ocaml/opam-repository.
   eg https://github.com/ocaml/opam-repository/pull/19377
   dune release could already be supported, they handle simple markdown and asciidoc aka version 1.

 * current design will not round-trip using the correct markdown formatting

Resources
----------

 * [ocaml-markdown omd](https://github.com/ocaml/omd)