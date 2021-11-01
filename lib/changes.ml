module Change = struct
  type t = { description : string; bullet_point : char }

  let pp f { description; bullet_point } =
    Fmt.pf f "%c %s" bullet_point description
end

module Release = struct
  type date =
    | FullDate of (string * string * string * char) (* 04/08/2018 *)
    | MonthYear of (int * string) (* Oct 2018 *)
    | DayMonthYear of (string * string * string) (* 4 October 2018 *)
    | Custom of string
  (* unreleased *)

  type header = { version : string; date : date option }

  type t = ReleaseChange of header * Change.t list

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

  let pp_header f { version; date } =
    match date with
    | None -> Fmt.pf f "%s" version
    | Some x -> Fmt.pf f "%s %a" version pp_date x

  let pp f = function
    | ReleaseChange (header, changes) ->
        Fmt.pf f "# %a\n%a" pp_header header
          Fmt.(list ~sep:(any "\n") Change.pp)
          changes
end

type t = Release.t list

module Parser = struct
  open MParser

  type t = {
    date_sep : char option;
    change_bullet : char option;
    cur_change_d : int;
  }

  (** [hidden p] behaves just like parser [p] but it doesn't show any
     expected tokens in error message of [p]*)
  let hidden p s = ( <?> ) p "" s

  let ( *> ) = ( >> )

  let ( <* ) = ( << )

  (* Skip many spaces or tabs, NOT newlines. *)
  let blanks = hidden (skip_many_chars blank)

  let colon = char ':'

  let parens p = between (char '(') (char ')') p

  let squares p = between (char '[') (char ']') p

  let decimal = many1_chars digit

  let version_char =
    alphanum <|> char ' ' <|> char '.' <|> char '~' <|> char '+' <|> char ','
    <|> char '"' <|> char '#' <?> "Version character"

  let line = many_chars (not_followed_by newline "" *> any_char)

  let blank_line = newline *> skip_many1 newline

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

  let version =
    many1_chars
      (not_followed_by (char '(' <|> char '[' <|> colon) "" *> version_char)
    |>> String.trim

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
    blanks *> decimal >>= fun year ->
    blanks >>= fun () -> return @@ Release.MonthYear (month, year)

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
    many1 alphanum |>> fun x -> Release.Custom (String.of_seq @@ List.to_seq x)

  let release_date = parens (either_date <|> custom_date) <|> squares month_year

  let release_version =
    version <?> "a non-empty, non-blank version string" >>= fun version ->
    option release_date |>> fun date -> (version, date)

  let atx_release_header =
    many1_chars (char '#') *> blanks *> release_version
    >>= fun (version, date) ->
    option colon *> skip_many newline *> return { Release.version; date }

  let setext_release_header =
    release_version >>= fun (version, date) ->
    newline
    *> many1_chars (char '-' <|> char '=')
    *> skip_many1 newline
    *> return { Release.version; date }

  let ascii_header =
    release_version >>= fun (version, date) ->
    (* NOTE without mandatory colon we can't terminate continue_change using release_header!
       If we tracked the indentation level
    *)
    colon *> skip_many1 newline *> return { Release.version; date }

  let release_header =
    atx_release_header
    <|> attempt setext_release_header
    <|> ascii_header <?> "release header"

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

  let rec continue_change d prev_lines =
    followed_by (many1 newline *> change_start) "next line not new change"
    <|> followed_by
          (many1 newline *> release_header)
          "next line not new release_header"
    <|> followed_by
          (blank_line *> not_followed_by (skip_count d.cur_change_d blank) "")
          "next line not new release"
    <|> followed_by (optional newline *> eof) "not changes eof"
    |>> (fun () ->
          {
            Change.description = String.concat "\n  " (List.rev prev_lines);
            bullet_point = Option.value ~default:'*' d.change_bullet;
          })
    <|> ( newline *> skip_upto_count d.cur_change_d blank *> line
        >>= fun next_line -> continue_change d (next_line :: prev_lines) )

  let change =
    change_start *> get_user_state >>= fun state ->
    line >>= fun description ->
    continue_change state [ description ] <* many1 newline

  let release =
    release_header >>= fun header ->
    many change >>= fun changes ->
    clear_bullet_state >> many newline
    >> return @@ Release.ReleaseChange (header, changes)

  let releases = many_until release eof

  let v = releases
end

let of_ parse changelog =
  let ps = { Parser.date_sep = None; change_bullet = None; cur_change_d = 1 } in
  match parse Parser.v changelog ps with
  | MParser.Success e -> Ok e
  | MParser.Failed (msg, _error) -> Error msg

let of_string = of_ MParser.parse_string

let of_channel = of_ MParser.parse_channel

let pp f changelog =
  Fmt.pf f "%a" Fmt.(list ~sep:(any "\n\n") Release.pp) changelog

let to_string changelog =
  Fmt.str "%a" Fmt.(list ~sep:(any "\n\n") Release.pp) changelog
