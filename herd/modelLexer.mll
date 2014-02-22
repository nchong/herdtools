(*********************************************************************)
(*                        Herd                                       *)
(*                                                                   *)
(* Luc Maranget, INRIA Paris-Rocquencourt, France.                   *)
(* Jade Alglave, University College London, UK.                      *)
(*                                                                   *)
(*  Copyright 2013 Institut National de Recherche en Informatique et *)
(*  en Automatique and the authors. All rights reserved.             *)
(*  This file is distributed  under the terms of the Lesser GNU      *)
(*  General Public License.                                          *)
(*********************************************************************)


{
module Make(O:LexUtils.Config) = struct
open Lexing
open LexMisc
open ModelParser
module LU = LexUtils.Make(O)

let keywords = Hashtbl.create 101
let () =
  List.iter
    (fun (s,k) -> Hashtbl.add keywords s k)
    [
     "MM",MM;  "MR",MR;  "MW",MW;
     "WM",WM; "WW",WW; "WR",WR; "RM",RM; "RW",RW; "RR",RR;
     "AA",AA; "AP",AP; "PA",PA; "PP",PP;
     "let",LET; "rec",REC; "set",SET; "rln",RLN; "and",AND;
     "acyclic",ACYCLIC; "irreflexive",IRREFLEXIVE;
     "show",SHOW;
     "unshow",UNSHOW;
     "empty",TESTEMPTY;
     "as",AS; "fun", FUN; "in",IN;
     "provides",PROVIDES; "requires",REQUIRES;
     "withco",WITHCO; "withoutco", WITHOUTCO;
   ]

(*
let scopes = Hashtbl.create 101
let () =
  List.iter
    (fun (s,k) -> Hashtbl.add scopes s k)
    [
     "work_item",AST.Work_Item; "thread",AST.Work_Item;
     "sub_group",AST.Sub_Group; "warp",AST.Sub_Group;
     "work_group",AST.Work_Group; "block",AST.Work_Group; "cta",AST.Work_Group;
     "kernel", AST.Kernel;
     "device", AST.Device; 
   ]
*)

}


let digit = [ '0'-'9' ]
let alpha = [ 'a'-'z' 'A'-'Z']
let name  = alpha (alpha|digit|'_' | '.')* '\''?

rule token = parse
| [' ''\t'] {  token lexbuf }
| '\n'      {  incr_lineno lexbuf; token lexbuf }
| "(*"      {  LU.skip_comment lexbuf ; token lexbuf }
| '#' [^'\n']* '\n' {  incr_lineno lexbuf ; token lexbuf }
| '(' {  LPAR }
| ')' {   RPAR }
| '[' {  LBRAC }
| ']' {   RBRAC }
| '_' { UNDERSCORE }
| '0'  {  EMPTY }
| "-1" { NEGONE }
| '|'  {  UNION }
| '&'  {  INTER }
| '*'  {  STAR }
| '~'  { COMP }
| '+'  {  PLUS }
| '\\'  {  DIFF }
| '?'  {  OPT }
| '='  {  EQUAL }
| ';'  {  SEMI }
| '^'  { HAT }
| ','  { COMMA }
| "->" { ARROW }
| '"' ([^'"']* as s) '"' { STRING s } (* '"' *)
| '2'  { TWO }
| name as x
    { 
      try Hashtbl.find keywords x with Not_found -> VAR x }
| eof { EOF }
| "" { error "Model lexer" lexbuf }

{
let token lexbuf =
   let tok = token lexbuf in
   if O.debug then begin
     Printf.eprintf
       "%a: Lexed '%s'\n"
       Pos.pp_pos2
       (lexeme_start_p lexbuf,lexeme_end_p lexbuf)
       (lexeme lexbuf)
   end ;
   tok
end
}
