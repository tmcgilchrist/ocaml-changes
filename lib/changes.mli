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
  type t = { description : string; bullet_point : char }

  val pp : t Fmt.t
  (** Transform an individual [Change.t] to a string. *)
end

(** A Release is the accumulation of changes, with an optional release date.

  A [version] should be a {{:https://semver.org}semantic version} or an tag representing
  the unreleased changes.
 *)
module Release : sig
  type date =
    | FullDate of (string * string * string * char)
    | MonthYear of (int * string)
    | DayMonthYear of (string * string * string)
    | Custom of string

  type header = { version : string; date : date option }

  type t = ReleaseChange of header * Change.t list

  val pp : t Fmt.t
  (** Transform a [Release.t] to a string. *)
end

type t = Release.t list
(** A Changelog as a list of [Release.t]. *)

val of_string : string -> (t, string) Result.result
(** Parse changelog from a string. *)

val of_channel : in_channel -> (t, string) Result.result
(** Parse changelog file from an [in_channel]. *)

val pp : Format.formatter -> t -> unit

val to_string : t -> string
(** Render a [t] as a string. *)
