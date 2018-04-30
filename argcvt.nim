## ``argParse`` determines how string args are interpreted into native types.
## ``argHelp`` explains this interpretation to a command-line user.  Define new
## overloads in-scope of ``dispatch`` to override these or support more types.

from parseutils import parseBiggestInt, parseBiggestUInt, parseBiggestFloat
from strutils   import `%`, join, split, strip, toLowerAscii, cmpIgnoreStyle
from typetraits import `$`  # needed for $T
proc ERR*(x: varargs[string, `$`]) = stderr.write(x)

proc nimEscape*(s: string): string =
  ## Until strutils gets a nimStringEscape that is not deprecated
  result = newStringOfCap(s.len + 2 + s.len shr 2)
  result.add('"')
  for c in s: result.addEscapedChar(c)
  result.add('"')

type argcvtParams* = object ## \
  ## Abstraction of non-param-type arguments to `argParse` and `argHelp`.
  ## Per-use data, then per-parameter data, then per-command/global data.
  key*: string        ## key actually used for this option
  val*: string        ## value actually given by user
  sep*: string        ## separator actually used (including before '=' text)
  parNm*: string      ## long option key/parameter name
  parSh*: string      ## short key for this option key
  parCount*: int      ## count of times this parameter has been invoked
  parReq*: int        ## flag indicating parameter is mandatory
  Mand*: string       ## how a mandatory defaults is rendered in help
  Help*: string       ## the whole help string, for parse errors
  Delimit*: string    ## delimiting convention for `seq`, `set`, etc.
  shortNoVal*: ptr set[char]
  longNoVal*: ptr seq[string]

proc argKeys*(a: argcvtParams, argSep="="): string =
  ## `argKeys` generates the option keys column in help tables
  result = if len(a.parSh) > 0: "-$1$3, --$2$3" % [ a.parSh, a.parNm, argSep ]
           else            : "--" & a.parNm & argSep

proc argDf*(a: argcvtParams, dv: string): string =
  ## argDf is an argHelp space-saving utility proc to decide default column.
  (if a.parReq != 0: a.Mand else: dv)

# bool
proc argParse*(dst: var bool, dfl: bool, a: argcvtParams): bool =
  if len(a.val) > 0:
    case a.val.toLowerAscii  # Like `strutils.parseBool` but we also accept t&f
    of "t", "true" , "yes", "y", "1", "on" : dst = true
    of "f", "false", "no" , "n", "0", "off": dst = false
    else:
      ERR("Bool option \"$1\" non-boolean argument (\"$2\")\n$3" %
          [ a.key, a.val, a.Help ])
      return false
  else:               # No option arg => reverse of default (usually, ..
    dst = not dfl     #.. but not always this means false->true)
  return true

proc argHelp*(dfl: bool; a: argcvtParams): seq[string] =
  result = @[ a.argKeys(argSep=""), "bool", a.argDf($dfl) ]
  a.shortNoVal[].incl(a.parSh[0]) # bool can elide option arguments.
  a.longNoVal[].add(a.parNm)      # So, add to *NoVal.

# string
proc argParse*(dst: var string, dfl: string, a: argcvtParams): bool =
  if a.val == nil:
    ERR("Bad value nil for string param \"$1\"\n$2" % [ a.key, a.Help ])
    return false
  dst = a.val
  return true

proc argHelp*(dfl: string; a: argcvtParams): seq[string] =
  result = @[ a.argKeys, "string", a.argDf(nimEscape(dfl)) ]

# cstring
proc argParse*(dst: var cstring, dfl: cstring, a: argcvtParams): bool =
  if a.val == nil:
    ERR("Bad value nil for string param \"$1\"\n$2" % [ a.key, a.Help ])
    return false
  dst = a.val
  return true

proc argHelp*(dfl: cstring; a: argcvtParams): seq[string] =
  result = @[ a.argKeys, "string", a.argDf(nimEscape($dfl)) ]

# char
proc argParse*(dst: var char, dfl: char, a: argcvtParams): bool =
  if len(a.val) > 1:
    ERR("Bad value \"$1\" for single char param \"$2\"\n$3" %
        [ a.val, a.key, a.Help ])
    return false
  dst = a.val[0]
  return true

proc argHelp*(dfl: char; a: argcvtParams): seq[string] =
  result = @[ a.argKeys, "char", a.argDf(repr(dfl)) ]

# enums
proc argParse*[T: enum](dst: var T, dfl: T, a: argcvtParams): bool =
  var found = false
  for e in low(T)..high(T):
    if cmpIgnoreStyle(a.val, $e) == 0:
      dst = e
      found = true
      break
  if not found:
    var all = ""
    for e in low(T)..high(T): all.add($e & " ")
    all.add("\n\n")
    ERR("Bad enum value for option \"$1\". \"$2\" is not one of:\n  $3$4" %
        [ a.key, a.val, all, a.Help ])
    return false
  return true

proc argHelp*[T: enum](dfl: T; a: argcvtParams): seq[string] =
  result = @[ a.argKeys, "enum", $dfl ]

# various numeric types
template argParseHelpNum(WideT: untyped, parse: untyped, T: untyped): untyped =
  proc argParse*(dst: var T, dfl: T, a: argcvtParams): bool =
    var parsed: WideT
    let valstrip = strip(a.val)
    if a.val == nil or parse(valstrip, parsed) != len(valstrip):
      ERR("Bad value: \"$1\" for option \"$2\"; expecting $3\n$4" %
          [ (if a.val == nil: "nil" else: a.val), a.key, $T, a.Help ])
      return false
    dst = T(parsed)
    return true

  proc argHelp*(dfl: T, a: argcvtParams): seq[string] =
    result = @[ a.argKeys, $T, a.argDf($dfl) ]

argParseHelpNum(BiggestInt  , parseBiggestInt  , int    )  #ints
argParseHelpNum(BiggestInt  , parseBiggestInt  , int8   )
argParseHelpNum(BiggestInt  , parseBiggestInt  , int16  )
argParseHelpNum(BiggestInt  , parseBiggestInt  , int32  )
argParseHelpNum(BiggestInt  , parseBiggestInt  , int64  )
argParseHelpNum(BiggestUInt , parseBiggestUInt , uint   )  #uints
argParseHelpNum(BiggestUInt , parseBiggestUInt , uint8  )
argParseHelpNum(BiggestUInt , parseBiggestUInt , uint16 )
argParseHelpNum(BiggestUInt , parseBiggestUInt , uint32 )
argParseHelpNum(BiggestUInt , parseBiggestUInt , uint64 )
argParseHelpNum(BiggestFloat, parseBiggestFloat, float32)  #floats
argParseHelpNum(BiggestFloat, parseBiggestFloat, float  )
#argParseHelpNum(BiggestFloat, parseBiggestFloat, float64) #only a type alias

## **PARSING AGGREGATES (seq, set, ..) FOR NON-OS-TOKENIZED OPTION VALUES**
##
## This module also defines argParse/argHelp pairs for ``seq[T]`` with flexible
## delimiting rules decided by `Delimit`.  A value of ``"<D>"`` indicates
## delimiter-prefixed-values (DPSV) while a square-bracket character class like
## ``"[:,]"`` indicates a set of chars.  Anything else indicates that the whole
## string is the delimiter.  DPSV format looks like
## ``<DELIM-CHAR><COMPONENT><DELIM-CHAR><COMPONENT>..`` E.g., for CSV the user
## enters ``",Howdy,Neighbor"``.
##
## To allow easy appending to, removing from, and resetting existing sequence
## values, ``'+'``, ``'-'``, ``'='`` are recognized as special prefix chars.
## So, e.g., ``-o=,1,2,3 -o=+,4,5, -o=-3`` is equivalent to ``-o=,1,2,4,5``.
## Meanwhile, ``-o,1,2 -o:=-3 -o=++4`` makes ``o``'s value ``["-3", "+4"]``.
## It is not considered an error to try to delete a non-existent value.
##
## ``argParseHelpSeq(myType)`` will instantiate ``argParse`` and ``argHelp``
## for ``seq[myType]`` if you like any of the default delimiting schemes.
##
## The delimiting system is somewhat extensible.  If you have a new style or
## would like to override my usage messages then you can define your own
## ``argAggSplit`` and ``argAggHelp`` anywhere before ``dispatchGen``.
## The optional ``+-=`` syntax will remain available.

proc argAggSplit*[T](src: string, delim: string, a: argcvtParams): seq[T] =
  var toks: seq[string]
  if delim == "<D>":                      # DELIMITER-PREFIXED Sep-Vals
    toks = src[1..^1].split(delim[0])     # E.g.: ",hello,world"
  elif delim[0] == '[' and delim[^1] == ']':
    var cclass: set[char] = {}            # is there no toSet?
    for c in delim[1..^2]: cclass.incl(c)
    toks = src[1..^1].split(cclass)
  else:
    toks = src.split(delim)
  var parsed, default: T
  result = @[]
  var acp = a
  for tok in toks:
    acp.val = tok
    if not argParse(parsed, default, acp):
      result.setLen(0)
      return
    result.add(parsed)

proc argAggHelp*(sd: string, Dfl: seq[string]; typ, dfl: var string) =
  if sd == "<D>":
    typ = "DPSV[" & typ & "]"
    dfl = if Dfl.len > 0: sd & Dfl.join(sd) else: "EMPTY"
  else:
    typ = sd & "SV[" & typ & "]"
    dfl = if Dfl.len > 0: Dfl.join(sd) else: "EMPTY"

## sets
proc argParse*[T](dst: var set[T], dfl: set[T], a: argcvtParams): bool =
  if a.val == nil:
    ERR("Bad value nil for DSV param \"$1\"\n$2" % [ a.key, a.Help ])
    return false
  let parsed = argAggSplit[T](a.val, a.Delimit, a)
  if parsed.len == 0: return false
  case a.sep[0]                     # char on command line before [=:]
  of '+':                           # Append Mode
    for e in parsed: dst.incl(e)
  of '-':                           # Delete mode
    for e in parsed: dst.excl(e)
  else:                             # Assign Mode
    dst = {}
    for e in parsed: dst.incl(e)
  return true

proc argHelp*[T](dfl: set[T], a: argcvtParams): seq[string]=
  var typ = $T; var df: string
  var dflSeq: seq[string] = @[ ]
  for d in dfl: dflSeq.add($d)
  argAggHelp(a.Delimit, dflSeq, typ, df)
  result = @[ a.argKeys, typ, a.argDf(df) ]

## seqs                               XXX Add a '^' prepend mode?
proc argParse*[T](dst: var seq[T], dfl: seq[T], a: argcvtParams): bool =
  if a.val == nil:
    ERR("Bad value nil for DSV param \"$1\"\n$2" % [ a.key, a.Help ])
    return false
  let parsed = argAggSplit[T](a.val, a.Delimit, a)
  if parsed.len == 0: return false
  case a.sep[0]                     # char on command line before [=:]
  of '+':                           # Append Mode
    if dst == nil: dst = @[]
    for e in parsed: dst.add(e)
  of '-':                           # Delete mode
    if dst == nil: dst = @[]
    for i, e in dst:
      if e in parsed: dst.delete(i)    # Quadratic algo, but preserves order
  else:                             # Assign Mode
    dst = @[]
    for e in parsed: dst.add(e)
  return true

proc argHelp*[T](dfl: seq[T], a: argcvtParams): seq[string]=
  var typ = $T; var df: string
  var dflSeq: seq[string] = @[ ]
  for d in dfl: dflSeq.add($d)
  argAggHelp(a.Delimit, dflSeq, typ, df)
  result = @[ a.argKeys, typ, a.argDf(df) ]
