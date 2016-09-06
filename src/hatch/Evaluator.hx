

import haxe.ds.Option;
import Reader;
using Lambda;

typedef Bindings = Map<String,Dynamic>;

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
    test("(+ 1 2)");
    test('(+ "abcd" "efgh")');
    test('(* 3 4)');
    test('(/ 3 4.0)');
	 

  }
  
  public static function init () {
    if (bindingStack == null) {
      bindingStack = [];
      addCoreBindings();
    }
  }

  private static function addCoreBindings() {
    var bindings : Bindings = new Map();
    bindings.set('+', function (x, y) {return x + y;});
    bindings.set('-', function (x, y) {return x - y;});
    bindings.set('*', function (x, y) {return x * y;});
    bindings.set('/', function (x, y) {return x / y;});
    bindings.set('map', function (f, a) {
	return eval(a).map(eval(f));
      });
    bindingStack.unshift( bindings );
  }

  // move up the statck looking for the somthing bound
  private static function lookupBinding (s : String) : Option<Dynamic> {
    var spec = s;
    for (bindings in bindingStack)
      if (bindings.exists( spec )) return Some(bindings.get( spec ));
    return None;
  }


  private static function applyQuote( a : Array<Term> ) : Term {
    if (a.length == 1) {
      return a[0];
    }
    throw "error, quote form takes 1 argument";
  }
  
  private static function evalList( a : Array<Term>)  {
    if (a.length == 0) return eval(NilT);

    switch (a[0]) {
    case SymbolT('quote'): return applyQuote( a.slice(1) );
    case SymbolT(f): switch (lookupBinding(f)) {
      case None: throw 'no callable symbol $f';
      case Some(value): {
	var value = value;
	if (Reflect.isFunction( value )) {
	  try {
	    return Reflect.callMethod( null, value, [for (x in a.slice(1)) eval(x)]);
	  } catch (e:Dynamic) {
	    throw '$f bound to $value cannot be applied to arguments provided';
	  }
	} else {
	  throw '$f is not callable';
	}
      }
      }
    default: throw 'error evaluating form ${a[0]}';
    }
  }

  private static function evalVar (v) {
    switch ( lookupBinding( v) ) {
    case None: throw 'unbound variable $v';
    case Some(v): return v;
    }
  }
  
  public static function eval (exp : Term) : Dynamic {
    return switch (exp) {
    case IntT(i): i;
    case FloatT(f): f;
    case StringT(s): s;
    case NilT: null;
      //    case VarT(v): evalVar(v);
    case BlankT: null;
    case SymbolT(a): evalVar(a);
    case ListT(a): evalList( a );
    };
  }

					     
					     
  
}