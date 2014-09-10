(*********************************************************************)
(*                        DIY                                        *)
(*                                                                   *)
(* Jade Alglave, Luc Maranget, INRIA Paris-Rocquencourt, France.     *)
(* Susmit Sarkar, Peter Sewell, University of Cambridge, UK.         *)
(*                                                                   *)
(*  Copyright 2013 Institut National de Recherche en Informatique et *)
(*  en Automatique and the authors. All rights reserved.             *)
(*  This file is distributed  under the terms of the Lesser GNU      *)
(*  General Public License.                                          *)
(*********************************************************************)

(***************************************)
(* Apply a function (zyva) to one test *)
(***************************************)

open Archs

module Top
    (T:sig type t end) (* Return type, must be abstracted *)
    (B: functor(A:ArchBase.S)->
      (sig val zyva : Name.t -> A.pseudo MiscParser.t -> T.t end)) :
sig
  val from_file : string -> T.t
end = struct

  module Make
      (A:ArchBase.S) 
      (L:GenParser.LexParse with type instruction = A.pseudo) =
    struct
      module P = GenParser.Make(GenParser.DefaultConfig)(A)(L)
      module X = B(A)


      let zyva chan splitted =
        let name = splitted.Splitter.name in
        let parsed = P.parse chan splitted in
        X.zyva name parsed
    end

  module LexConf = Splitter.Default

  let from_chan chan splitted = 
    match splitted.Splitter.arch with
    | PPC ->
        let module PPC = PPCBase in
        let module PPCLexParse = struct
	  type instruction = PPC.pseudo
	  type token = PPCParser.token

          module L = PPCLexer.Make(LexConf)
	  let lexer = L.token
	  let parser = PPCParser.main
        end in
        let module X = Make (PPC) (PPCLexParse) in
        X.zyva chan splitted
(*
  | PPCGen ->
  let module PPCGen = PPCGenArch.Make(V) in
  let module PPCGenLexParse = struct
  type instruction = PPCGen.pseudo
  type token = PPCGenParser.token

  let lexer = PPCGenLexer.token
  let parser = PPCGenParser.main
  end in
  let module X = Make (PPCGen) (PPCGenLexParse) in
  X.zyva chan splitted
 *)
    | X86 ->
        let module X86 = X86Base in
        let module X86LexParse = struct
	  type instruction = X86.pseudo
	  type token = X86Parser.token

          module L = X86Lexer.Make(LexConf)
	  let lexer = L.token
	  let parser = X86Parser.main
        end in
        let module X = Make (X86) (X86LexParse) in
        X.zyva chan splitted
    | ARM ->
        let module ARM = ARMBase in
        let module ARMLexParse = struct
	  type instruction = ARM.pseudo
	  type token = ARMParser.token

          module L = ARMLexer.Make(LexConf)
	  let lexer = L.token
	  let parser = ARMParser.main
        end in
        let module X = Make (ARM) (ARMLexParse) in
        X.zyva chan splitted
    | C -> Warn.fatal "No C arch in toolParse.ml"

  let from_file name =
    let module Y = ToolSplit.Top(LexConf)(T)
        (struct
          let zyva = from_chan
        end) in
    Y.from_file name

end

module Tops
    (T:sig type t end) (* Return type, must be abstracted *)
    (B: functor(A:Arch.S)->
      (sig val zyva : (Name.t * A.test) list -> T.t end)) :
    sig
      val from_files : string list -> T.t
    end = struct

      module LexConf = Splitter.Default

      module Make
          (A:Arch.S) 
          (L:GenParser.LexParse with type instruction = A.pseudo) =
        struct
          module P = GenParser.Make(GenParser.DefaultConfig)(A)(L)
          module X = B(A)
          module Alloc = SymbReg.Make(A)

          let justparse chan splitted =
            let parsed = P.parse chan splitted
            and doc = splitted.Splitter.name in
            let allocated = Alloc.allocate_regs parsed in
            doc,allocated

          module SP = Splitter.Make(LexConf)

          let from_chan name chan =
            let { Splitter.arch=arch;_ } as splitted = SP.split name chan in
            if arch <> A.arch then
              Warn.fatal
                "Arch mismatch on %s (%s <-> %s)"
                name (Archs.pp A.arch)  (Archs.pp arch) ;
            justparse chan splitted

          let from_name name = Misc.input_protect (from_chan name) name

          let rec from_names ns = match ns with
          | [] -> []
          | n::ns ->
              let dt = from_name n in
              dt::from_names ns

          let zyva names =
            let dts = from_names names in
            X.zyva dts
        end

      module Extend (A:ArchBase.S) = struct
        open Printf
        let hexa = false
        include A
        module V = struct
          include SymbConstant
          let maybevToV c = c
        end
        type location = 
          | Location_global of Constant.v
          | Location_reg of int * A.reg

        let maybev_to_location c = Location_global c

        let pp_location = function
          | Location_global c -> V.pp hexa c
          | Location_reg (i,r) -> sprintf "%i:%s" i (pp_reg r)

        let pp_rval = function
          | Location_global c -> sprintf "*%s" (V.pp hexa c)
          | Location_reg (i,r) -> sprintf "%i:%s" i (pp_reg r)


        type test =
            ((location * V.v) list, (int * pseudo list) list,
             (location, V.v) ConstrGen.prop ConstrGen.constr, location)
              MiscParser.result
      end

      let from_arch arch = 
        match arch with
        | PPC ->
            let module PPC = PPCBase in
            let module PPCLexParse = struct
	      type instruction = PPC.pseudo
	      type token = PPCParser.token

              module L = PPCLexer.Make(LexConf)
	      let lexer = L.token
	      let parser = PPCParser.main
            end in
            let module X = Make (Extend(PPC)) (PPCLexParse) in
            X.zyva 
        | X86 ->
            let module X86 = X86Base in
            let module X86LexParse = struct
	      type instruction = X86.pseudo
	      type token = X86Parser.token

              module L = X86Lexer.Make(LexConf)
	      let lexer = L.token
	      let parser = X86Parser.main
            end in
            let module X = Make (Extend(X86)) (X86LexParse) in
            X.zyva
        | ARM ->
            let module ARM = ARMBase in
            let module ARMLexParse = struct
	      type instruction = ARM.pseudo
	      type token = ARMParser.token

              module L = ARMLexer.Make(LexConf)
	      let lexer = L.token
	      let parser = ARMParser.main
            end in
            let module X = Make (Extend(ARM)) (ARMLexParse) in
            X.zyva
        | C -> Warn.fatal "No C arch in toolParse.ml"

      let from_files names =
        let module Y = ToolSplit.Tops(LexConf)(T)
            (struct
              let zyva = from_arch
            end) in
        Y.from_files names

    end
