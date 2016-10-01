package hatch;

import haxe.ds.Option;
import hatch.Reader;
import hatch.HatchValue.HatchValue;
import hatch.BindingStack.Bindings;
using Lambda;

class Evaluator {

  private static var coreBindings : BindingStack;
  private static var documentation : Map<String,String>;
  private static var RESERVED_NAMES : Array<String>;
  
  public static function init () {
    if (coreBindings == null) {
      documentation = new Map();
      addCoreBindings();
      RESERVED_NAMES = ["if","cond","let","lambda","->","define",":=","#f","#t",".","quote", ":", "help"];
#if sys
      RESERVED_NAMES = RESERVED_NAMES.concat(["load"]);
#end
    }
  }

  public static function setCore (s : String, d : Dynamic) {
    coreBindings.bindSymbol(s, marshalHaxeVal( d ));
  }

  private static function documentSymbol ( bs: BindingStack, s : String, doc : String ) {
    documentation.set(s,doc);
  }

  private static function lookupDocumentation ( bs: BindingStack, s : String) {
    return documentation.get(s);
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
    core.set('+', wrapEval(evalPlus));
    core.set('-', wrapEval(evalMinus));
    core.set('*', wrapEval(evalMult));
    core.set('/', wrapEval(evalDiv));
    core.set('%', wrapEval(evalMod));        
    core.set('!', wrapEval(evalNth));
    core.set('function?', wrapEval(evalIsFunction));
    core.set('or', wrapEval(evalOr));
    core.set('and', wrapEval(evalAnd));
    core.set('$', wrapEval(evalPartial));
    core.set('=', wrapEval(evalEqual));
    core.set('eval', wrapEval(function (exp, bs) {
	  if (exp.length != 1) throw "Bad eval call";
	  return eval( eval( exp[0], bs), bs);
	}));

    loadPrelude();

  }

  private static function loadPrelude () {
    loadString( Prelude.getPrelude(), coreBindings);
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
    checkForReservedNames( names ); // Note! this can throw an error
    var bindings : Bindings = new Map();
    if (names.has('rest&')) {
      var stop = names.indexOf('rest&');
      for (i in 0...stop) bindings.set( names[i], eval( vals[i], bs));
      bindings.set('rest&', ListV( vals.slice( stop ).map( eval.bind( _, bs ))));
    } else {
      for (i in 0...names.length) bindings.set( names[i], eval( vals[i], bs));
    }
    return bs.newScope( bindings );
  }

  private static function redefineForm( form: HatchValue, scope : BindingStack) {
    return switch (form) {
    case ListV(frms): ListV(frms.map( redefineForm.bind(_, scope)));
    case SymbolV(s): switch (scope.lookup(s)) {
	case None: SymbolV(s);
	case Some(val): val;
	}
    default: form;
    }
  }
  
  private static function evalLambda( a : Array<HatchValue> , defineScope : BindingStack) {
    if (a.length != 2) throw "Error: malformed lambda expression";
    return switch (a) {
    case [ListV(args), form] if ( allSymbols( args ) ):  {
	var names = symbolsToNames(args);
	var form2 = redefineForm( form, defineScope);
	var f = function (expr : HatchValue, callingScope : BindingStack ) {
	  switch (expr) {
	  case ListV(exprs):{
	    var argumentScope = introduceBindings( names, exprs, callingScope);
	    return eval( form2 , argumentScope);
	  }
	  default: throw "OH NO, SOMEHOW THIS FUNCTION WAS CALLED INCORRECTLY";
	  }
	};
	return FunctionV(f);	  
      }
    default: throw "Error: malformed lambda expression";
    };
  }


  private static function macroBindings (ns : Array<String>, exs: Array<HatchValue>) {
    var quote = function (e : HatchValue) {return ListV([SymbolV('quote'), e]);};
    var bs : Bindings = new Map();
    if (ns.has('rest&')) {
      var stop = ns.indexOf( 'rest&' );
      for (i in 0...stop) bs.set( ns[i], quote( exs[i] ));
      bs.set('rest&', quote(ListV( exs.slice( stop ))));
    } else {
      for (i in 0...ns.length) bs.set( ns[i], quote( exs[i] ));
    }
    return bs;
  }
  
  private static function expandMacro( form : HatchValue, bs: Bindings) {
    return switch (form) {
    case SymbolV(s): if (bs.exists(s)) bs.get( s ) else SymbolV(s);
    case ListV(s): ListV( s.map( expandMacro.bind(_, bs) ));
    default: form;
    };
  }
  
  private static function evalMacro (a : Array<HatchValue>, defineScope : BindingStack ) {
    if (a.length != 2) throw "Error: malformed macro expression";
    return switch (a) {
    case [ListV(args), form] if (allSymbols( args )): {
	var names = symbolsToNames(args);
	var f = function (expr : HatchValue, callingScope : BindingStack) {
	  switch (expr) {
	  case ListV(exprs): {
	    var boundForms = macroBindings( names, exprs );
	    var expanded = expandMacro( form, boundForms );
	    return eval( expanded, callingScope);
	  }
	  default: throw "Macro called incorrectly?";
	  }
	};
	return FunctionV(f);
      }
    default: throw "Error, Somehow this macro was called incorrectly";
    };
  }

  
  private static function evalDefine (a :Array<HatchValue>, bs : BindingStack) {
    if (a.length != 2 && a.length != 3) throw "Error: malformed define statement";
    return switch (a) {
    case [SymbolV(s), form]: bs.bindSymbol( s, eval( form, bs ) );
    case [SymbolV(s), form, StringV(doc)]: {
      var val = bs.bindSymbol(s, eval( form, bs ) );
      documentSymbol( bs, s, doc );
      val;
    }
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
  
  // Should be short-circuiting
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
    for (i in 1...a.length) {
      if ( !eqlHatchVal(val, eval(a[i], bs))) return BoolV(false);
    }
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

  private static function evalMult ( a :Array<HatchValue>, bs: BindingStack) {
    if (a.length < 2) throw "Error, * called with wrong number of arguments";
    var vals = a.map( eval.bind(_, bs));
    if (allIntVals(vals)) {
      return IntV(vals.fold(function (v, acc) {return hxInt(v) * acc;}, 1));
    } else if (allNumberVals(vals)) {
      return FloatV(vals.fold(function (v, acc:Float) {return hxFloat(v) * acc;}, 1.0)); 
    } else switch (a) {
      case [IntV(i), StringV(s)]:  return StringV([for (x in 0...i) s].join(''));
      case [StringV(s), IntV(i)]:  return StringV([for (x in 0...i) s].join(''));
      default: throw "Error, * called with bad arguments";
      }
  }

  private static function evalDiv (a : Array<HatchValue>, bs : BindingStack) {
    if (a.length != 2) throw "Error, / called with wrong number of arguments";
    return switch (a.map( eval.bind(_, bs))) {
    case [IntV(i), IntV(j)]: IntV(Std.int(i / j));
    case [IntV(i), FloatV(j)] : FloatV(i/j);
    case [FloatV(i), FloatV(j)] : FloatV(i/j);
    case [FloatV(i), IntV(j)] : FloatV(i/j);
    default: throw "Error, / called with the wrong arguments";
    }
  }

  private static function evalMod (a :Array<HatchValue>, bs : BindingStack) {
    if (a.length != 2) throw "Error, % called with wrong number of arguments";
    return switch (a.map( eval.bind(_, bs))) {
    case [IntV(i), IntV(j)]: IntV(i % j);
    default: throw "Error, % called with the wrong arguments";
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
    if (a.length != 2 ) throw "error, special form ! takes two arguments (! int sequence)";
    return switch ( a.map( eval.bind( _, bs ) ) ) {
    case [IntV(n), ListV(l)]: l[n];
    case [IntV(n), StringV(l)]: StringV(l.charAt(n));
    default: throw "error, special form, call like this (! int sequence)";
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
    return [for (b in a) switch (b) {case ListV([_,f]): f; default: throw "mega mega prob";}];
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


  private static function resolveHaxeSymbol (v : HatchValue)  {
    switch (v) {
    case SymbolV(s): {

      var path = s.split('.');

      // its hopefully a class method
      if (path[path.length - 1].charAt(0) == path[path.length - 1].toLowerCase().charAt(0)) {
	var clMaybe = Type.resolveClass( path.slice(0, -1).join('.'));
	if (clMaybe != null)  return Reflect.field( clMaybe, path[path.length - 1]);
      }

      // its probably a class
      if (path[path.length - 1].charAt(0) == path[path.length - 1].toUpperCase().charAt(0)) {
	var clMaybe = Type.resolveClass(s);
	if (clMaybe != null) return clMaybe;
      }

      return null;
    }
    default: return null;
    };
  }

  private static function demarshalHatch (v : HatchValue) : (Dynamic) {
    return switch (v) {
    case IntV(i) : i;
    case FloatV(f): f;
    case StringV(s) : s;
      //    case ListV(l) : l.map(demarshalHatch); // WARNING - PROBABLY NOT HOMOGENEOUS
    case ListV(l): l;
    case SymbolV(a) : a;	// WARNING - POSSIBLY USELESS
    case BoolV(b) : b;
    case HaxeV(h) : h;
    case FunctionV(f) : f;	// WARNING - PROBABLY USELESS
    }
  }
  
  private static function marshalHaxeVal (v : Dynamic) {
    return switch (Type.typeof(v)) {
    case TInt: IntV(v);
    case TFloat: FloatV(v);
    case TBool: BoolV(v);
    case TFunction: return FunctionV(function (a, bs) {
	return switch (a) {
	case ListV(exprs): {
	  Reflect.callMethod(null, v, exprs.map(eval.bind(_, bs)).map(demarshalHatch));
	}
	default: throw "Error calling external method";
	};
      });
    case TNull: ListV([]);
    default: {
      if (Std.is( v, String)) return StringV(v);
      return HaxeV(v);
    }
    };
  }

  private static function getAttribute( o : Dynamic, s : String ) : (Dynamic) {
    if (Reflect.hasField(o, s))  return Reflect.field(o, s);
    return Reflect.getProperty(o, s);
  }

  private static function setAttribute( o : Dynamic, s : String, v : Dynamic) {
    if (Reflect.hasField(o, s)) {
      Reflect.setField( o, s, v);
    } else {
      Reflect.setProperty( o, s, v);
    }
  }

  
  private static function evalHaxe ( a : Array<HatchValue>, bs : BindingStack, ?setter = false) {
    if (a.length == 0) throw "error, . takes a Haxe identifier and optional arguments";
    var haxeVal : Dynamic = resolveHaxeSymbol( a[0] );
    if (haxeVal != null ) {
      if (Reflect.isObject( haxeVal )) { // MIGHT BE A CLASS
	return marshalHaxeVal(Type.createInstance( haxeVal, a.slice(1).map(eval.bind(_, bs)).map(demarshalHatch)));
      } else if (Reflect.isFunction( haxeVal )) {
	return marshalHaxeVal(Reflect.callMethod(null, haxeVal, a.slice(1).map(eval.bind(_, bs)).map(demarshalHatch)));
      } else throw 'bad Haxe external ${a[0]}?';
    } else switch ([ a[0], demarshalHatch( eval( a[1], bs)) ]) {
      case [SymbolV(s), o]: { // should I demarshal? or no?
        var path = s.split('.');
        path.reverse();
        var fieldVal : Dynamic = getAttribute(o, path.pop()); // Reflect.field( o, path.pop() );
        var fieldOb : Dynamic = o;
        while (path.length > 0) {
          fieldOb = fieldVal;
          fieldVal = getAttribute( fieldOb, path.pop()); //Reflect.field( fieldOb, path.pop() );
        }

        if (Reflect.isFunction(fieldVal)) {
          return marshalHaxeVal(Reflect.callMethod( fieldOb, fieldVal,
                                                    a.slice(2).map( eval.bind( _, bs )).map(demarshalHatch)));
        } else if (setter) {
          if (a.length == 3) {
            var val = eval( a[2], bs);
            setAttribute( fieldOb, s.split('.').shift(), demarshalHatch( val ));
            return val;
          } else throw 'Error .= called with wrong number of terms';
        } else return marshalHaxeVal(fieldVal);
      }
      default: throw 'bad haxe reference ${a[0]} on ${a[1]}';
      }
  }


  private static function evalHaxeFunction( a : Array<HatchValue>, defineScope : BindingStack ) {
    // (function args body)
    switch (a) {
    case [ListV([]), _form]:
      {
	var lambda = evalLambda( a, defineScope);
	var f = function () {
	  return demarshalHatch( eval( ListV([ lambda ]) ));
	};
	return HaxeV( f );
      }
    case [ListV([SymbolV(arg1)]), _form]:
      {
	var lambda = evalLambda( a , defineScope );
	var f = function (theArg : Dynamic)
	  {
	    return demarshalHatch( eval( ListV([ lambda, marshalHaxeVal( theArg )] ))); // This is evaled in defaultScope :(
	  };
	return HaxeV( f );
      }
    case [ListV([SymbolV(_),SymbolV(_)]), _from]:
      {
	var lambda = evalLambda( a , defineScope );
	var f = function( arg1 : Dynamic, arg2 : Dynamic ) {
	  return demarshalHatch( eval( ListV([ lambda, marshalHaxeVal( arg1 ), marshalHaxeVal( arg2 )])));
	};
	return HaxeV( f );
      }
      
    default: throw "Bad function: syntax, takes zero, one, or two arguments";
    }
  }
  
  private static function evalObLit( a : Array<HatchValue>, bs : BindingStack) {
    if (a.length % 2 != 0) throw "Bad object literal syntax";
    var ob = {};
    var a2 = a.copy();
    while (a2.length > 0) {
      switch (a2.shift()) {
      case SymbolV(s): {
	Reflect.setField( ob, s, demarshalHatch(eval( a2.shift(), bs)));
      }
      default: throw 'Bad object literal syntax; non-symbol used as field name';
      }
    }
    return HaxeV(ob);
  }

  private static function evalHelp (a : Array<HatchValue>, bs: BindingStack) {
    return switch (a) {
    case []: {
      var keys = [for (k in documentation.keys()) k];
      keys.sort(Reflect.compare);
      ListV(keys.map(SymbolV));
    }
    case [SymbolV(s)]: {
      var doc = lookupDocumentation(bs, s);
      if (doc != null) StringV(doc) else StringV("Not Documented");
    }
    default: throw "Bad help lookup";
    };
  }


  public static function loadString (content : String, bs : BindingStack) {
    var commentR = ~/;[^\n]*\n/g;
    content = commentR.replace(content,' ');
    switch (Reader.readMany( content )) {
    case Left(e): throw 'PARSE ERROR $e';
    case Right(exprs):  for (e in exprs) eval( e, bs );
    }
  }
  
  
  private static function evalLoad (a : Array<HatchValue>, bs : BindingStack) {
#if sys
    if (a.length == 0) throw "cannot load nothing";
    var cwd = Sys.getCwd();
    for (path in a)  {
      var file = '$cwd/${demarshalHatch(path)}';
      if (sys.FileSystem.exists(file)) {
	var content = sys.io.File.getContent(file);
	loadString( content , bs );
      } else {
	throw 'file not found: $file';
      }
    }
#end
    return ListV([]);
  }
  

  
  private static function evalList ( a : Array<HatchValue>, bs : BindingStack)  {
    if (a.length == 0) return ListV(a);

    return switch (a[0]) {
#if sys
    case SymbolV('load'): evalLoad(a.slice(1), bs);
#end
    case SymbolV('define'), SymbolV(':='): evalDefine(a.slice(1), bs);
    case SymbolV('lambda'), SymbolV('->'): evalLambda(a.slice(1), bs);
    case SymbolV('macro'): evalMacro(a.slice(1), bs);
    case SymbolV('if'): evalIf( a.slice( 1 ), bs);
    case SymbolV('let'): evalLet( a.slice( 1 ), bs);
    case SymbolV('help'): evalHelp( a.slice( 1 ), bs );
    case SymbolV('.='): evalHaxe( a.slice( 1 ), bs, true);
    case SymbolV('.'): evalHaxe( a.slice( 1 ), bs);
    case SymbolV(':'): evalObLit( a.slice( 1 ), bs);
    case SymbolV('function:'): evalHaxeFunction( a.slice( 1 ), bs);
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

  public static function evalR (s : String, ?bs0 : BindingStack = null) {
    var bs = if (bs0 == null) coreBindings else bs0;
    switch (Reader.read(s)) {
    case Left(e): throw 'Error: $e';
    case Right(exp): return eval(exp, bs);
    }
  }
  
}



