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
  type format =
    | AtxHeader of int
    | SetextHeader of (char * int)
    | AsciiHeader of char option

  type header = string * format

  type t = { title : header option; changes : Change.t list }

  let pp_header f = function
    | str, AtxHeader n -> Fmt.pf f "%s%s" (String.make n '#') str
    | str, SetextHeader (c, n) -> Fmt.pf f "%s\n%s" (String.make n c) str
    | str, AsciiHeader (Some c) -> Fmt.pf f "%s%c" str c
    | str, AsciiHeader None -> Fmt.pf f "%s" str

  let pp f = function
    | { title = None; changes } ->
        Fmt.pf f "%a" Fmt.(list ~sep:(unit "\n") Change.pp) changes
    | { title = Some header; changes } ->
        Fmt.pf f "%a\n%a" pp_header header
          Fmt.(list ~sep:(unit "\n") Change.pp)
          changes
end

module Release = struct
  type date =
    | FullDate of (string * string * string * char) (* 04/08/2018 *)
    | MonthYear of (int * string) (* Oct 2018 *)
    | DayMonthYear of (string * string * string) (* 4 October 2018 *)
    (* unreleased *)
    | Custom of string

  type header =
    | ATXHeader
    | SetextHeader of (char * int)
    | AsciiHeader of string option

  type version = string * header

  type t = { version : version; date : date option; sections : Section.t list }

  let pp_version f = function
    | str, ATXHeader -> Fmt.pf f "#%s" str
    | str, SetextHeader (c, n) -> Fmt.pf f "%s\n%s" (String.make n c) str
    | str, AsciiHeader (Some c) -> Fmt.pf f "%s%s" str c
    | str, AsciiHeader None -> Fmt.pf f "%s" str

  let pp_date f = function
    | Custom str -> Fmt.pf f "(%s)" str
    | FullDate (y, m, d, date_sep) ->
        Fmt.pf f "(%s%c%s%c%s)" y date_sep m date_sep d
    | DayMonthYear (d, m, y) -> Fmt.pf f "(%s %s %s)" d m y
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
        Fmt.pf f "[%s %s]" month y

  (* Variants of headers:

     Header
     ----

     Header (date)
     =====

     ## Header: TODO This option isn't handled yet
     ## Header (date):
     ## Header (date)

     Header [date]
     Header [date]:
     Header (date)
     Header (date):
  *)
  let pp f { version; date; sections } =
    let date_str =
      Option.map (fun x -> Fmt.strf " %a" pp_date x) date
      |> Option.value ~default:""
    in
    match version with
    | str, ATXHeader ->
        Fmt.pf f "# %s%s:\n%a\n" str date_str
          Fmt.(list ~sep:(unit "\n\n") Section.pp)
          sections
    | str, SetextHeader (c, n) ->
        Fmt.pf f "%s%s\n%s\n%a\n" str date_str (String.make n c)
          Fmt.(list ~sep:(unit "\n\n") Section.pp)
          sections
    | str, AsciiHeader (Some c) ->
        Fmt.pf f "%s%s%s\n%a\n" str date_str c
          Fmt.(list ~sep:(unit "\n\n") Section.pp)
          sections
    | str, AsciiHeader None ->
        Fmt.pf f "%s%s\n%a\n" str date_str
          Fmt.(list ~sep:(unit "\n\n") Section.pp)
          sections
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

  let version_char =
    alphanum <|> char ' ' <|> char '.' <|> char '~' <|> char '+'

  let version =
    many1_chars
      (not_followed_by (char '(' <|> char '[' <|> colon) "" *> version_char)
    |>> String.trim

  let decimal = many1_chars digit

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
    followed_by blank_line "not next release 1"
    <|> followed_by (optional newline *> eof) "not eof 2"
    |>> (fun () -> List.rev (delta :: prev_changes))
    <|> newline *> changes (delta :: prev_changes)

  let no_section_header =
    followed_by change_start "not change start"
    *> (changes [] |>> fun changes -> { Section.title = None; changes })

  let atx_markdown_section_header =
    let markdown_header_pre = skip_many1 (char '#') in
    let markdown_header_post = skip_many1_chars newline in

    between
      (markdown_header_pre *> blanks)
      (optional colon <* markdown_header_post)
      line
    >>= fun title ->
    many change |>> fun changes ->
    { Section.title = Some (title, AtxHeader 1); changes }

  (*
   Options here:
   1. Straight into bullet points for changes
   2. SectionHeader with just newline
   3. SectionHeader: with colon and newline
   4. ## SectionHeader:
  *)
  let section =
    no_section_header <|> atx_markdown_section_header
    <|>
    let end_of_title = option colon <* newline <?> "end of title1" in
    let end_of_title_2 =
      option colon <* (optional newline <|> eof) <?> "end of title2"
    in
    many1_chars (not_followed_by end_of_title "No end of title" *> any_char)
    >>= fun title ->
    end_of_title_2 >>= fun sep ->
    optional newline *> opt [] (changes []) |>> fun changes ->
    { Section.title = Some (title, AsciiHeader sep); changes }

  let month_name_short =
    choice
      [
        string "Jan" *> return 1;
        string "Feb" *> return 2;
        string "Mar" *> return 3;
        string "Apr" *> return 4;
        string "May" *> return 5;
        string "Jun" *> return 6;
        string "Jul" *> return 7;
        string "Aug" *> return 8;
        string "Sep" *> return 9;
        string "Oct" *> return 10;
        string "Nov" *> return 11;
        string "Dec" *> return 12;
      ]

  let month_name_long =
    choice
      [
        string "January";
        string "February";
        string "March";
        string "April";
        string "May";
        string "June";
        string "July";
        string "August";
        string "September";
        string "October";
        string "November";
        string "December";
      ]

  let month_year =
    month_name_short >>= fun month ->
    blanks *> decimal >>= fun year -> return @@ Release.MonthYear (month, year)

  let date_sep =
    get_user_state >>= function
    | { date_sep = None; _ } as state ->
        char '-' <|> char '/' >>= fun sep ->
        set_user_state { state with date_sep = Some sep } >>$ sep
    | { date_sep = Some sep; _ } -> char sep

  let either_date =
    (* Parse date of YYYY-MM-DD or YYYY/MM/DD. *)
    let year_month_day x () =
      date_sep >>= fun date_sep_char ->
      decimal >>= fun month ->
      skip date_sep *> decimal >>= fun day ->
      return @@ Release.FullDate (x, month, day, date_sep_char)
    in

    (* Parse date of 4 October 2018 *)
    let day_month_year x () =
      blanks *> month_name_long <* blanks >>= fun month ->
      decimal >>= fun year -> return @@ Release.DayMonthYear (x, month, year)
    in

    decimal >>= fun x -> year_month_day x () <|> day_month_year x ()

  (* Free form string for the date, usually a placeholder for a release that hasn't occured. *)
  let custom_date =
    many1 alphanum |>> fun x ->
    Release.Custom (String.of_seq @@ List.to_seq x)

  let release_date_or_release_name =
    parens (either_date <|> custom_date) <|> squares month_year

  let release_version =
    version <?> "a non-empty, non-blank version string" >>= fun version ->
    option release_date_or_release_name |>> fun date -> (version, date)

  let atx_markdown_header =
    let markdown_header_pre = skip_many1 (char '#') in
    let markdown_header_post = skip_many1_chars newline in

    between
      (markdown_header_pre *> blanks)
      (optional colon <* markdown_header_post)
      release_version

  let setext_markdown_header =
    release_version >>= fun (version, date) ->
    skip_many1_chars newline *> many1_chars (char '-' <|> char '=')
    >>= fun chars ->
    skip_many1_chars newline
    *> return (version, date, (String.get chars 0, String.length chars))

  (* version (date?)(:?) *)
  let ascii_header =
    version >>= fun version ->
    option release_date_or_release_name >>= fun date ->
    option (string ":") >>= fun colon ->
    skip_many1_chars newline
    *> not_followed_by (string "==" <|> string "--") "ascii_header"
    *> return ((version, Release.AsciiHeader colon), date)

  let release_header =
    atx_markdown_header
    >>= (fun (version, date) -> return ((version, Release.ATXHeader), date))
    <|> attempt
          ( setext_markdown_header >>= fun (version, date, header) ->
            return ((version, Release.SetextHeader header), date) )
    <|> ascii_header

  let rec sections prev_sections =
    clear_bullet_state *>
    section >>= fun section ->
    followed_by (blank_line *> release_header) "not release header"
    <|> followed_by (optional newline *> eof) "not eof"

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
