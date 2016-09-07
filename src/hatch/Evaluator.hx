

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
    test("(lambda () (quote (1 2 3)))");
    test("((lambda () (quote (1 2 3))))");    
    test("(define x 10)");
    test("x");
    test("(not x)");
    test('(define foo (lambda (x y) "Nothing"))');
    test('(foo 1 2)');
    test('(quote ())');
    test('(cons (quote a) (quote (1 2 3)))');
    test('(cons 10 30)');
    test('(if 3 "True" "False")');
    test('(if () "True" "False")');
    test("(quote ')");
    test("(not 4)");
    test("(list? ())");
    test("(list? (quote (1 2)))");
    test("(empty? ())");
    test("(empty? (quote (1 2 3)))");
    test("(++ 3 4)");
    test("(map (lambda (x) (++ x 1)) (quote (1 2 3)))");
    test("(define sum (lambda (l) (fold (lambda (acc v) (++ acc v)) 0 l)))");
    test("(sum (quote (1 2 3)))");
    test("(sum (map (lambda (x) (++ x 1)) (quote (1 2 3))))");
  }
  
  public static function init () {
    if (bindingStack == null) {
      bindingStack = [];
      addCoreBindings();
    }
  }

  private static function addCoreBindings() {
    var core : Bindings = new Map();
    bindingStack.unshift(core);

    evalR('(define map (lambda (f l) 
                       (if (empty? l) l
                           (cons (f (head l)) 
                                 (map f (tail l))))))');

    evalR('(define fold (lambda (f acc l)
                          (if (empty? l) acc
                              (fold f (f acc (head l)) (tail l)))))');
    
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
    // case [NilV, form]: {
    //   return FunctionV( function (expr : HatchValue) {
    // 	  return eval(form);
    // 	});
    // }
    default: throw "Error: malformed lambda expression";
    };
  }

  private static function bindSymbol (s, v) {
    var val = eval(v);
    bindingStack[0].set(s, val);
    return val;
  }

  private static function evalDefine (a :Array<HatchValue>) {
    if (a.length != 2) throw "Error: malformed define statement";
    return switch (a) {
    case [SymbolV(s), form]: bindSymbol( s, form);
    default: throw "Error: malformed define statement";
    }
  }

  private static function evalCons( a : Array<HatchValue>) {
    if (a.length != 2) throw "Error: cons called with wrong nubmer of arguments";
    var head = eval( a[0] );
    var tail = eval( a[1] );
    return switch (tail) {
      //    case NilV: ListV([head]);
    case ListV(l): {
      l.unshift( head );
      ListV(l);
    }
    default: ListV([head, tail]);
    };
  }

  private static function isEmpty (v : HatchValue) {
    return switch (v) {
    case ListV(a): a.length == 0;
    default: throw "Error: cannot check emptiness of non-list";
    };
  }

  private static function isTruthy( v :HatchValue) {
    return switch (v) {
    case BoolV(b): b;
    default: true;
    };
  }
  
  private static function evalIf ( a : Array<HatchValue> ) {
    if (a.length != 3) throw "Error: if syntax error. Try (if cond then else)";
    var cond = isTruthy( eval( a[0] )); //!isNil(eval( a[0] ));
    return if (cond) eval( a[1] ) else eval( a[2] );
  }

  private static function evalIsEmpty( a : Array<HatchValue> ) {
    if (a.length != 1) throw "Error: empty? called with wrong number of arguments";
    return if (isEmpty( eval(a[0]) )) BoolV(true) else BoolV(false);
  }

  private static function evalNot( a : Array<HatchValue> ) {
    if (a.length != 1) throw "Error: not called with wrong number of arguments";
    return if (isTruthy( eval( a[0] ))) BoolV(false) else BoolV(true);
  }

  private static function evalIsList ( a : Array<HatchValue> ) {
    if (a.length != 1) throw "Error: list? called with wrong number of arguments";
    return switch( eval(a[0]) ) {
    case ListV(_): BoolV(true);
      //    case NilV: BoolV(true);
    default: BoolV(false);
    };
  }

  private static function evalPlus (a : Array<HatchValue>) {
    if (a.length != 2) throw "Error: ++ called with wrong number of arguments";
    return switch( a.map(eval) ) {
    case [IntV(x), IntV(y)] : IntV(x + y);
    case [IntV(x), FloatV(y)] : FloatV(x + y);
    case [FloatV(x), IntV(y)] : FloatV(x + y);
    case [StringV(x), StringV(y)] : StringV('$x$y');
    default: throw "Error, ++ called with bad arguments";
    };
  }

  private static function evalHead ( a: Array<HatchValue> ) {
    if (a.length != 1) throw "error, head called with wrong number args";
    return switch( eval(a[0]) ) {
    case ListV(b) if (b.length > 0): b[0];
    default: throw 'Error: cannot return head of non-list ${a[0]}';
    };
  }

  private static function evalTail (a : Array<HatchValue>) {
    if (a.length != 1) throw "error";
    return switch(eval(a[0])) {
    case ListV(b) if (b.length > 0): ListV(b.slice(1));
    default: throw "no tail of non list";
    };
  }
  
  private static function evalList( a : Array<HatchValue>)  {
    if (a.length == 0) return ListV(a);

    return switch (a[0]) {
    case SymbolV('define'): evalDefine(a.slice(1));
    case SymbolV('lambda'): evalLambda(a.slice(1));
    case SymbolV('quote'): evalQuote( a.slice(1) );
    case SymbolV('cons'): evalCons( a.slice(1) );
    case SymbolV('empty?'): evalIsEmpty( a.slice(1) );
    case SymbolV('list?'): evalIsList( a.slice(1));
    case SymbolV('if'): evalIf( a.slice( 1 ));
    case SymbolV('not'): evalNot( a.slice( 1 ));
    case SymbolV('head'): evalHead( a.slice( 1 ));
    case SymbolV('tail') :evalTail( a.slice( 1 ));
    case SymbolV('++'): evalPlus( a.slice(1));
    default: switch( eval(a[0]) ) {
      case FunctionV(f): f( ListV( a.slice(1)));
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

  public static function evalR (s : String) {
    switch (Reader.read(s)) {
    case Left(e): throw 'Error: $e';
    case Right(exp): return eval(exp);
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