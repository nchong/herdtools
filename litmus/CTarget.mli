(*********************************************************************)
(*                          Litmus                                   *)
(*                                                                   *)
(*        Luc Maranget, INRIA Paris-Rocquencourt, France.            *)
(*                                                                   *)
(*  Copyright 2014 Institut National de Recherche en Informatique et *)
(*  en Automatique and the authors. All rights reserved.             *)
(*  This file is distributed  under the terms of the Lesser GNU      *)
(*  General Public License.                                          *)
(*********************************************************************)

(* C target, a simplified template *)

type arch_reg = string

type t =
  { inputs : string list ;
    finals : arch_reg list ;
    code : string ; }

   
val fmt_reg : arch_reg -> string
val dump_out_reg : int -> arch_reg -> string
val compile_out_reg : int -> arch_reg -> string
val get_addrs : t -> string list

