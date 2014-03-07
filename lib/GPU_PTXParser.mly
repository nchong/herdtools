/*********************************************************************/
/*                        Memevents                                  */
/*                                                                   */
/* Jade Alglave, Luc Maranget, INRIA Paris-Rocquencourt, France.     */
/* Susmit Sarkar, Peter Sewell, University of Cambridge, UK.         */
/*                                                                   */
/*  Copyright 2010 Institut National de Recherche en Informatique et */
/*  en Automatique and the authors. All rights reserved.             */
/*  This file is distributed  under the terms of the Lesser GNU      */
/*  General Public License.                                          */
/*********************************************************************/

%{
module GPU_PTX = GPU_PTXBase
open GPU_PTX
%}

%token EOF
%token <GPU_PTXBase.reg> ARCH_REG
%token <GPU_PTXBase.op_type> S32 B64 B32 U64 U32
%token <GPU_PTXBase.state_space> GLOB SH
%token <GPU_PTXBase.cache_op> CA CG CV WB WT
%token <GPU_PTXBase.bar_scope> CTA GL SYS
%token <int> NUM
%token <string> NAME
%token <int> PROC

%token SEMI COMMA PIPE COLON LPAR RPAR LBRAC RBRAC LBRACE RBRACE

%token <int> CRK

/* Instruction tokens */
%token ST LD MEMBAR MOV ADD AND CVT VOL



%type <int list * (GPU_PTXBase.pseudo) list list> main 
%start  main

%nonassoc SEMI
%%

main:
| semi_opt proc_list iol_list EOF { $2,$3 }

semi_opt:
| { () }
| SEMI { () }

proc_list:
| PROC SEMI
    {[$1]}

| PROC PIPE proc_list  { $1::$3 }

iol_list :
|  instr_option_list SEMI
    {[$1]}
|  instr_option_list SEMI iol_list {$1::$3}

instr_option_list :
  | instr_option
      {[$1]}
  | instr_option PIPE instr_option_list 
      {$1::$3}

instr_option :
|            { Nop }
| instr      { Instruction $1}

instr:
  | ST prefix ins_type cop LBRAC reg RBRAC COMMA reg
    { Pst ($6, $9, $2, $4, $3) }

  | LD prefix ins_type cop reg COMMA LBRAC reg RBRAC
    { Pld ($5, $8, $2, $4, $3) }

  | ST VOL prefix ins_type LBRAC reg RBRAC COMMA reg
    { Pstvol ($6, $9, $3, $4) }

  | LD VOL prefix ins_type reg COMMA LBRAC reg RBRAC
    { Pldvol ($5, $8, $3, $4) }

  | MOV ins_type reg COMMA ins_op
    { Pmov ($3,$5,$2) }

  | ADD ins_type reg COMMA ins_op COMMA ins_op
    { Padd ($3,$5,$7,$2) }

  | AND ins_type reg COMMA ins_op COMMA ins_op
    { Pand ($3,$5,$7,$2) }

  | CVT ins_type ins_type reg COMMA reg
    { Pcvt ($4,$6,$2,$3) }

  | MEMBAR bscope
    { Pmembar ($2) }

ins_op:
| reg {Reg $1}
| NUM {Im $1}

bscope:
| CTA {$1}
| GL  {$1}
| SYS {$1}

ins_type:
| S32 {$1}
| B64 {$1}
| B32 {$1}
| U64 {$1}
| U32 {$1}

prefix:
| {NOMP}
| GLOB {$1}
| SH {$1}

cop:
| {NCOP}
| CA {$1}
| CG {$1}
| CV {$1}
| WB {$1}
| WT {$1}
 
reg:
| ARCH_REG { $1 }