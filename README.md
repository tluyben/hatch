
HATCH
=========

*A lisp interoperable with Haxe*

The `hatch` dialect of lisp is intended to be a scripting langauge for
your haxe and openfl projects.  That is, you can *expose* Haxe objects
to the *hatch system* and then code to your heart's content in hatch.

The hatch language itself is a lisp dialect with dynamic scope and a
few special conventions.  It is a _work-in-progress_ and should remain
so for some time.  The hatch parser is extremely simple and makes use
of the [farcek](https://github.com/asciiascetic/farcek) monadic
parser-combinator library.  

Using
-------

You can use hatch in a number of ways. 

1. As a stand-alone command line REPL for playing with the language.
2. Embedded in another project

Either way the `hatch.REPL` module is what you're interested in.

One **caveat**: If you are compliling for a dynamic target (like
python, js, or neko) you must include the `-dce no` switch IF you want
to instantiate regular haxe objects from within the hatch environment.
Otherwise you should (probably) not include the switch. More about this elsewhere.  

### Stand-Alone REPL for playing

I've just given a `main` to REPL in the case you want to play. After
cloning this repository, do the following

    cd hatch/src
    haxe -main hatch.REPL -lib farcek -dce no -neko repl.n   # or -python or whatever
    neko repl.n
    

At this point, you can do lisp stuff. See the
[manual](not-yet-written) for more info, but here is a copy-and-pasted
shell session:

**NOTE: THIS IS OUT OF DATE, HATCH IS UNDER CONSTRUCTION**

``` scheme
;;  _           _       _        __     __ 
;; | |__   __ _| |_ ___| |__    / /     \ \ 
;; | '_ \ / _` | __/ __| '_ \  / /       \ \
;; | | | | (_| | || (__| | | | \ \   _   / /
;; |_| |_|\__,_|\__\___|_| |_|  \_\ (_) /_/ 

Version 0.0.3

> (map ($ + 1) (list 1 2 3 4))
(2 3 4 5)

> (filter (<> ($ = 1) (-> (x) (% x 2))) (list 1 2 3 4))
(1 3)

> (define is-odd (<> ($ = 1) (-> (x) (% x 2))))
#<function>

> (filter is-odd (list 1 2 3 4))
(1 3)

> (define is-even (<> not is-odd))
#<function>

> (filter is-even (list 1 2 3 4))
(2 4)

> (define apply-4 (<$ 4))
#<function>

> (map (<$ 4) (list is-even is-odd))
(#t #f)

> (apply and (map (<$ 4) (list is-even is-odd)))
#f

> (. haxe.Http.requestUrl "http://asciiascetic.github.io/projects")
"<html>
<head><title>301 Moved Permanently</title></head>
<body bgcolor="white">
<center><h1>301 Moved Permanently</h1></center>
<hr><center>nginx</center>
</body>
</html>
"	

> (define PEOPLE (. haxe.ds.StringMap))
  {}

> (define mk-person (lambda (name age job) (list (quote person) name age job)))
  #<function>

> (! 1 (list 44 55 66))
  55

> (define person-name ($ ! 1))
  #<function>

> (person-name (mk-person "colin" 34 "pro nobody"))
  "colin"

> (define store-person (lambda (name age job) (. set PEOPLE name (mk-person name age job))))
  #<function>

> (store-person "colin" 34 "Senior Code Frother")
  ()

> (define get-person (lambda (name) (. get PEOPLE name)))
  #<function>

> (get-person "colin")
  ("person" "colin" 34 "Senior Code Frother")

> (person-name (get-person "colin"))
  "colin"

```

### Embedding In Projects

If you want to do scripting of your haxe projects while they run there
are a few things to consider first. 

1. For which target are you compiling?
2. Which Haxe modules do you intend directly access from within your
   hatch code?
3. Which instantiated Haxe objects do you intend to expose to hatch?
   
When dealing with item 1, just pay mind to the above mentioned caveat
about the `-dce no` switch.

For 2, you need to explicitly import each of the modules you want to
use into the project.  Preferably into the module that calls
`hatch.REPL.init()`.

And for 3, any object that you want to make accessible in the hatch
environment (that is, any object that was not created from within
hatch itself), must be *exposed*.  E.g. `hatch.REPL.expose('canvas',
myCanvas)` will bind the object `myCanvas` to the top-level symbol
`canvas` in the hatch enviroment.

To actually pass hatch expressions into hatch from the outside
(i.e. to build your own custom REPL that is right for your project),
use the `hatch.REPL.repl(s : String) : String` static method.

    hatch.REPL.repl("(+ 1 2 3 4)"); // returns 10


The Future
--------------


There is much to be done. A non-exhaustive list of features to come:

1. A hatch REPL for interactively playing with your openfl projects
   while they are running (already in progress).
2. A more sophisticated command line hatch REPL, with history, and
   help functions.
3. Support for docstrings in the `define` statement.
4. An API on top of openfl for doing graphical programming in hatch itself.
5. Support for comments and .hatch sourcecode files.


Disclaimer
-----------

This is mega-ultra-alpha version stuff here. 
