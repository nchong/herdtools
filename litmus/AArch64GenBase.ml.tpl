(**************************************************************************)
(*                                  DIY                                   *)
(*                                                                        *)
(* Jade Alglave, Luc Maranget, INRIA Paris-Rocquencourt, France.          *)
(* Shaked Flur, Susmit Sarkar, Peter Sewell, University of Cambridge, UK. *)
(*                                                                        *)
(*  Copyright 2015 Institut National de Recherche en Informatique et en   *)
(*  Automatique and the authors. All rights reserved.                     *)
(*  This file is distributed  under the terms of the Lesser GNU General   *)
(*  Public License.                                                       *)
(**************************************************************************)

(** Define registers, barriers, and instructions for AArch64 *)

open Printf

(* Who am i ? *)
let arch = `AArch64

(* #include "./src_aarch64_hgen/types.hgen" *)

let big_in_range (n : Nat_big_num.num) (min : int) (max : int) =
  let big_min = Nat_big_num.of_int min in
  let big_max = Nat_big_num.of_int max in
  (Nat_big_num.less_equal big_min n) && (Nat_big_num.less_equal n big_max)
  
(*************)
(* Registers *)
(*************)

type ireg =
  | R0 | R1 | R2 | R3
  | R4 | R5 | R6 | R7
  | R8 | R9 | R10 | R11
  | R12 | R13 | R14 | R15
  | R16 | R17 | R18 | R19
  | R20 | R21 | R22 | R23
  | R24 | R25 | R26 | R27
  | R28 | R29 | R30

type reg =
  | PC
  | Ireg of ireg
  | ZR
  | SP
  | Symbolic_reg of string
(* Internal regs *)
  | Internal of int

type inst_reg =
  | X of reg
  | W of reg

(* FIXME: do we need these *)
let base =  Internal 0
and max_idx = Internal 1
and idx = Internal 2
and ephemeral = Internal 3
let loop_idx = Internal 4

let xregs =
  [
    Ireg R0,  "X0"  ; Ireg R1,  "X1"  ; Ireg R2,  "X2"  ; Ireg R3,  "X3"  ;
    Ireg R4,  "X4"  ; Ireg R5,  "X5"  ; Ireg R6,  "X6"  ; Ireg R7,  "X7"  ;
    Ireg R8,  "X8"  ; Ireg R9,  "X9"  ; Ireg R10, "X10" ; Ireg R11, "X11" ;
    Ireg R12, "X12" ; Ireg R13, "X13" ; Ireg R14, "X14" ; Ireg R15, "X15" ;
    Ireg R16, "X16" ; Ireg R17, "X17" ; Ireg R18, "X18" ; Ireg R19, "X19" ;
    Ireg R20, "X20" ; Ireg R21, "X21" ; Ireg R22, "X22" ; Ireg R23, "X23" ;
    Ireg R24, "X24" ; Ireg R25, "X25" ; Ireg R26, "X26" ; Ireg R27, "X27" ;
    Ireg R28, "X28" ; Ireg R29, "X29" ; Ireg R30, "X30" ;
    ZR, "XZR" ;
  ]

let wregs =
  [
    Ireg R0,  "W0"  ; Ireg R1,  "W1"  ; Ireg R2,  "W2"  ; Ireg R3,  "W3"  ;
    Ireg R4,  "W4"  ; Ireg R5,  "W5"  ; Ireg R6,  "W6"  ; Ireg R7,  "W7"  ;
    Ireg R8,  "W8"  ; Ireg R9,  "W9"  ; Ireg R10, "W10" ; Ireg R11, "W11" ;
    Ireg R12, "W12" ; Ireg R13, "W13" ; Ireg R14, "W14" ; Ireg R15, "W15" ;
    Ireg R16, "W16" ; Ireg R17, "W17" ; Ireg R18, "W18" ; Ireg R19, "W19" ;
    Ireg R20, "W20" ; Ireg R21, "W21" ; Ireg R22, "W22" ; Ireg R23, "W23" ;
    Ireg R24, "W24" ; Ireg R25, "W25" ; Ireg R26, "W26" ; Ireg R27, "W27" ;
    Ireg R28, "W28" ; Ireg R29, "W29" ; Ireg R30, "W30" ;
    ZR, "WZR" ; SP, "WSP" ;
  ]

let parse_xlist =
  List.map (fun (r,s) -> s,r) xregs

let parse_wlist =
  List.map (fun (r,s) -> s,r) wregs

let parse_xreg s =
  try Some (List.assoc s parse_xlist)
  with Not_found -> None

let parse_wreg s =
  try Some (List.assoc s parse_wlist)
  with Not_found -> None

let parse_reg = parse_xreg

let pp_reg r =
  match r with
  | Symbolic_reg r -> "%" ^ r
  | Internal i -> Printf.sprintf "i%i" i
  | _ -> try List.assoc r xregs with Not_found -> assert false


let reg_compare = Pervasives.compare

let is_zero_reg r = (r = X ZR || r = W ZR)
let is_sp_reg r = (r = X SP || r = W SP)

let ireg_to_int r =
  match r with
  | R0 -> 0   | R1 -> 1   | R2 -> 2   | R3 -> 3   | R4 -> 4   | R5 -> 5   | R6 -> 6   | R7 -> 7
  | R8 -> 8   | R9 -> 9   | R10 -> 10 | R11 -> 11 | R12 -> 12 | R13 -> 13 | R14 -> 14 | R15 -> 15
  | R16 -> 16 | R17 -> 17 | R18 -> 18 | R19 -> 19 | R20 -> 20 | R21 -> 21 | R22 -> 22 | R23 -> 23
  | R24 -> 24 | R25 -> 25 | R26 -> 26 | R27 -> 27 | R28 -> 28 | R29 -> 29 | R30 -> 30

let ireg_of_int i =
  match i with
  | 0 -> R0   | 1 -> R1   | 2 -> R2   | 3 -> R3   | 4 -> R4   | 5 -> R5   | 6 -> R6   | 7 -> R7
  | 8 -> R8   | 9 -> R9   | 10 -> R10 | 11 -> R11 | 12 -> R12 | 13 -> R13 | 14 -> R14 | 15 -> R15
  | 16 -> R16 | 17 -> R17 | 18 -> R18 | 19 -> R19 | 20 -> R20 | 21 -> R21 | 22 -> R22 | 23 -> R23
  | 24 -> R24 | 25 -> R25 | 26 -> R26 | 27 -> R27 | 28 -> R28 | 29 -> R29 | 30 -> R30

let inst_reg_to_int r =
  match r with
  | X (Ireg r') | W (Ireg r') -> ireg_to_int r'
  | X ZR | X SP | W ZR | W SP -> 31
  (* TODO: do we need to handle the other regs? *)


(************)
(* Barriers *)
(************)

type barrier =
  | DMB of mBReqDomain*mBReqTypes
  | DSB of mBReqDomain*mBReqTypes
  | ISB

let all_kinds_of_barriers =
  [
    DMB (MBReqDomain_FullSystem, MBReqTypes_All);
    DMB (MBReqDomain_FullSystem, MBReqTypes_Reads);
    DMB (MBReqDomain_FullSystem, MBReqTypes_Writes);
    DSB (MBReqDomain_FullSystem, MBReqTypes_All);
    DSB (MBReqDomain_FullSystem, MBReqTypes_Reads);
    DSB (MBReqDomain_FullSystem, MBReqTypes_Writes);
    ISB;
  ]

let pp_option domain types =
  match (domain,types) with
  | (MBReqDomain_OuterShareable, MBReqTypes_Reads)  -> "OSHLD"
  | (MBReqDomain_OuterShareable, MBReqTypes_Writes) -> "OSHST"
  | (MBReqDomain_OuterShareable, MBReqTypes_All)    -> "OSH"
  | (MBReqDomain_Nonshareable,   MBReqTypes_Reads)  -> "NSHLD"
  | (MBReqDomain_Nonshareable,   MBReqTypes_Writes) -> "NSHST"
  | (MBReqDomain_Nonshareable,   MBReqTypes_All)    -> "NSH"
  | (MBReqDomain_InnerShareable, MBReqTypes_Reads)  -> "ISHLD"
  | (MBReqDomain_InnerShareable, MBReqTypes_Writes) -> "ISHST"
  | (MBReqDomain_InnerShareable, MBReqTypes_All)    -> "ISH"
  | (MBReqDomain_FullSystem,     MBReqTypes_Reads)  -> "LD"
  | (MBReqDomain_FullSystem,     MBReqTypes_Writes) -> "ST"
  | (MBReqDomain_FullSystem,     MBReqTypes_All)    -> "SY"

let pp_barrier b =
  match b with
  | DMB(domain,types) -> "DMB " ^ (pp_option domain types)
  | DSB(domain,types) -> "DSB " ^ (pp_option domain types)
  | ISB -> "ISB"

let barrier_compare = Pervasives.compare

(****************)
(* Instructions *)
(****************)

type label = Label.t

type instruction =
  [
    (* #include "./src_aarch64_hgen/ast.hgen" *)

    (* Branch *)
    (* these instructions take a 'label' instead of offset (bit64) *)
    | `AArch64BranchImmediate_label of branchType*label (* _branch_type,offset *)
    | `AArch64BranchConditional_label of label*bit4 (* offset,condition *)
    | `AArch64CompareAndBranch_label of inst_reg*reg_size*boolean*label (* t,datasize,iszero,offset *)
    | `AArch64TestBitAndBranch_label of inst_reg*reg_size*integer*bit*label (* t,datasize,bit_pos,bit_val,offset *)
  ]


(*** TODO: maybe put these in a different file? ***)
(*** pretty aux functions ***)

let pp_imm imm = sprintf "#%d" imm
let pp_big_imm imm = "#" ^ (Nat_big_num.to_string imm)

let pp_reg_size_imm imm =
  match imm with
  | R32Bits imm -> pp_imm imm
  | R64Bits imm -> pp_big_imm imm

let pp_offset page offset = pp_big_imm offset (* FIXME: make this right *)

let pp_label label = label

let pp_withflags inst setflags =
  if setflags then (inst ^ "S")
  else inst

let pp_regzr sf r = (*pp_reg r*)
  match r with
  | X ZR -> "XZR"
  | X (Ireg i) -> sprintf "X%d" (ireg_to_int i)
  | X (Symbolic_reg s) -> "X" ^ s
  | W ZR -> "WZR"
  | W (Ireg i) -> sprintf "W%d" (ireg_to_int i)
  | W (Symbolic_reg s) -> "W" ^ s

let pp_regsp sf r = (*pp_reg r*)
  match r with
  | X SP -> "SP"
  | X (Ireg i) -> sprintf "X%d" (ireg_to_int i)
  | X (Symbolic_reg s) -> "X" ^ s
  | W SP -> "WSP"
  | W (Ireg i) -> sprintf "W%d" (ireg_to_int i)
  | W (Symbolic_reg s) -> "W" ^ s

let pp_regzrbyext sf extend_type r = (*pp_reg r*)
  (*match extend_type with
  | ExtendType_UXTX | ExtendType_SXTX -> pp_regzr sf r
  | _ -> pp_regzr Set32 r*)
  match r with
  | X ZR -> "XZR"
  | X (Ireg i) -> sprintf "X%d" (ireg_to_int i)
  | X (Symbolic_reg s) -> "X" ^ s
  | W ZR -> "WZR"
  | W (Ireg i) -> sprintf "W%d" (ireg_to_int i)
  | W (Symbolic_reg s) -> "W" ^ s

let pp_regext ext =
  match ext with
  | ExtendType_UXTB -> "UXTB"
  | ExtendType_UXTH -> "UXTH"
  | ExtendType_UXTW -> "UXTW"
  | ExtendType_UXTX -> "UXTX"
  | ExtendType_SXTB -> "SXTB"
  | ExtendType_SXTH -> "SXTH"
  | ExtendType_SXTW -> "SXTW"
  | ExtendType_SXTX -> "SXTX"

let pp_sysreg (sys_op0,sys_op1,sys_op2,sys_crn,sys_crm) =
  match (sys_op0,sys_op1,sys_op2,sys_crn,sys_crm) with
  | (0b11,0b011,0b000,0b0100,0b0010) -> "NZCV"
  | (0b11,0b011,0b001,0b0100,0b0010) -> "DAIF"

let pp_pstatefield field =
  match field with
  | PSTATEField_DAIFSet -> "DAIFSet"
  | PSTATEField_DAIFClr -> "DAIFClr"
  | PSTATEField_SP      -> "SPSel"

let pp_shift shift =
  match shift with
  | ShiftType_LSL -> "LSL"
  | ShiftType_LSR -> "LSR"
  | ShiftType_ASR -> "ASR"
  | ShiftType_ROR -> "ROR"

let pp_shiftop shifttype =
  match shifttype with
  | ShiftType_ASR -> "ASR"
  | ShiftType_LSL -> "LSL"
  | ShiftType_LSR -> "LSR"
  | ShiftType_ROR -> "ROR"

let pp_ifnz amount =
  if amount = 0 then "" else (" " ^ (pp_imm amount))

let pp_addsub sub_op =
  pp_withflags (if sub_op then "SUB" else "ADD")

let pp_logop op setflags invert =
  match (op,invert) with
  | (LogicalOp_AND,false) -> if setflags then "ANDS" else "AND"
  | (LogicalOp_AND,true)     -> if setflags then "BICS" else "BIC"
  | (LogicalOp_EOR,false) -> "EOR" (*assert (not setflags)*)
  | (LogicalOp_EOR,true)     -> "EON" (*assert (not setflags)*)
  | (LogicalOp_ORR,false) -> "ORR" (*assert (not setflags)*)
  | (LogicalOp_ORR,true)     -> "ORN" (*assert (not setflags)*)

let pp_cond cond =
  match cond with
  | 0b0000 -> "EQ"
  | 0b0001 -> "NE"
  | 0b0010 -> "CS"
  | 0b0011 -> "CC"
  | 0b0100 -> "MI"
  | 0b0101 -> "PL"
  | 0b0110 -> "VS"
  | 0b0111 -> "VC"
  | 0b1000 -> "HI"
  | 0b1001 -> "LS"
  | 0b1010 -> "GE"
  | 0b1011 -> "LT"
  | 0b1100 -> "GT"
  | 0b1101 -> "LE"
  | 0b1110 -> "AL"
  | 0b1111 -> "NV"

let pp_bfm inzero extend =
  match (inzero,extend) with
  | (false,false) -> "BFM"
  | (true,true)   -> "SBFM"
  | (true,false)  -> "UBFM"

let pp_branchimmediate branch_type =
  match branch_type with
  | BranchType_JMP -> "B"
  | BranchType_CALL -> "BL"

let pp_branchregister branch_type =
  match branch_type with
  | BranchType_JMP -> "BR"
  | BranchType_CALL -> "BLR"
  | BranchType_RET -> "RET"

let pp_countop opcode =
  match opcode with
  | CountOp_CLS -> "CLS"
  | CountOp_CLZ -> "CLZ"

let pp_crc size crc32c =
  let sz =
    match size with
    | DataSize8  -> "B"
    | DataSize16 -> "H"
    | DataSize32 -> "W"
    | DataSize64 -> "X"
    in
  "CRC" ^ (if crc32c then "C" else "") ^ sz

let pp_csel else_inv else_inc =
  match (else_inv,else_inc) with
  | (false,false) -> "CSEL"
  | (false,true)  -> "CSINC"
  | (true,false)  -> "CSINV"
  | (true,true)   -> "CSNEG"

let pp_barr op =
  match op with
  | MemBarrierOp_DSB -> "DSB"
  | MemBarrierOp_DMB -> "DMB"
  | MemBarrierOp_ISB -> "ISB"

let pp_barroption domain types =
  if domain = MBReqDomain_FullSystem && types = MBReqTypes_All then "SY"
  else
  let pref =
    match domain with
    | MBReqDomain_OuterShareable -> "OSH"
    | MBReqDomain_Nonshareable ->   "NSH"
    | MBReqDomain_InnerShareable -> "ISH"
    | MBReqDomain_FullSystem ->     "" in
  let suff =
    match types with
    | MBReqTypes_Reads ->  "LD"
    | MBReqTypes_Writes -> "ST"
    | MBReqTypes_All ->    "" in
  pref ^ suff

let pp_ldaxstlxp memop acctype excl pair datasize =
  (match memop with
  | MemOp_STORE -> "ST" ^ (if acctype = AccType_ORDERED then "L" else "")
  | MemOp_LOAD ->  "LD" ^ (if acctype = AccType_ORDERED then "A" else ""))
  ^
  (if excl then "X" else "")
  ^
  (if pair then "P" else
  match datasize with
  | DataSize32 | DataSize64 -> "R"
  | DataSize8 ->               "RB"
  | DataSize16 ->              "RH")

let pp_movwide opcode =
  match opcode with
  | MoveWideOp_N -> "MOVN"
  | MoveWideOp_Z -> "MOVZ"
  | MoveWideOp_K -> "MOVK"

let pp_maddsubl sub_op unsigned =
  (if unsigned then "U" else "S") ^ "M" ^ (pp_addsub sub_op false) ^ "L"

let moveWidePreferred sf imm = false (* FIXME: implement the function from arm arm *)
let bFXPreferred sf opc1 imms immr = false (* FIXME: implement the function from arm arm *)

let pp_prfop prfop =
  match prfop with
  | 0b00000 -> "PLDL1KEEP"
  | 0b00001 -> "PLDL1STRM"
  | 0b00010 -> "PLDL2KEEP"
  | 0b00011 -> "PLDL2STRM"
  | 0b00100 -> "PLDL3KEEP"
  | 0b00101 -> "PLDL3STRM"
  (**)
  | 0b01000 -> "PLIL1KEEP"
  | 0b01001 -> "PLIL1STRM"
  | 0b01010 -> "PLIL2KEEP"
  | 0b01011 -> "PLIL2STRM"
  | 0b01100 -> "PLIL3KEEP"
  | 0b01101 -> "PLIL3STRM"
  (**)
  | 0b10000 -> "PSTL1KEEP"
  | 0b10001 -> "PSTL1STRM"
  | 0b10010 -> "PSTL2KEEP"
  | 0b10011 -> "PSTL2STRM"
  | 0b10100 -> "PSTL3KEEP"
  | 0b10101 -> "PSTL3STRM"
  | _ -> (pp_imm prfop)

let pp_reverse sf op =
  match op with
  | RevOp_RBIT -> "RBIT"
  | RevOp_REV64 -> "REV"
  | RevOp_REV16 -> "REV16"
  | RevOp_REV32 -> if sf = Set32 then "REV" else "REV32"

(*** TODO: end ***)

let instruction_printer (pp_regzr : reg_size -> inst_reg -> string) (pp_regsp : reg_size -> inst_reg -> string) (pp_regzrbyext : reg_size -> extendType -> inst_reg -> string) (pp_label : string -> string) (instruction : instruction) : string  =
  match instruction with
  (* #include "./src_aarch64_hgen/pretty.hgen" *)
  | `AArch64BranchConditional_label (label,condition) ->
        sprintf "B.%s %s" (pp_cond condition) (pp_label label)
  | `AArch64BranchImmediate_label (_branch_type,label) ->
        sprintf "%s %s" (pp_branchimmediate _branch_type) (pp_label label)
  | `AArch64CompareAndBranch_label (t, datasize, iszero, label) ->
        sprintf "%s %s, %s" (if iszero then "CBZ" else "CBNZ") (pp_regzr datasize t) (pp_label label)
  | `AArch64TestBitAndBranch_label (t, datasize, bit_pos, bit_val, label) ->
        sprintf "%s %s, %s, %s" (if bit_pos = 1 then "TBNZ" else "TBZ") (pp_regzr (if bit_pos > 31 then Set64 else Set32) t) (pp_imm bit_pos) (pp_label label)
  | _ -> failwith "unrecognised instruction"

let do_pp_instruction = instruction_printer pp_regzr pp_regsp pp_regzrbyext pp_label


let pp_instruction _m i = do_pp_instruction i

let dump_instruction = do_pp_instruction

(****************************)
(* Symbolic registers stuff *)
(****************************)

(*let allowed_for_symb =
  [ Xreg R0  ; Xreg R1  ; Xreg R2  ; Xreg R3  ;
    Xreg R4  ; Xreg R5  ; Xreg R6  ; Xreg R7  ;
    Xreg R8  ; Xreg R9  ; Xreg R10 ; Xreg R11 ;
    Xreg R12 ; Xreg R13 ; Xreg R14 ; Xreg R15 ;
    Xreg R16 ; Xreg R17 ; Xreg R18 ; Xreg R19 ;
    Xreg R20 ; Xreg R21 ; Xreg R22 ; Xreg R23 ;
    Xreg R24 ; Xreg R25 ; Xreg R26 ; Xreg R27 ;
    Xreg R28 ; Xreg R29 ; Xreg R30 ;
    Wreg R0  ; Wreg R1  ; Wreg R2  ; Wreg R3  ;
    Wreg R4  ; Wreg R5  ; Wreg R6  ; Wreg R7  ;
    Wreg R8  ; Wreg R9  ; Wreg R10 ; Wreg R11 ;
    Wreg R12 ; Wreg R13 ; Wreg R14 ; Wreg R15 ;
    Wreg R16 ; Wreg R17 ; Wreg R18 ; Wreg R19 ;
    Wreg R20 ; Wreg R21 ; Wreg R22 ; Wreg R23 ;
    Wreg R24 ; Wreg R25 ; Wreg R26 ; Wreg R27 ;
    Wreg R28 ; Wreg R29 ; Wreg R30 ]*)
let allowed_for_symb =
  [ Ireg R0  ; Ireg R1  ; Ireg R2  ; Ireg R3  ;
    Ireg R4  ; Ireg R5  ; Ireg R6  ; Ireg R7  ;
    Ireg R8  ; Ireg R9  ; Ireg R10 ; Ireg R11 ;
    Ireg R12 ; Ireg R13 ; Ireg R14 ; Ireg R15 ;
    Ireg R16 ; Ireg R17 ; Ireg R18 ; Ireg R19 ;
    Ireg R20 ; Ireg R21 ; Ireg R22 ; Ireg R23 ;
    Ireg R24 ; Ireg R25 ; Ireg R26 ; Ireg R27 ;
    Ireg R28 ; Ireg R29 ; Ireg R30 ]

let fold_regs (f_reg,f_sreg) =
  (* Let us have a functional style... *)
  let fold_reg reg (y_reg,y_sreg) =
    match reg with
    | X (Symbolic_reg s)
    | W (Symbolic_reg s) -> y_reg, f_sreg s y_sreg
(*     | Xreg _ | XZR | SP | Wreg _ | WZR | WSP -> f_reg reg y_reg, y_sreg *)
    | X ((Ireg _) as reg') | X (ZR as reg') | X (SP as reg')
    | W ((Ireg _) as reg') | W (ZR as reg') | W (SP as reg') -> f_reg reg' y_reg, y_sreg
    | _ -> y_reg, y_sreg in

  fun (y_reg,y_sreg as c) ins ->
    match ins with
    (* #include "./src_aarch64_hgen/fold.hgen" *)
    | _ -> c

(* Map over symbolic regs *)
let map_regs f_reg f_symb =
  let map_reg reg =
    match reg with
    | X (Symbolic_reg s) -> X (f_symb s)
    | W (Symbolic_reg s) -> W (f_symb s)
    (*| Xreg _ | XZR | SP | Wreg _ | WZR | WSP -> f_reg reg*)
    | X ((Ireg _) as reg') | X (ZR as reg') | X (SP as reg') -> X (f_reg reg')
    | W ((Ireg _) as reg') | W (ZR as reg') | W (SP as reg') -> W (f_reg reg')
    | _ -> reg in

  fun ins ->
    match ins with
    (* #include "./src_aarch64_hgen/map.hgen" *)
    | _ -> ins

(* No addresses burried in ARM code *)
let fold_addrs _f c _ins = c

let map_addrs _f ins = ins

let norm_ins ins = ins

(* Instruction continuation *)
let get_next = function
  | _ -> [Label.Next]

include Pseudo.Make
  (struct
      type ins = instruction
      type reg_arg = reg

      let get_naccesses = function
        (* number of memory accesses *)
        (* XXX this should be guessable from pseudocode *)
        | _ ->  failwith "shouldn't need this for litmus"

      let fold_labels k f = function
        | _ -> k

      let map_labels f = function
        | ins -> ins

  end)

let get_macro _name = raise Not_found

(* #include "./src_aarch64_hgen/token_types.hgen" *)

(*** TODO: maybe put these in a different file? ***)
(*** parser aux functions ***)

(* check_bits: returns true iff any bit that is not between lsb and
               lsb+count-1 has the value 0 *)
let check_bits (n : Nat_big_num.num) (lsb : int) (count : int) =
  Nat_big_num.equal
    n
    (Nat_big_num.shift_left (Nat_big_num.extract_num n lsb count) lsb)

let iskbituimm k imm = 0 <= imm && imm < (1 lsl k)
let big_iskbituimm k imm = check_bits imm 0 k
let iskbitsimm k imm = -(1 lsl (k-1)) <= imm && imm < (1 lsl (k-1))

(* invert: inverts the least significant bit *)
let invert n = if n mod 2 = 0 then (n+1) else (n-1)

(* TODO: this is a function from ARM ARM, we have a better implementation
         in Sail and we should use it instead of this *)
let decodeBitMasks regSize (immN : int) (imms : int) (immr : int) (immediate : bool) =
  assert (regSize = 32 || regSize = 64) ;

  (* Compute log2 of element size *)
  (* 2^len must be in range [2, regSize] *)
  let len : int =
    if immN = 1 then 6
    else if 0b100000 land imms = 0 then 5
    else if 0b10000 land imms = 0 then 4
    else if 0b1000 land imms = 0 then 3
    else if 0b100 land imms = 0 then 2
    else if 0b10 land imms = 0 then 1
    else if 0b1 land imms = 0 then 0
    else -1 in

  if len < 1 then failwith "reserved value" else
  if not (regSize >= (1 lsl len)) then failwith "assert failed" else

  (* Determine S, R and S - R parameters *)
  let levels : int = (1 lsl len) - 1 in

  (* For logical immediates an all-ones value of S is reserved *)
  (* since it would generate a useless all-ones result (many times) *)
  if immediate && ((imms land levels) = levels) then failwith "reserved value" else

  let _S : int = imms land levels in
  let _R : int = immr land levels in

  let diff : int = _S - _R in

  let esize : int = 1 lsl len in

  let d : int = diff land levels in
  let welem : Nat_big_num.num = Nat_big_num.pred (Nat_big_num.shift_left (Nat_big_num.of_int 1) (_S+1)) in
  let telem : Nat_big_num.num = Nat_big_num.pred (Nat_big_num.shift_left (Nat_big_num.of_int 1) (d+1)) in

  let ror (n : Nat_big_num.num) (k : int) =
    let k = k mod esize in
    if k = 0 then n else
    let d = Nat_big_num.extract_num n 0 k in
    Nat_big_num.bitwise_or
      (Nat_big_num.shift_left d (esize-k))
      (Nat_big_num.shift_right n k) in

  let rec replicate (n : Nat_big_num.num) k =
    if k = 1 then n else
    let d = replicate n (k-1) in
    Nat_big_num.bitwise_or n (Nat_big_num.shift_left d esize) in

  let wmask : Nat_big_num.num = replicate (ror welem _R) (regSize / esize) in
  let tmask : Nat_big_num.num = replicate telem (regSize / esize) in
  (wmask, tmask)

(* encodeBitMasks: return Some (N,imms,immr) if exist such values that
                   decode to 'imm' for 'regSize' (32/64) bits datasize. Otherwise
                   return None. *)
let encodeBitMasks regSize (imm : Nat_big_num.num) =
  if Nat_big_num.equal imm (Nat_big_num.of_int 0) then None
  else if Nat_big_num.equal imm (Nat_big_num.pred (Nat_big_num.shift_left (Nat_big_num.of_int 1) regSize)) then None
  else

  let ror (n : Nat_big_num.num) (k : int) =
    let k = k mod regSize in
    if k = 0 then n else
    let d = Nat_big_num.extract_num n 0 k in
    Nat_big_num.bitwise_or
      (Nat_big_num.shift_left d (regSize-k))
      (Nat_big_num.shift_right n k) in

  let rec next b n =
    if Nat_big_num.extract_num n 0 1 = b then 0
    else 1 + next b (Nat_big_num.shift_right n 1) in

  let pref0 = next (Nat_big_num.of_int 1) imm in (* the length of 0s prefix of imm *)
  let (e,ones,rotate) =
    if pref0 = 0 then
      let pref1 = next (Nat_big_num.of_int 0) imm in (* the length of 1s prefix of imm *)
      let run0 = next (Nat_big_num.of_int 1) (ror imm pref1) in (* the length of the first 0s run *)
      let run1 = next (Nat_big_num.of_int 0) (ror imm (pref1 + run0)) in  (* the length of the first non-prefix 1s run *)
      (run0+run1, run1, run1-pref1)
    else
      let run1 = next (Nat_big_num.of_int 0) (ror imm pref0) in (* the length of the first 1s run *)
      let run0 = next (Nat_big_num.of_int 1) (ror imm (pref0 + run1)) in  (* the length of the first non-prefix 0s run *)
      (run0+run1, run1, run0+run1-pref0) in

  let (_N,imms,immr) =
    if e = 64 then (1, ones-1, rotate)
    else (0, (lnot (e*2 - 1)) lor (ones-1), rotate) in

  match decodeBitMasks regSize _N imms immr true with
  | (wmask,_) when Nat_big_num.equal wmask imm -> Some (_N,imms,immr)
  | _ -> None


