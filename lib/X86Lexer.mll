(*********************************************************************)
(*                        Memevents                                  *)
(*                                                                   *)
(* Jade Alglave, Luc Maranget, INRIA Paris-Rocquencourt, France.     *)
(* Susmit Sarkar, Peter Sewell, University of Cambridge, UK.         *)
(*                                                                   *)
(*  Copyright 2010 Institut National de Recherche en Informatique et *)
(*  en Automatique and the authors. All rights reserved.             *)
(*  This file is distributed  under the terms of the Lesser GNU      *)
(*  General Public License.                                          *)
(*********************************************************************)

{
module Make(O:LexUtils.Config) = struct
open Lexing
open LexMisc
open X86Parser
module X86 = X86Base
module LU = LexUtils.Make(O)
}
let digit = [ '0'-'9' ]
let alpha = [ 'a'-'z' 'A'-'Z']
let name  = alpha (alpha|digit|'_' | '/' | '.' | '-')*
let num = digit+

rule token = parse
| [' ''\t'] { token lexbuf }
| '\n'      { incr_lineno lexbuf; token lexbuf }
| "(*"      { LU.skip_comment lexbuf ; token lexbuf }
| '-' ? num as x { NUM (int_of_string x) }
| '$' ('-'? num as x) { INTEL_NUM (int_of_string x) }
| 'P' (num as x)
    { PROC (int_of_string x) }
| '%' (name as name) { SYMB_REG name }
| ';' { SEMI }
| ',' { COMMA }
| '|' { PIPE }
| '(' { LPAR }
| ')' { RPAR }
| '[' { LBRK }
| ']' { RBRK }
| ':' { COLON }
| "add"|"ADD"   { I_ADD }
| "xor"|"XOR"   { I_XOR }
| "mov"|"MOV"   { I_MOV }
| "movq"|"MOVQ"   { I_MOVQ }
| "movsd"|"MOVSD"   { I_MOVSD }
| "dec"|"DEC"   { I_DEC }
| "cmp"|"CMP"   { I_CMP }
| "cmovc"|"CMOVC"   { I_CMOVC }
| "inc"|"INC"   { I_INC }
| "jmp"|"JMP"   { I_JMP }
| "je"|"JE"    { I_JE }
| "jne"|"JNE"    { I_JNE }
| "lock"|"LOCK"   { I_LOCK }
| "xchg"|"XCHG"   { I_XCHG }
| "cmpxchg"|"CMPXCHG"   { I_CMPXCHG }
| "lfence"|"LFENCE"   { I_LFENCE }
| "sfence"|"SFENCE"   { I_SFENCE }
| "mfence"|"MFENCE"   { I_MFENCE }
| "read"|"READ"       { I_READ }
| "setnb"|"SETNB"       { I_SETNB }
| "xbegin"|"XBEGIN" { I_XBEGIN }
| "xabort"|"XABORT" { I_XABORT }
| "xend"|"XEND" { I_XEND }
| name as x
  { match X86.parse_reg x with
  | Some r -> ARCH_REG r
  | None -> NAME x }
| eof { EOF }
| ""  { error "X86" lexbuf }

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

