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

open Printf

type base = string

type t =
  | Base of base
  | Volatile of t
  | Atomic of t
  | Pointer of t

let rec  dump = function
  | Base s -> s
  | Volatile (Base s) -> "volatile " ^ s
  | Atomic (Base s) -> "_Atomic " ^ s
  | Volatile t -> sprintf "%s volatile" (dump t)
  | Atomic t -> sprintf "_Atomic (%s)" (dump t)
  | Pointer t -> dump t  ^ "*"


let rec is_atomic = function
  | Volatile t -> is_atomic t
  | Atomic _ -> true
  | _ -> false

let strip_atomic0 = function
  | Atomic t -> t
  | t -> t

let rec strip_atomic = function
  | Volatile t -> Volatile (strip_atomic t)
  | t ->  strip_atomic0 t

let strip_volatile0 = function
  | Volatile t -> t
  | t -> t

let rec strip_volatile = function
  | Atomic t -> Atomic (strip_volatile t)
  | t ->  strip_volatile0 t
