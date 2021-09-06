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

open Result

module Change = struct
  type t = { description : string; list_marker : char }

  let pp f { description; list_marker } =
    let lines = Astring.String.fields ~is_sep:(( = ) '\n') description in
    let rev_indented_lines =
      List.fold_left
        (fun lines line ->
          match lines with
          | [] -> [ line ]
          | _ :: _ -> (
              match line with
              | "" -> "" :: lines
              | line -> ("  " ^ line) :: lines))
        [] lines
    in
    let description = String.concat "\n" (List.rev rev_indented_lines) in
    Fmt.pf f "%c %s" list_marker description
end

module Section = struct
  type t = { title : (string * string option) option; changes : Change.t list }

  let pp f = function
    | { title = None; changes } ->
        Fmt.pf f "%a" Fmt.(list ~sep:(unit "\n") Change.pp) changes
    | { title = Some (title, a); changes } ->
       let sep = Option.value ~default:"" a in
       Fmt.pf f "%s%s\n%a" title sep Fmt.(list ~sep:(unit "\n") Change.pp) changes
end

module Release = struct
  type date = FullDate of (int * int * int * char) | MonthYear of (int * int)
  type header = ATXHeader | SetextHeader | AsciiHeader of string option
  type version = string * header
  type t = { version : version
           ; date : date option
           ; sections : Section.t list
           }

  let pp_version f = function
    | (str, ATXHeader) -> Fmt.pf f "#%s" str
    | (str, SetextHeader) -> Fmt.pf f "%s\n----------" str (* TODO Capture the type of underlining*)
    | (str, AsciiHeader (Some c)) -> Fmt.pf f "%s%s" str c
    | (str, AsciiHeader None) -> Fmt.pf f "%s" str

  let pp_date f = function
    | FullDate (y, m, d, date_sep) ->
        Fmt.pf f "(%d%c%02d%c%02d)" y date_sep m date_sep d
    | MonthYear (m, y) ->
        let months =
          [
            (1, "Jan");
            (2, "Feb");
            (3, "Mar");
            (4, "Apr");
            (5, "May");
            (6, "Jun");
            (7, "Jul");
            (8, "Aug");
            (9, "Sep");
            (10, "Oct");
            (11, "Nov");
            (12, "Dec");
          ]
        in
        let month = Option.value ~default:"Jan" (List.assoc_opt m months) in
        Fmt.pf f "[%s %i]" month y

(* Variants of headers:

Header
----

Header (date)
=====

## Header:
## Header (date):
## Header (date)

Header [date]
Header [date]:
Header (date)
Header (date):
*)
  let pp f { version; date; sections } =
    let date_str = Option.map (fun x -> Fmt.strf " %a" pp_date x) date
                   |> Option.value ~default:"" in
    match version with
    | (str, ATXHeader) ->
      Fmt.pf f "# %s%s:\n%a\n" str date_str
        Fmt.(list ~sep:(unit "\n\n") Section.pp)
        sections
    | (str, SetextHeader) ->
      Fmt.pf f "%s%s\n----------\n%a\n" str date_str
        Fmt.(list ~sep:(unit "\n\n") Section.pp)
        sections
    | (str, AsciiHeader (Some c)) ->
       Fmt.pf f "%s%s%s\n%a\n" str date_str c Fmt.(list ~sep:(unit "\n\n") Section.pp) sections
    | (str, AsciiHeader None) ->
        Fmt.pf f "%s%s\n%a\n" str date_str Fmt.(list ~sep:(unit "\n\n") Section.pp) sections
end

type t = Release.t list

module Parser = struct
  open MParser

  type t = {
    date_sep : char option;
    change_bullet : char option;
    cur_change_d : int;
  }

  let colon = char ':'

  let parens p = between (char '(') (char ')') p

  let squares p = between (char '[') (char ']') p

  let rec skip_upto_count k p =
    match k with
    | 0 -> return ()
    | k -> (
        attempt (skip p) >>$ true <|> return false >>= function
        | true -> skip_upto_count (k - 1) p
        | false -> return ())

  let clear_bullet_state =
    get_user_state >>= fun state ->
    set_user_state { state with change_bullet = None }

  let blanks = hidden (skip_many_chars blank)

  let line = many_chars (not_followed_by newline "" *> any_char)

  let printable_char_no_space =
    any_of (String.init (126 - 33 + 1) (fun x -> Char.chr (x + 33)))

  let version_char = printable_char_no_space

  let version =
    many1_chars (not_followed_by (blank <|> colon) "" *> version_char) <* blanks

  let decimal =
    many1_chars digit >>= fun digits ->
    let r = int_of_string_opt digits in
    match r with
    | None -> message ("couldn't create integer from " ^ digits)
    | Some r -> return r

  let date_sep =
    get_user_state >>= function
    | { date_sep = None; _ } as state ->
        char '-' <|> char '/' >>= fun sep ->
        set_user_state { state with date_sep = Some sep } >>$ sep
    | { date_sep = Some sep; _ } -> char sep

  (* Parse date of YYYY-MM-DD or YYYY/MM/DD. *)
  let date =
    decimal >>= fun year ->
    date_sep >>= fun date_sep_char ->
    decimal >>= fun month ->
    skip date_sep *> decimal >>= fun day ->
    return @@ Release.FullDate (year, month, day, date_sep_char)

  let change_bullet =
    get_user_state >>= function
    | { change_bullet = None; _ } as state ->
        char '*' <|> char '-' <|> char '+' >>= fun bullet ->
        set_user_state { state with change_bullet = Some bullet } >>$ bullet
    | { change_bullet = Some bullet; _ } -> char bullet

  let change_start =
    blanks *> skip change_bullet *> blanks *> get_pos >>= fun (_, _, col) ->
    get_user_state >>= fun state ->
    set_user_state { state with cur_change_d = col - 1 }

  let blank_line = newline *> skip_many1_chars newline

  let rec continue_change d prev_lines =
    followed_by (newline *> change_start) "next line not new change"
    <|> followed_by
          (blank_line *> not_followed_by (skip_count d.cur_change_d blank) "")
          "next line not new release"
    <|> followed_by (optional newline *> eof) "next line not eof"
    |>> (fun () ->
          let description = String.concat "\n" (List.rev prev_lines) in
          {
            Change.description;
            list_marker = Option.value ~default:'*' d.change_bullet;
          })
    (* TODO This will bite me later on. We know that we are in a change, How can we preserve that info? *)
    <|> ( newline *> skip_upto_count d.cur_change_d blank *> line
        >>= fun next_line -> continue_change d (next_line :: prev_lines) )

  let change =
    change_start *> get_user_state >>= fun d ->
    line >>= fun description -> continue_change d [ description ]

  let rec changes prev_changes =
    change >>= fun delta ->
    followed_by blank_line "not next release"
    <|> followed_by (optional newline *> eof) "not eof 2"
    |>> (fun () -> List.rev (delta :: prev_changes))
    <|> newline *> changes (delta :: prev_changes)

  (*
    SectionHeader

    SectionHeader:

*)
  let section =
    followed_by change_start "not change start"
    *> (changes [] |>> fun changes -> { Section.title = None; changes })
    <|>
    let end_of_title = (colon <* newline)  <?> "end of title" in

    many1_chars (not_followed_by end_of_title "No end of title" *> any_char) >>= fun title ->
    option end_of_title >>= fun sep ->  optional newline *> opt [] (changes []) |>> fun changes ->
    { Section.title = Some (title, Option.map (String.make 1) sep); changes }

  let month_name =
    choice [
        string "Jan" *> return 1
      ; string "Feb" *> return 2
      ; string "Mar" *> return 3
      ; string "Apr" *> return 4
      ; string "May" *> return 5
      ; string "Jun" *> return 6
      ; string "Jul" *> return 7
      ; string "Aug" *> return 8
      ; string "Sep" *> return 9
      ; string "Oct" *> return 10
      ; string "Nov" *> return 11
      ; string "Dec" *> return 12
      ]

  let month_year =
    month_name >>= fun month ->
    blanks *> decimal >>= fun year -> return @@ Release.MonthYear (month, year)

  let release_date_or_release_name =
    parens date <|> squares month_year

  let release_version =
    version <?> "a non-empty, non-blank version string" >>= fun version ->
    option release_date_or_release_name |>> fun date ->
    (version, date)

  let atx_markdown_header =
    let markdown_header_pre = skip_many1 (char '#') in
    let markdown_header_post = skip_many1_chars newline in

    between
      (markdown_header_pre  *> blanks)
      (optional (char ':') <* markdown_header_post)
      release_version

  let setext_markdown_header =
    release_version <* (skip_many1_chars newline *> skip_many1_chars (char '-' <|> char '=') *> skip_many1_chars newline)

  (* version (date?)(:?) *)
  let ascii_header =
    version >>= fun version ->
    option release_date_or_release_name >>= fun date ->
    option (string ":") >>= fun colon ->
    skip_many1_chars newline *>
    not_followed_by (string "==" <|> string "--") "ascii_header" *>
    return ((version, Release.AsciiHeader colon), date)

  let release_header =
    (atx_markdown_header >>= fun (version, date) -> return ((version, Release.ATXHeader), date))
    <|> attempt (setext_markdown_header >>= fun (version, date) -> return ((version, Release.SetextHeader), date))
    <|> ascii_header

  let rec sections prev_sections =
    (* Clear change_bullet state. *)
    clear_bullet_state *> section >>= fun section ->
    followed_by (blank_line *> release_header) "not release header"
    <|> followed_by (optional newline *> eof) "not eof 1"
    |>> (fun () -> List.rev (section :: prev_sections))
    <|> blank_line *> sections (section :: prev_sections)

  let release =
    release_header >>= fun (version, date) ->
    sections [] >>= fun sections -> return Release.{ version; date; sections }

  let rec releases prev_releases =
    release >>= fun release ->
    followed_by (optional newline *> eof) "not eof 0"
    |>> (fun () -> List.rev (release :: prev_releases))
    <|> blank_line *> releases (release :: prev_releases)

  let v = releases []
end

let of_ parse changelog =
  let ps = { Parser.date_sep = None; change_bullet = None; cur_change_d = 1 } in
  match parse Parser.v changelog ps with
  | MParser.Success e -> Ok e
  | MParser.Failed (msg, _error) -> Error msg

let of_string = of_ MParser.parse_string

let of_channel = of_ MParser.parse_channel

let to_string changelog =
  Fmt.strf "%a" Fmt.(list ~sep:(unit "\n") Release.pp) changelog
