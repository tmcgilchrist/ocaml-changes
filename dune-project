(lang dune 2.7)
(name ocaml-changes)
(generate_opam_files true)

(license ISC)
(maintainers "Tim McGilchrist <timmcgil@gmail.com")
(authors "Tim McGilchrist" "David Sheets")
(source (github tmcgilchrist/ocaml-changes))

(package
 (name ocaml-changes)
 (depends
  (alcotest :with-test)
  (ocaml (>= 4.08.0))
  (mparser (>= 1.3))
  (fmt (>= 0.8))
  (result (>= 1.5))
  (astring (>= 0.8))
  (bisect_ppx (and :dev (>= 2.5.0))))
 (synopsis "Changelog parser")
 (description "Provides a changelog data type, parser, linter, and printer"))