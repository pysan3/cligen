proc demo(alpha=1, beta=2.0, verb=false, item="", files: seq[string]): int =
  ## demo entry point with varied, meaningless parameters.
  echo "alpha:", alpha, " beta:", beta, " verb:", verb, " item:", repr(item)
  for i, f in files: echo "args[", i, "]: ", repr(f)
  return 42

proc show(gamma=1, iota=2.0, verb=false, paths: seq[string]): int =
  ## show entry point with varied, meaningless parameters.
  echo "gamma:", gamma, " iota:", iota, " verb:", verb
  for i, p in paths: echo "args[", i, "]: ", repr(p)
  return 42

when isMainModule:
  import cligen, os

  dispatchGen(demo, doc="  This does the demo.", help = {
              "alpha" : "This is a very long parameter help string which " &
                        "ordinarily should be auto-wrapped by alignTable " &
                        "into a multi-line format unless you have eagle " &
                        "eyes, a gigantic monitor, or maybe a little bit of " &
                        "both. :-)",
              "beta" : "This is more modest, but might still wrap around " &
                       "once or twice or so.",
              "verb" : "on=chatty, off=quiet. 'Nuff said." })

  dispatchGen(show, doc="  This shows me something.")

  proc multi(beta=1, subcmd: seq[string]): int =
    echo "globalbeta:", beta
    let arg0 = if subcmd.len > 0: subcmd[0] else: "help"
    case arg0
    of "demo": quit(dispatch_demo(cmdline = subcmd[1..^1]))
    of "show": quit(dispatch_show(cmdline = subcmd[1..^1]))
    of "help":
        echo "Usage:\n  SemiAutoMulti demo|show|help [subcommand-args]\n"
        echo "    This is a multiple-dispatch cmd.  Subcommand syntax:\n"
        # Don't have multiple Usage: stuff in there.  Also indent subcmd help.
        let use = "SemiAutoMulti [globalOpts] $command $args\n$doc\nOptions:\n$options"
        discard dispatch_demo(cmdline = @[ "--help" ], prefix="    ", usage=use)
        discard dispatch_show(cmdline = @[ "--help" ], prefix="    ", usage=use)
        quit(0)
    else: echo "unknown subcommand: ", subcmd
    quit(1)

  dispatch(multi, stopWords = @[ "demo", "show", "help" ])
