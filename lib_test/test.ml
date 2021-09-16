let ( / ) = Filename.concat

let read_ic ic =
  let rec loop prev =
    match try Some (input_line ic) with End_of_file -> None with
    | Some line -> loop (line :: prev)
    | None -> List.rev prev
  in
  String.concat "\n" (loop [])

let read_file path =
  let ic = open_in path in
  let contents = read_ic ic in
  close_in ic;
  contents

let read_tests f =
  let cases = "cases" in
  let contents = Array.to_list (Sys.readdir cases) in
  let case_list =
    List.filter (fun c -> Sys.is_directory (cases / c)) contents
  in
  List.map (fun dir -> (cases / dir, `Quick, f (cases / dir))) case_list

let check_diff dir s =
  let expected = dir / "expected" in
  let output = dir / "output" in
  let oc = open_out output in
  output_string oc s;
  close_out oc;
  let diff = Printf.sprintf "diff -u %s %s" expected output in
  let diff_out, diff_in = Unix.open_process diff in
  let diff_output = read_ic diff_out in
  match Unix.close_process (diff_out, diff_in) with
  | Unix.WEXITED 0 -> ()
  | Unix.WEXITED x ->
      Alcotest.fail ("diff failed " ^ string_of_int x ^ ":\n" ^ diff_output)
  | _ -> Alcotest.fail "diff failed unexpectedly"

(* parse, print *)
module Parse = struct
  let test dir () =
    let ic = open_in (dir / "CHANGES") in
    match Changes.of_channel ic with
    | Result.Error message -> check_diff dir message
    | Result.Ok changes -> check_diff dir (Changes.to_string changes)

  let tests = read_tests test
end

let changes =
  let module M = struct
    type t = Changes.t

    let pp = Changes.pp

    let equal = ( = )
  end in
  (module M : Alcotest.TESTABLE with type t = M.t)

let unit_test str ast =
  Alcotest.(check changes) "parse" ast (Result.get_ok @@ Changes.of_string str)

let test_atx_release_header () =
  let ast =
    [
      Changes.Release.ReleaseChange
        ( {
            Changes.Release.version = "0.3.0";
            date = Some (Changes.Release.FullDate ("2018", "07", "10", '-'));
          },
          [] );
    ]
  in
  let str = "## 0.3.0 (2018-07-10)" in
  unit_test str ast

let test_setext_release_header () =
  let ast =
    [
      Changes.Release.ReleaseChange
        ( {
            Changes.Release.version = "0.3.0";
            date = Some (Changes.Release.FullDate ("2018", "07", "10", '-'));
          },
          [] );
    ]
  in
  let str = "0.3.0 (2018-07-10)\n------\n" in
  unit_test str ast

let test_ascii_release_header () =
  let ast =
    [
      Changes.Release.ReleaseChange
        ( {
            Changes.Release.version = "0.3.0";
            date = Some (Changes.Release.FullDate ("2018", "07", "10", '-'));
          },
          [] );
    ]
  in
  let str = "0.3.0 (2018-07-10):\n" in
  unit_test str ast

let test_empty () = unit_test "" []

let test_releases_with_no_changes () =
  let ast =
    [
      Changes.Release.ReleaseChange
        ( {
            Changes.Release.version = "0.2.0";
            date = Some (Changes.Release.FullDate ("2015", "01", "01", '-'));
          },
          [] );
      Changes.Release.ReleaseChange
        ( {
            Changes.Release.version = "0.1.0";
            date = Some (Changes.Release.FullDate ("2014", "01", "01", '-'));
          },
          [] );
    ]
  in
  let str = "0.2.0 (2015-01-01):\n0.1.0 (2014-01-01):\n" in
  unit_test str ast

let test_releases_with_changes () =
  let ast =
    [
      Changes.Release.ReleaseChange
        ( {
            Changes.Release.version = "0.2.0";
            date = Some (Changes.Release.FullDate ("2015", "01", "01", '-'));
          },
          [ { Changes.Change.description = "things"; bullet_point = '*' } ] );
      Changes.Release.ReleaseChange
        ( {
            Changes.Release.version = "0.1.0";
            date = Some (Changes.Release.FullDate ("2014", "01", "01", '-'));
          },
          [] );
    ]
  in
  let str = "# 0.2.0 (2015-01-01):\n* things\n# 0.1.0 (2014-01-01):\n" in
  unit_test str ast

let () =
  let open Alcotest in
  let tests =
    [
      ("parse_print", Parse.tests);
      ( "test_parse",
        [
          test_case "empty" `Quick test_empty;
          test_case "atx_release_header" `Quick test_atx_release_header;
          test_case "setext_release_header" `Quick test_setext_release_header;
          test_case "ascii_release_header" `Quick test_ascii_release_header;
          test_case "test release with no changes" `Quick
            test_releases_with_no_changes;
          test_case "test release with changes" `Quick
            test_releases_with_changes;
        ] );
    ]
  in
  Alcotest.run "Changes" tests
