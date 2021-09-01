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


Issues
----------

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