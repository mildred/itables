import std/strformat
import std/strutils
import std/unicode

import formula

type
  FormulaReader = object
    formula: string
    idx: int

func isEOF(reader: FormulaReader): bool = reader.idx >= reader.formula.len

func rune(s: string): Rune = s.runeAt(0)
func rune(c: char): Rune = ("" & c).runeAt(0)

func isDigit(r: Rune): bool =
  result = (rune('0') <=% r) and (r <=% rune('9'))

func isNumberRune(r: Rune): bool =
  result = r.isDigit() or r == rune('.') or r == rune(',')

func isAlphaNumeric(r: Rune): bool =
  result = r.isDigit() or r.isAlpha()

proc readRune(r: var FormulaReader): Rune =
  if r.isEOF(): return Rune(0)
  r.formula.fastRuneAt(r.idx, result, true)

func peekRune(r: FormulaReader): Rune =
  if r.isEOF(): return Rune(0)
  r.formula.fastRuneAt(r.idx, result, false)

proc skipSpaces(r: var FormulaReader) =
  while r.peekRune().isWhiteSpace():
    discard r.readRune()

proc readIdentifier(r: var FormulaReader): string =
  result = ""
  while r.peekRune().isAlphaNumeric():
    result = result & ($r.readRune())

proc readInteger(r: var FormulaReader): int =
  var res = ""
  while r.peekRune().isDigit():
    res = res & ($r.readRune())
  result = parseInt(res)

proc readNumber(r: var FormulaReader): float =
  var res = ""
  while r.peekRune().isNumberRune():
    var c = $r.readRune()
    if c == ",": c = "."
    res = res & c
  result = parseFloat(res)

proc readExpr(r: var FormulaReader): FormulaExpr

proc readBaseExpr(r: var FormulaReader): FormulaExpr =
  if r.isEOF():
    return nil

  r.skipSpaces()
  let c = r.peekRune()
  if c == rune('$'):
    discard r.readRune()
    let col = r.readInteger()
    discard r.readRune() # should be "."
    let row = r.readInteger()
    return FormulaExpr(
      kind: CellRefKind,
      col: col,
      row: row)
  if c == rune('-'):
    return FormulaExpr(
      kind: ApplyKind,
      functionName: "-",
      arguments: @[r.readExpr()])
  elif c.isDigit():
    return FormulaExpr(
      kind: NumberKind,
      valueNumber: r.readNumber())
  elif c.isAlpha():
    let identifier = r.readIdentifier()
    result.kind = ApplyKind
    result.functionName = identifier
    r.skipSpaces()
    if r.peekRune() == rune('('):
      discard r.readRune()
      while not r.isEOF():
        result.arguments.add(r.readExpr())
        r.skipSpaces()
        case $r.readRune()
        of ")":
          break
        of ";":
          discard
        else:
          break

proc readExprOp1(r: var FormulaReader): FormulaExpr =
  result = r.readBaseExpr()
  while not r.isEOF():
    r.skipSpaces()
    let op = $r.peekRune()
    case op
    of "*", "/":
      result = FormulaExpr(
        kind: ApplyKind,
        functionName: op,
        arguments: @[result, r.readBaseExpr()])
    else:
      break

proc readExprOp2(r: var FormulaReader): FormulaExpr =
  result = r.readExprOp1()
  while not r.isEOF():
    r.skipSpaces()
    let op = $r.peekRune()
    case op
    of "+", "-":
      result = FormulaExpr(
        kind: ApplyKind,
        functionName: op,
        arguments: @[result, r.readExprOp1()])
    else:
      break

proc readExpr(r: var FormulaReader): FormulaExpr =
  result = r.readExprOp2()

proc parse*(formula: string): Formula =
  var reader = FormulaReader(formula: formula, idx: 0)

  let c = reader.readRune()
  if c != rune('='):
    result = Formula(code: formula, expr: FormulaExpr(
      kind: AnyKind,
      valueAny: formula))
  else:
    echo &"Formula.parse({formula})"
    result = Formula(code: formula, expr: reader.readExpr())


