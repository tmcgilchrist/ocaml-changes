(*
 * Copyright (c) 2016 David Sheets <sheets@alum.mit.edu>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *)

(** A Changelog is a file which contains a curated, chronologically ordered list of notable changes for each version of a project.

{3 Why keep a changelog?}

To make it easier for users and contributors to see precisely what notable changes have
been made between each release (or version) of the project.

{3 Who needs a changelog?}

People do. Whether consumers or developers, the end users of software are human beings
who care about what's in the software. When the software changes, people want to know why
and how.

{3 Format}

While there is no common accepted format for changelogs, this library supports changelogs commonly
found for OCaml projects. Representive CHANGELOGs that are supported:

 - 1 opam-publish style as per {{:https://raw.githubusercontent.com/ocaml-opam/opam-publish/master/CHANGES}} (SUPPORTED)

{[
2.1.0:
* Added an '--output-patch' option to allow use without a Github account
* Use the latest opam libraries (2.1.0~rc) with better format-preserving printing
* Avoid submission of packages without a reachable archive, except if `--force`
  was set or they are `conf` packages
]}

 - 2 Markdown style without sections as per {{:https://github.com/mirage/ocaml-cohttp/blob/master/CHANGES.md}} (SUPPORTED)

{[
## Version (date?)
- change

]}

- 3 Markdown style with sections as per {{:https://github.com/mirage/irmin/blob/master/CHANGES.md}} (WIP)

{[
## Version (date?)

### Added | Changed
- **component**
- change

]}

- 4 LWT style as per {{:https://github.com/ocsigen/lwt/blob/master/CHANGES}} (WIP)

{[
===== version (date?) =====

====== section ======
 * change

]}


 *)

(** Represents a logical change to a project.

  For example, adding a new feature, fixing a bug, or writing documentation.
 *)
module Change : sig
  type t = { description : string; list_marker : char }

  val pp : t Fmt.t
  (** Transform an individual [Change.t] to a string. *)
end

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

(** A Release is the accumulation of sections and changes, with an optional release date.

  If no named section is present then an unnamed section is included.

  A [version] should be a {{:https://semver.org}semantic version} or an tag representing
  the unreleased changes.
 *)
module Release : sig
  type date =
    | FullDate of (string * string * string * char)
    | MonthYear of (int * string)
    | DayMonthYear of (string * string * string)
    | Custom of string

  type header =
    | ATXHeader of (int * string option)
    | SetextHeader of (char * int)
    | AsciiHeader of string option

  type version = string * header

  val pp_version : version Fmt.t

  val pp_date : date Fmt.t
  (** Transform a [date] to a string. *)

  type t = { version : version; date : date option; sections : Section.t list }

  val pp : t Fmt.t
  (** Transform a [Release.t] to a string. *)
end

type t = Release.t list
(** A Changelog as a list of [Release.t]. *)

val of_string : string -> (t, string) Result.result
(** Parse changelog from a string. *)

val of_channel : in_channel -> (t, string) Result.result
(** Parse changelog file from an [in_channel]. *)

val to_string : t -> string
(** Render a Changelog as a string. *)


(* Section headers

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

OCaml 4.07.1 (4 October 2018)
-----------------------------

### Bug fixes:

- MPR#7815, GPR#1896: major GC crash with first-fit policy
  (Stephen Dolan and Damien Doligez, report by Joris Giovannangeli)


*)