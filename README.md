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

 * add support for Sections within a Release block using markdown
   eg Irmin or LWT style.
 * property tests for roundtripping print / parse / print
 *

Resources
----------

 * [ocaml-markdown omd](https://github.com/ocaml/omd)


OPTIONS
----------

 * throw everything at Omd markdown and pattern match structure.
 * split out Ascii parser into it's own thing
 * Only parse changes and no sub-section headers

``` ocaml
(* Section headers for common libraries.

cohttp style

0.19.0 (2015-08-05):
Compatibility breaking interface changes:
* Remove `read_form` from the `Request/Response/Header` interfaces
  as this should be done in `Body` handling instead (#401).

odoc style

2.0.0~beta4
----------
Additions
- Handle @canonical tags in the top-comment of modules (@Julow, #662)
- Simplify paths referring to Stdlib (@jonludlam, #677)

ocamlformat style

### unreleased

#### Bug fixes

  + Fix normalization of sequences of expressions (#1731, @gpetiot)

ocaml style

*)

(** A Section is a collection of [Change.t]s within a Changelog.

  Common examples are:
  - {i Added} for new features.
  - {i Changed} for changes in existing functionality.
  - {i Deprecated} for soon-to-be removed features.
  - {i Removed} for now removed features.
  - {i Fixed} for any bug fixes.
  - {i Security} in case of vulnerabilities.

 *)
module Section : sig
  type format =
    | AtxHeader of int
    | SetextHeader of (char * int)
    | AsciiHeader of char option

  type header = string * format

  type t = { title : header option; changes : Change.t list }

  val pp_header : header Fmt.t

  val pp : t Fmt.t
  (** Transform a [Section.t] to a string. *)
end


```