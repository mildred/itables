import std/strformat
import std/json
import std/strutils

type
  ValueType* = enum
    NumberType = "number"
    TextType = "text"
    BoolType = "bool"
    NullType = "null"
    FlexibleType = "flexible"
    ErrorType = "error"

  Value* = ref object
    case type*: ValueType
    of NumberType:
      valueNumber*: float
    of TextType:
      valueText*: string
    of BoolType:
      valueBool*: bool
    of NullType:
      discard
    of FlexibleType:
      valueFlexible*: string
    of ErrorType:
      valueError*: string

func `$`*(v: Value): string =
  if v.isNil: return ""

  case v.type
  of NumberType:
    result = $v.valueNumber
  of TextType:
    result = v.valueText
  of BoolType:
    result = if v.valueBool: "true" else: "false"
  of NullType:
    result = "null"
  of FlexibleType:
    result = v.valueFlexible
  of ErrorType:
    result = &"#!{v.valueError}"

func asJSON*(v: Value): JsonNode =
  case v.type
  of NumberType:
    result = %v.valueNumber
  of TextType:
    result = %v.valueText
  of BoolType:
    result = %v.valueBool
  of NullType:
    result = newJNull()
  of FlexibleType:
    result = %v.valueFlexible
  of ErrorType:
    result = %*{ "error": v.valueError }

func toJSON*(v: Value): string =
  $v.asJSON()

proc fromStrings*(typ: string, json_str: string): Value =
  #echo &"Value.fromStrings({typ}, {json_str})"
  if typ == "": return nil

  let json = parseJSON(json_str)
  let t = parseEnum[ValueType](typ)
  case t
  of NumberType:
    result = Value(type: t, valueNumber: json.getFloat())
  of TextType:
    result = Value(type: t, valueText: json.getStr())
  of BoolType:
    result = Value(type: t, valueBool: json.getBool())
  of NullType:
    result = Value(type: t)
  of FlexibleType:
    result = Value(type: t, valueFlexible: json.getStr())
  of ErrorType:
    result = Value(type: t, valueError: json["error"].getStr())
