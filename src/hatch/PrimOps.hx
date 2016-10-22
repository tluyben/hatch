package hatch;

import hatch.HatchValue.HatchValue;
using hatch.HatchValueUtil;
using Lambda;


class PrimOps
{


  public static function length (args : Array<HatchValue>) : (HatchValue)
  {
    return switch (args)
      {
      case [ListV(a)]: IntV(a.length);
      case [StringV(s)]: IntV(s.length);
      default: throw "improper arguments in call to length";
      }
  }

  public static function atIndex (args : Array<HatchValue>) : (HatchValue)
  {
    return switch (args)
      {
      case [IntV(n), ListV(a)] if (n < a.length): a[n];
      case [IntV(n), StringV(s)] if (n < s.length): StringV(s.charAt(n));
      case [_, v] if (v.isList() || v.isString()):
        throw "error: attempted to de index out of sequence bounds";
      default: throw "de index operator called with bad arguments";
      }
  }

  public static function add (args : Array<HatchValue>) : (HatchValue)
  {
    if ( args.length == 2 || args.foreach( HatchValueUtil.isNumeric) )
      {
        var result = args[0].toHaxe() + args[1].toHaxe();
        return if ( args.exists( HatchValueUtil.isFloat)) FloatV(result) else IntV(Std.int(result));
      }
    throw "cannot add non-numeric arguments";
  }

  public static function sub (args : Array<HatchValue>) : (HatchValue)
  {
    if ( args.length == 2 && args.foreach( HatchValueUtil.isNumeric) )
      {
        var result = args[0].toHaxe() - args[1].toHaxe();
        return if (args.exists( HatchValueUtil.isFloat)) FloatV(result) else IntV(Std.int(result));
      }
    throw "cannot subtract non-numeric or zero-length arguments";
  }

  public static function mul (args : Array<HatchValue>) : (HatchValue)
  {
    if (args.length == 2 || args.foreach( HatchValueUtil.isNumeric ) )
      {
        var result = args[0].toHaxe() * args[1].toHaxe();
        return if (args.exists( HatchValueUtil.isFloat)) FloatV(result) else IntV(Std.int(result));
      }
    throw "cannot multiply non-numeric arguments";
  }
  

  public static function div (args : Array<HatchValue>) : (HatchValue)
  {
    if (args.length == 2 && args[0].isNumeric() && args[1].isNumeric()) {
      return FloatV( args[0].toHaxe() / args[1].toHaxe());
    }
    throw "cannot perform division operation on supplied arguments";
  }

  public static function head (args : Array<HatchValue>) : (HatchValue)
  {
    return switch (args)
      {
      case [ListV( vals )] if (vals.length > 0): vals[0];
      default: throw "cannot take head of nonlist or empty list or more than one argument";
      }
  }
  
  public static function tail (args : Array<HatchValue>) : (HatchValue)
  {
    return switch (args)
      {
      case [ListV( vals )] if (vals.length > 0): ListV(vals.slice(1));
      default: throw  "cannot take tail of nonlist or empty list or more than one argument";
      }
  }

  public static function cons (args : Array<HatchValue>) : (HatchValue)
  {
    return switch (args)
      {
      case [hd, ListV(tl)]: {
        var newList = tl.slice(0);
        newList.unshift(hd);
        return ListV( newList );
      }
      default: throw "malformed cons call";
      }
  }

  public static function isEmpty (args : Array<HatchValue>) : (HatchValue)
  {
    return switch (args)
      {
      case [ListV([])] : BoolV(true);
      case [ListV(_)]: BoolV(false);
      default: throw "cannot check if a non-list is empty";
      }
  }
  
  public static function mod (args : Array<HatchValue>) : (HatchValue)
  {
    return switch (args)
      {
      case [IntV(i), IntV(j)]: IntV(i % j);
      default: throw "cannot perform modulo calculation with provided arguments";
      }
  }

  public static function equal (args: Array<HatchValue>) : (HatchValue)
  {
    return switch (args)
      {
      case [v1, v2]: BoolV( HatchValueUtil.equal( v1, v2 ));
      default: throw "malformed equality check";
      }
  }

  public static function apply (args: Array<HatchValue>) : (HatchValue)
  {
    return switch (args)
      {
      case [val, ListV(arguments)]: Evaluator.apply( val, arguments );
      default: throw "malfomred apply expression";
      }
  }

  public static function concat (args : Array<HatchValue>) : (HatchValue)
  {
    return switch (args)
      {
      case [ListV(a1), ListV(a2)]: ListV(a1.copy().concat( a2.copy() ));
      case [StringV(s1), StringV(s2)]: StringV(s1 + s2);
      default: throw "attempt to concatenate not supported on given arguments";
      }
  }

  public static function dot (args : Array<HatchValue>) : (HatchValue)
  {
    return switch (args)
      {
      case [SymbolV(haxeRef), ListV(vals)]:
	HaxeOpV(function () {
	    try {
	      var evaluated = HaxeEnv.evaluate( haxeRef, vals.map(HatchValueUtil.toHaxe ));
	      return ok( HatchValueUtil.fromHaxe( evaluated ) );
	      //	      return ListV([SymbolV('ok'), HatchValueUtil.fromHaxe( evaluated )]);	  
	    } catch ( e:Dynamic ) {
	      return fail( Std.string( e ));
	      //	      return ListV([SymbolV('fail'), StringV(Std.string(e))]);
	    }
	  });
      case [ context, ListV(vals)] if ( vals.length >= 1 && HatchValueUtil.isSymbol(vals[0])):
	HaxeOpV(function () {
	    try {
	      var evaluated = HaxeEnv.evaluate( vals[0].toHaxe(),
						vals.slice(1).map(HatchValueUtil.toHaxe),
						context.toHaxe());
	      return ok( HatchValueUtil.fromHaxe( evaluated ) );
	      //	      return ListV([SymbolV('ok'), HatchValueUtil.fromHaxe( evaluated )]);	  
	    } catch (e:Dynamic) {
	      return fail( Std.string( e ));
	      //	      return ListV([SymbolV('fail'), StringV(Std.string(e))]);
	    }
	  });
      default: throw "the . primitive called with malformed arguments";
      };
  }

  public static function dotSet (args : Array<HatchValue>) : (HatchValue)
  {
    return switch (args)
      {
      case [SymbolV(haxeRef), v]:
	HaxeOpV(function () {
	    try {
	      HaxeEnv.setSymbol(haxeRef, v.toHaxe());
	      //	      return ListV([SymbolV('ok'), args[0]]);
	      return ok( args[0] );
	    } catch (e:Dynamic) {
	      //	      return ListV([SymbolV('fail'), StringV(Std.string(e))]);
	      return fail( Std.string(e) );
	    }
	  });	    
      default: throw ' the .= primitive called with malformed arguments';
      };
  }

  public static function dotBind (args : Array<HatchValue>) : (HatchValue)
  {
    // bind :: m a -> (a -> m b) -> m b
    // (.>> op f) ;; op2
    return switch (args)
      {
      case [HaxeOpV(op), FunctionV(_,_,_)]:
	HaxeOpV(function () {
	    var res = op();
	    return switch ( res )
	      {
	      case ListV([SymbolV('fail'), _]): res;
	      case ListV([SymbolV('ok'), val]): switch (Evaluator.apply( args[1], [val]))
		  {
		  case HaxeOpV(op2): op2();
		  default: throw "second argument to monadic bind did not return a haxe operation";
		  }
	      default: throw "monadic bind called with bad arguments";
	      }
	  });
      default: throw "monadic bind called with bad arguments";
      };
  }

  public static function runHaxe (args : Array<HatchValue>) : (HatchValue)
  {
    return switch (args)
      {
      case [HaxeOpV(op)]: op();
      default: throw "run-haxe must be called with an Haxe operation";
      }
  }

  public static function getNth (args : Array<HatchValue>) : (HatchValue)
  {
    return switch (args)
      {
      case [IntV(i), ListV(l)] if (i < l.length): l[i];
      case [IntV(_), ListV(_)]: throw 'indiex out of range';
      default: throw 'nth called with improper arguments';
      };
  }

  private static function isAssocList (vals: Array<HatchValue>) : (Bool)
  {
    if (vals.length % 2 == 1)
      {
	return false;
      }

    var i = 0;
    while ( i < vals.length && vals[i].isSymbol() )
      {
	i += 2;
      }
    return i == vals.length;
  }

  private static function makeAssocPairs (vals : Array<HatchValue>) : Array<{attrib:String,value:Dynamic}>
  {
    var a = [];
    var i = 0;
    while (i < vals.length)
      {
	a.push( {attrib: vals[i].toHaxe(), value: vals[i+1].toHaxe()});
	i += 2;
      }
    return a;
  }

  private static function ok (v : HatchValue) : (HatchValue)
  {
    return ListV([SymbolV('ok'), v]);
  }

  private static function fail (v : String) : (HatchValue)
  {
    return ListV([SymbolV('fail'), StringV(v)]);
  }
  
  public static function pureHaxe (args : Array<HatchValue>)
  {
    return switch (args)
      {
      case [v]: HaxeOpV(function () {return ok(v);});
      default: throw '`haxe` takes a single expression';
      }
  }
  
  public static function makeObjectLiteral (args : Array<HatchValue>)
  {
    return switch (args)
      {
      case [ListV(vals)] if (isAssocList( vals )):
	HaxeOpV(function () {
	    var ob = {};
	    var pairs = makeAssocPairs( vals );
	    for (pair in pairs)
	      {
		Reflect.setField(ob, pair.attrib, pair.value);
	      }
	    return ok( HaxeV(ob));
	  });
      default: throw "bad call to make object literal";
      }
  }

  public static function mapHaxe (args : Array<HatchValue>)
  {
    return switch (args)
      {
      case [FunctionV(_,_,_), HaxeOpV(op)]:
	HaxeOpV(function () {
	    var res = op();
	    return switch ( res )
	      {
	      case ListV([SymbolV('fail'), _]): res;
	      case ListV([SymbolV('ok'), val]): ok( Evaluator.apply( args[0], [val] ));
	      default: fail( "haxe op returned unexpected value");
	      };
	  });
      default: throw "maphx takes two arguments";
      };
  }

}


