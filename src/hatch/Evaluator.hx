

import haxe.ds.Option;
import Reader;
using Lambda;

typedef Bindings = Map<String,HatchValue>;



class Evaluator {


  private static var bindingStack : Array<Bindings>;
  
  public static function main () {
    Reader.init();
    init();
    var test = function (s) {
      switch (Reader.read(s)) {
      case Left(e) : trace(e);
      case Right(v): trace(eval(v));
      }
    };

    test("()");
    test("33");
    test("44.32");
    test('"hello there"');
    test("(quote (1 2 3))");
    test("(lambda (x) x)");
    test("((lambda (x) x) 2)");

  }
  
  public static function init () {
    if (bindingStack == null) {
      bindingStack = [];
      addCoreBindings();
    }
  }

  private static function addCoreBindings() {
  }

  // move up the statck looking for the somthing bound
  private static function lookupBinding (s : String) : Option<HatchValue> {
    var spec = s;
    for (bindings in bindingStack)
      if (bindings.exists( spec )) return Some(bindings.get( spec ));
    return None;
  }


  private static function evalQuote( a : Array<HatchValue> ) {
    if (a.length == 1) return a[0];
    throw "error, quote form takes 1 argument";
  }
  
  private static function evalSymbol( s : String, args : Array<HatchValue>) {
    switch (lookupBinding( s )) {
    case Some(FunctionV(f)) : f(ListV(args));
    default: throw 'Error: cannot eval symbol $s';
    }
  }

  private static function allSymbols (vars : Array<HatchValue>) {
    for (v in vars) switch (v) {
      case SymbolV(_): 'no_op';
      default: return false;
      }
    return true;
  }

  private static function symbolsToNames (vars : Array<HatchValue>) {
    // the default case should never happen, but be warned...
    return [for (v in vars) switch (v) {case SymbolV(s): s; default: '';}];
  }
  
  private static function introduceBindings (names: Array<String>, vals: Array<HatchValue>) {
    var bindings : Bindings = new Map();
    trace('binding $names to $vals');
    for (i in 0...names.length) bindings.set( names[i], eval(vals[i]));
    bindingStack.unshift( bindings );
  }

  private static function popBindings () {
    bindingStack.shift();
  }
  
  // (lambda (a1 a2) form1 form1 form2) 
  private static function evalLambda( a : Array<HatchValue> ) {
    if (a.length != 2) throw "Error: malformed lambda expression";
    return switch (a) {
    case [ListV(args), form] if ( allSymbols( args ) ):  {
	var names = symbolsToNames(args);
	var f = function (expr : HatchValue) {
	  trace('in f, expr = $expr');
	  switch (expr) {
	  case ListV(exprs): {
	    // add a check here that names.length == exprs.length
	    introduceBindings( names, exprs);
	    var v = eval( form );
	    popBindings();
	    return v;
	  }
	  default: throw "OH NO, SOMEHOW THIS FUNCTION WAS CALLED INCORRECTLY";
	  }
	};
	return FunctionV(f);	  
      }
    default: throw "Error: malformed lambda expression";
    };
  }
  
  private static function evalList( a : Array<HatchValue>)  {
    if (a.length == 0) return eval(NilV);

    return switch (a[0]) {
    case SymbolV('lambda'): evalLambda(a.slice(1));
    case SymbolV('quote'): evalQuote( a.slice(1) );
    default: switch( eval(a[0]) ) {
      case FunctionV(f): {
	trace('calling function $f with ${ListV(a.slice(1))}');
	f( ListV( a.slice(1)));
      }
      default: throw 'Error: cannot eval $a as given';
      };
    };
  }

  private static function evalVar (v:String) {
    switch ( lookupBinding( v) ) {
    case None: throw 'unbound variable $v';
    case Some(v): return v;
    }
  }
  
  public static function eval (exp : HatchValue) : HatchValue {
    return switch (exp) {
    case SymbolV(a): evalVar(a);
    case ListV(a): evalList( a );
    default: exp;
    };
  }

					     
					     
  
}