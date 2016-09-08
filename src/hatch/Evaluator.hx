

import haxe.ds.Option;
import Reader;
import HatchValue.HatchValue;
import BindingStack.Bindings;
using Lambda;

class Evaluator {

  private static var coreBindings : BindingStack;
  
  public static function main () {
    Reader.init();
    init();
    var test = function (s) {
      switch (Reader.read(s)) {
      case Left(e) : trace(e);
      case Right(v): trace(eval(v, coreBindings));
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
    if (coreBindings == null) {
      addCoreBindings();
    }
  }

 public static function eval (exp : HatchValue, ?bindings : BindingStack = null) : HatchValue {
   var bs = if (bindings == null) coreBindings else bindings;
    return switch (exp) {
    case SymbolV(a): evalVar(a, bs);
    case ListV(a): evalList( a , bs);
    default: exp;
    };
  }
  
  private static function wrapEval (f : Array<HatchValue> -> BindingStack -> HatchValue) {
    var hf = function (hv : HatchValue, bs : BindingStack) {
      return switch (hv) {
      case ListV(l): f(l, bs);
      default: throw("Error: something horrible has happened :( ");
      };
    };
    return FunctionV(hf);
  }

      
  private static function addCoreBindings() {
    var core : Bindings = new Map();
    coreBindings = new BindingStack([core]);

    core.set('quote', wrapEval(evalQuote));
    core.set('cons', wrapEval( evalCons));
    core.set('empty?',  wrapEval(evalIsEmpty));
    core.set('list?',  wrapEval(evalIsList));
    core.set('not', wrapEval(evalNot));
    core.set('head', wrapEval(evalHead));
    core.set('tail', wrapEval(evalTail));
    core.set('++', wrapEval(evalPlus));
    core.set('--', wrapEval(evalMinus));
    core.set('!', wrapEval(evalNth));

    // core.set('eval', FunctionV(function (exp) {
	  
    // 	});
    
    evalR('(define map (lambda (f l) 
                       (if (empty? l) l
                           (cons (f (head l)) 
                                 (map f (tail l))))))', coreBindings);

    evalR('(define fold (lambda (f acc l)
                          (if (empty? l) acc
                              (fold f (f (head l) acc) (tail l)))))', coreBindings);

    evalR('(define reverse (lambda ( l ) (fold cons () l)))', coreBindings);
    evalR('(define length (lambda ( l ) (fold (lambda (ignore acc) (++ 1 acc)) 0 l)))', coreBindings);


    
  }

  private static function evalQuote( a : Array<HatchValue>, ignore : BindingStack ) {
    if (a.length == 1) return a[0];
    throw "error, quote form takes 1 argument";
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
  
  private static function introduceBindings (names: Array<String>,
					     vals: Array<HatchValue>,
					     bs : BindingStack) {
    var bindings : Bindings = new Map();
    for (i in 0...names.length) bindings.set( names[i], eval( vals[i], bs));
    return bs.newScope( bindings );
  }

  private static function evalLambda( a : Array<HatchValue> , defineScope : BindingStack) {
    if (a.length != 2) throw "Error: malformed lambda expression";
    return switch (a) {
    case [ListV(args), form] if ( allSymbols( args ) ):  {
	var names = symbolsToNames(args);
	var f = function (expr : HatchValue, callingScope : BindingStack ) {
	  switch (expr) {
	  case ListV(exprs) if (names.length == exprs.length): {
	    var argumentScope = introduceBindings( names, exprs, callingScope);
	    var thisScope = argumentScope.prependTo( defineScope );
	    return eval( form , thisScope);
	  }
	  default: throw "OH NO, SOMEHOW THIS FUNCTION WAS CALLED INCORRECTLY";
	  }
	};
	return FunctionV(f);	  
      }
    default: throw "Error: malformed lambda expression";
    };
  }

  private static function evalDefine (a :Array<HatchValue>, bs : BindingStack) {
    if (a.length != 2) throw "Error: malformed define statement";
    return switch (a) {
    case [SymbolV(s), form]: bs.bindSymbol( s, eval(form, bs) );
    default: throw "Error: malformed define statement";
    }
  }

  private static function evalCons( a : Array<HatchValue>, bs : BindingStack ) {
    if (a.length != 2) throw "Error: cons called with wrong nubmer of arguments";
    var head = eval( a[0], bs );
    var tail = eval( a[1], bs );
    return switch (tail) {
    case ListV(l): {
      var l2 = l.copy();
      l2.unshift( head );
      ListV(l2);
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
  
  private static function evalIf ( a : Array<HatchValue> , bs : BindingStack ) {
    if (a.length != 3) throw "Error: if syntax error. Try (if cond then else)";
    var cond = isTruthy( eval( a[0] , bs)); 
    return if (cond) eval( a[1] , bs ) else eval( a[2], bs );
  }

  private static function evalIsEmpty( a : Array<HatchValue>, bs : BindingStack ) {
    if (a.length != 1) throw "Error: empty? called with wrong number of arguments";
    return if (isEmpty( eval(a[0], bs ))) BoolV(true) else BoolV(false);
  }

  private static function evalNot( a : Array<HatchValue>, bs : BindingStack ) {
    if (a.length != 1) throw "Error: not called with wrong number of arguments";
    return if (isTruthy( eval( a[0] , bs))) BoolV(false) else BoolV(true);
  }

  private static function evalIsList ( a : Array<HatchValue> , bs : BindingStack ) {
    if (a.length != 1) throw "Error: list? called with wrong number of arguments";
    return switch( eval(a[0], bs )) {
    case ListV(_): BoolV(true);
      //    case NilV: BoolV(true);
    default: BoolV(false);
    };
  }

  private static function evalPlus (a : Array<HatchValue>, bs : BindingStack) {
    if (a.length != 2) throw "Error: ++ called with wrong number of arguments";
    return switch( a.map( eval.bind( _, bs ) ) ) {
    case [IntV(x), IntV(y)] : IntV(x + y);
    case [IntV(x), FloatV(y)] : FloatV(x + y);
    case [FloatV(x), IntV(y)] : FloatV(x + y);
    case [StringV(x), StringV(y)] : StringV('$x$y');
    default: throw "Error, ++ called with bad arguments";
    };
  }


  private static function evalMinus (a : Array<HatchValue>, bs : BindingStack) {
    if (a.length != 2) throw "Error: -- called with wrong number of arguments";
    return switch( a.map( eval.bind( _, bs ) ) ) {
    case [IntV(x), IntV(y)] : IntV(x - y);
    case [IntV(x), FloatV(y)] : FloatV(x - y);
    case [FloatV(x), IntV(y)] : FloatV(x - y);
    case [StringV(x), StringV(y)] : StringV( StringTools.replace(x, y, '') );
    default: throw "Error, -- called with bad arguments";
    };
  }

  
  private static function evalHead ( a: Array<HatchValue>, bs : BindingStack ) {
    if (a.length != 1) throw "error, head called with wrong number args";
    return switch( eval( a[0], bs ) ) {
    case ListV(b) if (b.length > 0): b[0];
    default: throw 'Error: cannot return head of non-list ${a[0]}';
    };
  }

  private static function evalTail (a : Array<HatchValue>, bs : BindingStack ) {
    if (a.length != 1) throw "error, tail called with wrong number of args";
    return switch( eval( a[0], bs ) ) {
    case ListV(b) if (b.length > 0): ListV(b.slice(1));
    default: throw "no tail of non list";
    };
  }

  private static function evalNth (a : Array<HatchValue>, bs : BindingStack ) {
    if (a.length != 2 ) throw "error, special form ! takes two arguments (! int list)";
    return switch ( a.map( eval.bind( _, bs ) ) ) {
    case [IntV(n), ListV(l)]: l[n];
    default: throw "error, special form, call like this (! int list)";
    }
  }

  private static function isLetBindings( a: Array<HatchValue> ) {
    for (v in a) switch (v) {
      case ListV([SymbolV(_),_]): 'no_op';
      default: return false;
      }
    return true;
  }

  private static function namesFromLetBindings (a : Array<HatchValue>) {
    return [for (b in a) switch (b) {case ListV([SymbolV(s),_]): s; default: throw "mega prob";}];
  }

  private static function exprsFromLetBindings (a : Array<HatchValue>, bs : BindingStack ) {
    return [for (b in a) switch (b) {case ListV([_,f]): eval( f , bs); default: throw "mega mega prob";}];
  }
  
  private static function evalLet ( a : Array<HatchValue>, bs : BindingStack ) {
    if (a.length != 2) throw "error, malformed let expression. Hint: (let bindings form)";
    return switch (a) {
    case [ListV(ls), form] if (isLetBindings( ls )): {
	var names = namesFromLetBindings(ls);
	var exprs = exprsFromLetBindings(ls, bs);
	var thisScope = introduceBindings( names, exprs, bs);
	return eval( form, thisScope );
      };
    default: throw "error, malformed let expression";
    };
  }
  
  private static function evalList( a : Array<HatchValue>, bs : BindingStack)  {
    if (a.length == 0) return ListV(a);

    return switch (a[0]) {
    case SymbolV('define'): evalDefine(a.slice(1), bs);
    case SymbolV('lambda'): evalLambda(a.slice(1), bs);
    case SymbolV('if'): evalIf( a.slice( 1 ), bs);
    case SymbolV('let'): evalLet( a.slice( 1 ), bs);
    default: switch( eval( a[0], bs ) ) {
      case FunctionV(f): f( ListV( a.slice(1)), bs );
      default: throw 'Error: cannot eval $a as given';
      };
    };
  }

  private static function evalVar (v:String, bs : BindingStack) {
    switch ( bs.lookup( v ) ) {
    case None: throw 'unbound variable $v';
    case Some(v): return v;
    }
  }

  public static function evalR (s : String, bs : BindingStack) {
    switch (Reader.read(s)) {
    case Left(e): throw 'Error: $e';
    case Right(exp): return eval(exp, bs);
    }
  }
  
 
						   
}



