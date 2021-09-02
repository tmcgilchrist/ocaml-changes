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

  let to_string { description; list_marker } =
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
    Printf.sprintf "%c %s" list_marker description
end

module Section = struct
  type t = { title : string option; changes : Change.t list }

  let to_string = function
    | { title = None; changes } ->
        String.concat "\n" (List.map Change.to_string changes)
    | { title = Some title; changes } ->
        Printf.sprintf "%s:\n%s" title
          (String.concat "\n" (List.map Change.to_string changes))
end

module Release = struct
  type t = {
    version : string;
    date : (int * int * int) option;
    sections : Section.t list;
  }

  let default_date_sep = '-'

  let string_of_date (y, m, d) =
    Printf.sprintf "%d%c%02d%c%02d" y default_date_sep m default_date_sep d

  let to_string { version; date; sections } =
    match date with
    | None ->
        Printf.sprintf "%s:\n%s\n" version
          (String.concat "\n\n" (List.map Section.to_string sections))
    | Some date ->
        Printf.sprintf "%s (%s):\n%s\n" version (string_of_date date)
          (String.concat "\n\n" (List.map Section.to_string sections))
end

type t = Release.t list

module Parser = struct
  open MParser

  type t = {
    date_sep : char option;
    change_bullet : char option;
    cur_change_d : int;
  }

  let ( <* ) x y = x >>= ( >>$ ) y

  let ( *> ) x y = x >>= fun _ -> y

  let rec skip_upto_count k p =
    match k with
    | 0 -> return ()
    | k -> (
        attempt (skip p) >>$ true <|> return false >>= function
        | true -> skip_upto_count (k - 1) p
        | false -> return ())

  let blanks = skip_many_chars blank

  let line = many_chars (not_followed_by newline "" *> any_char)

  let printable_char_no_space =
    any_of (String.init (126 - 33 + 1) (fun x -> Char.chr (x + 33)))

  let version_char = printable_char_no_space

  let version =
    many1_chars (not_followed_by (blank <|> char ':') "" *> version_char)

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

  let date =
    decimal <* skip date_sep >>= fun year ->
    decimal <* skip date_sep >>= fun month ->
    decimal >>= fun day -> return (year, month, day)

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

  let section =
    followed_by change_start "not change start"
    >>= (fun () ->
          changes [] |>> fun changes -> { Section.title = None; changes })
    <|>
    let end_of_title = char ':' *> newline <?> "end of title" in
    many_chars (not_followed_by end_of_title "" *> any_char) >>= fun title ->
    skip end_of_title *> optional newline *> changes [] |>> fun changes ->
    { Section.title = Some title; changes }

  let markdown_header_pre = skip_many (char '#')

  let markdown_header_post = skip_many1_chars newline

  let release_date_or_release_name = between (char '(') (char ')') date

  let release_header =
    (markdown_header_pre <?> "section before release_header")
    *> blanks
    *> (version <?> "a non-empty, non-blank version string")
    <* blanks
    >>= fun version ->
    option release_date_or_release_name
    <* optional (char ':')
    <* (markdown_header_post <?> "section after release_header")
    |>> fun date -> (version, date)

  let rec sections prev_sections =
    (* Clear change_bullet state. *)
    get_user_state >>= fun state ->
    set_user_state { state with change_bullet = None } *> section
    >>= fun section ->
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

module Error = struct end

let of_ parse changelog =
  let ps = { Parser.date_sep = None; change_bullet = None; cur_change_d = 1 } in
  match parse Parser.v changelog ps with
  | MParser.Success e -> Ok e
  | MParser.Failed (msg, _error) -> Error msg

let of_string = of_ MParser.parse_string

let of_channel = of_ MParser.parse_channel

let to_string changelog =
  String.concat "\n" (List.map Release.to_string changelog)
