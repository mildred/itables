import std/strutils

import values
import parseutils

type
  Formula* = ref object
    code*: string
    expr*: FormulaExpr

  FormulaExprKind* = enum
    CellRefKind
    NumberKind
    AnyKind
    TextKind
    BoolKind
    NullKind
    ApplyKind

  FormulaExpr* = ref object
    case kind*: FormulaExprKind
    of CellRefKind:
      col*: int
      row*: int
    of NumberKind:
      valueNumber*: float
    of AnyKind:
      valueAny*: string
    of TextKind:
      valueText*: string
    of BoolKind:
      valueBool*: bool
    of NullKind:
      discard
    of ApplyKind:
      functionName*: string
      arguments*: seq[FormulaExpr]

proc walk*(f: FormulaExpr, walker: proc(expr: FormulaExpr)) =
  walker(f)
  case f.kind
  of ApplyKind:
    for arg in f.arguments:
      f.walk(walker)
  else:
    discard

proc get_deps*(f: FormulaExpr): seq[tuple[col,row: int]] =
  var res: seq[tuple[col,row: int]] 
  f.walk do(f: FormulaExpr):
    if f.kind == CellRefKind:
      res.add((col: f.col, row: f.row))
  result = res

proc compute*(f: FormulaExpr, cellValue: proc(col, row: int): Value): Value =
  case f.kind
  of CellRefKind:
    result = cellValue(f.col, f.row)
  of NumberKind:
    result = Value(type: NumberType, valueNumber: f.valueNumber)
  of AnyKind:
    let str = f.valueAny.replace(",", ".")
    var fl: float
    let len = str.parseFloat(fl)
    if len == str.len:
      result = Value(type: NumberType, valueNumber: fl)
    else:
      result = Value(type: TextType, valueText: f.valueAny)
  of TextKind:
    result = Value(type: TextType, valueText: f.valueText)
  of BoolKind:
    result = Value(type: BoolType, valueBool: f.valueBool)
  of NullKind:
    result = Value(type: NullType)
  of ApplyKind:
    result = Value(type: ErrorType, valueError: "WIP")
