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

 * support `#### Deprecated` headers (dune-release and ocamlformat)
 * prefix paragraphs or generally between headers, probably should make these `Change.t`
 * support date format `(4 October 2018)` for ocaml CHANGES

 * integrate into dune-release, which needs to read the first section in the CHANGELOG,
   modify it, and include it in the PR comment for creating against ocaml/opam-repository.
   eg https://github.com/ocaml/opam-repository/pull/19377
   dune release could already be supported, they handle simple markdown and asciidoc aka version 1.

 * identify the file type either by scanning ahead and heuristically identifing the type, or
   by passing the type into the parser, having both ascii and markdown side by side.
 * current design will not round-trip using the correct markdown formatting
 * opam CHANGES has an opening paragraph before the first version header see `cases/opam`
 * indented list of lists in markdown format do not round trip
 eg
```
* Thing
  * sub-list
```

Is parsed as two entries and pretty printed as:

```
* Thing
* sub-list
```

Resources
----------

 * [ocaml-markdown omd](https://github.com/ocaml/omd)