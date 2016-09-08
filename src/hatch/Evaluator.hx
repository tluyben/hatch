

import haxe.ds.Option;
import Reader;
import HatchValue.HatchValue;
import BindingStack.Bindings;
using Lambda;

class Evaluator {

  private static var coreBindings : BindingStack;
  private static var RESERVED_NAMES : Array<String>;
  
  public static function init () {
    if (coreBindings == null) {
      addCoreBindings();
      RESERVED_NAMES = ["if","cond","let","lambda","define","#f","#t"];
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
    core.set('function?', wrapEval(evalIsFunction));
    core.set('or', wrapEval(evalOr));
    core.set('and', wrapEval(evalAnd));
    core.set('list', wrapEval(evalListFunction));
    core.set('$', wrapEval(evalPartial));
    core.set('=', wrapEval(evalEqual));
    core.set('eval', wrapEval(function (exp, bs) {
	  if (exp.length != 1) throw "Bad eval call";
	  return eval( eval( exp[0], bs), bs);
	}));
	  
    evalR('(define map (lambda (f l) 
                       (if (empty? l) l
                           (cons (f (head l)) 
                                 (map f (tail l))))))', coreBindings);

    evalR('(define fold (lambda (f acc l)
                          (if (empty? l) acc
                              (fold f (f (head l) acc) (tail l)))))', coreBindings);

    evalR('(define <> (lambda (f g) (lambda (x) (f (g x)))))', coreBindings);
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
    return vars.map(hxSymbol);
  }

  private static function checkForReservedNames (ns : Array<String>) {
    for (n in ns) if (RESERVED_NAMES.has(n)) throw 'Error: $n is a reserved name';
  }
  
  private static function introduceBindings (names: Array<String>,
					     vals: Array<HatchValue>,
					     bs : BindingStack) {
    checkForReservedNames( names ); // Note! this can throws an error
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

  private static function evalListFunction (a :Array<HatchValue>, bs : BindingStack) {
    return ListV(a.map(eval.bind(_, bs)));
  }

  private static function evalPartial (a : Array<HatchValue>, definingScope : BindingStack) {
    if (a.length == 0) throw "$ takes at least one argument";
    var a2 = a.map(eval.bind(_, definingScope)); // might eval a[0] before eval all.. oh well.
    return switch (a2[0]) {
    case FunctionV(f): {
      return FunctionV(function (a3 : HatchValue, callingScope : BindingStack) {
	  return switch (a3) {
	  case ListV(exprs): f(ListV(a2.slice(1).concat(exprs)), callingScope); 
	  default: throw "Oh gosh, something really horrible has happened.";
	  }
	});
    }
    default: throw "Can't partially evaluate a non function";
    };    
  }
  
  private static function evalOr (a : Array<HatchValue>, bs: BindingStack) {
    for (arg in a) {
      var val = eval( arg, bs);
      if (isTruthy(val)) return val;
    }
    return BoolV(false);
  }

  private static function evalAnd (a : Array<HatchValue>, bs : BindingStack) {
    var val = BoolV(false);
    for (arg in a) {
      val = eval( arg, bs);    
      if (!isTruthy(val)) return BoolV(false);
    }
    return val;
  }
  
  private static function evalIsList ( a : Array<HatchValue> , bs : BindingStack ) {
    if (a.length != 1) throw "Error: list? called with wrong number of arguments";
    return switch( eval(a[0], bs )) {
    case ListV(_): BoolV(true);
      //    case NilV: BoolV(true);
    default: BoolV(false);
    };
  }


  private static function evalEqual (a : Array<HatchValue>, bs : BindingStack) {
    if (a.length < 1) throw "Error, = cannot be called with zero arguments";
    var val = eval( a[0], bs);
    for (i in 1...a.length) if ( !eqlHatchVal(val, eval(a[i], bs))) return BoolV(false);
    return BoolV(true);
  }

  private static function allIntVals (a : Array<HatchValue> ) {
    for (v in a) switch (v) {case IntV(_): 'no_op'; default: return false;};
    return true;
  }

  private static function allStringVals (a : Array<HatchValue> ) {
    for (v in a) switch (v) {case StringV(_): 'no_op'; default: return false;};
    return true;
  }

  private static function allListVals (a : Array<HatchValue> ) {
    for (v in a) switch (v) {case ListV(_): 'no_op'; default: return false;};
    return true;
  }

  private static function allNumberVals (a : Array<HatchValue> ) {
    for (v in a) switch (v) {case IntV(_): 'no_op'; case FloatV(_): 'no_op'; default: return false;};
    return true;
  }


  private static function hxInt (v : HatchValue)  {
    return switch (v) {
    case IntV(i) : i;
    default: throw "Error, bad hx coersion";
    };
  }

  private static function hxFloat (v : HatchValue)  {
    return switch (v) {
    case IntV(i) : i+ 0.0;
    case FloatV(i) : i;
    default: throw "Error, bad hx coersion";
    };
  }

  private static function hxString (v : HatchValue)  {
    return switch (v) {
    case StringV(i) : i;
    default: throw "Error, bad hx coersion";
    };
  }

  private static function hxList (v : HatchValue)  {
    return switch (v) {
    case ListV(i) : i;
    default: throw "Error, bad hx coersion";
    };
  }

  private static function hxSymbol( v : HatchValue) {
    return switch (v) {
    case SymbolV(s): s;
    default: throw "Error, bad hx coersion";
    }
  }
  
  private static function evalPlus (a : Array<HatchValue>, bs : BindingStack) {
    if (a.length < 2) throw "Error: ++ called with wrong number of arguments";
    var vals = a.map( eval.bind( _, bs ));
    if (allIntVals( vals ) ) {
      return IntV(vals.fold(function (v, acc) {return hxInt(v) + acc;}, 0));
    } else if (allNumberVals( vals )) {
      return FloatV(vals.fold(function (v, acc) {return hxFloat(v) + acc;}, 0));
    } else if (allStringVals( vals )) {
      return StringV(vals.fold(function (v, acc) {return acc + hxString(v);}, ''));
    } else if (allListVals( vals )) {
      return ListV(vals.fold(function (v, acc:Array<HatchValue>) {return acc.concat(hxList(v));},[]));
    } else throw "Error: ++ called with improper arguments";
  }

  private static function eqlListVal (xs : Array<HatchValue>, ys : Array<HatchValue>) {
    if (xs.length != ys.length) return false;
    for (i in 0...xs.length) if (!eqlHatchVal(xs[i],ys[i])) return false;
    return true;
  }

  private static function eqlHatchVal ( v1 : HatchValue, v2 : HatchValue) {
    return switch( [v1, v2]) {
    case [IntV(x), IntV(y)]: x == y;
    case [FloatV(x), FloatV(y)] : x == y;
    case [StringV(x), StringV(y)] : x == y;
    case [FunctionV(f), FunctionV(g)]: Reflect.compareMethods(f,g);
    case [ListV(xs), ListV(ys)] : eqlListVal(xs,ys);
    case [SymbolV(a), SymbolV(b)] : a == b;
    case [BoolV(a), BoolV(b)]: (a && b) || (!a && !b);
    default: false;
    };
  }

  private static function evalMinus (a : Array<HatchValue>, bs : BindingStack) {
    if (a.length != 2) throw "Error: -- called with wrong number of arguments";
    return switch( a.map( eval.bind( _, bs ) ) ) {
    case [IntV(x), IntV(y)] : IntV(x - y);
    case [IntV(x), FloatV(y)] : FloatV(x - y);
    case [FloatV(x), IntV(y)] : FloatV(x - y);
    case [StringV(x), StringV(y)] : StringV( StringTools.replace(x, y, '') );
    case [ListV(xs), ListV(ys)] :
      ListV( [for (x in xs) if (!ys.exists(function (y) {return eqlHatchVal(x,y);})) x]);
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

  private static function evalIsFunction (a : Array<HatchValue>, bs : BindingStack) {
    if (a.length != 1) throw "function? called with wrong number of arguments";
    return switch ( eval(a[0], bs) ) {
    case FunctionV(_): return BoolV(true);
    default: return BoolV(false);
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
  
  // public static function main () {
  //   Reader.init();
  //   init();
  //   var test = function (s) {
  //     switch (Reader.read(s)) {
  //     case Left(e) : trace(e);
  //     case Right(v): trace(eval(v, coreBindings));
  //     }
  //   };

  //   test("()");
  //   test("33");
  //   test("44.32");
  //   test('"hello there"');
  //   test("(quote (1 2 3))");
  //   test("(lambda (x) x)");
  //   test("((lambda (x) x) 2)");
  //   test("(lambda () (quote (1 2 3)))");
  //   test("((lambda () (quote (1 2 3))))");    
  //   test("(define x 10)");
  //   test("x");
  //   test("(not x)");
  //   test('(define foo (lambda (x y) "Nothing"))');
  //   test('(foo 1 2)');
  //   test('(quote ())');
  //   test('(cons (quote a) (quote (1 2 3)))');
  //   test('(cons 10 30)');
  //   test('(if 3 "True" "False")');
  //   test('(if () "True" "False")');
  //   test("(quote ')");
  //   test("(not 4)");
  //   test("(list? ())");
  //   test("(list? (quote (1 2)))");
  //   test("(empty? ())");
  //   test("(empty? (quote (1 2 3)))");
  //   test("(++ 3 4)");
  //   test("(map (lambda (x) (++ x 1)) (quote (1 2 3)))");
  //   test("(define sum (lambda (l) (fold (lambda (acc v) (++ acc v)) 0 l)))");
  //   test("(sum (quote (1 2 3)))");
  //   test("(sum (map (lambda (x) (++ x 1)) (quote (1 2 3))))");
  // }
 
						   
}



