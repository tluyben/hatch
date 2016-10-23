package hatch;

import hatch.HatchValue.HatchValue;

using Lambda;
using hatch.HatchValueUtil;

class Evaluator {

  public static var prelude : HatchEnv;
  
  public static function init () {
    if (prelude == null) {
      prelude = new HatchEnv();

      prelude.bind('length', wrapPrimOp(1, PrimOps.length));
      prelude.bind('[]', wrapPrimOp(2, PrimOps.atIndex));
      prelude.bind('+', wrapPrimOp(2, PrimOps.add));
      prelude.bind('-', wrapPrimOp(2, PrimOps.sub));
      prelude.bind('*', wrapPrimOp(2, PrimOps.mul));
      prelude.bind('/', wrapPrimOp(2, PrimOps.div));
      prelude.bind('%', wrapPrimOp(2, PrimOps.mod));
      prelude.bind('=', wrapPrimOp(2, PrimOps.equal));
      prelude.bind('head', wrapPrimOp(1, PrimOps.head));
      prelude.bind('tail', wrapPrimOp(1, PrimOps.tail));
      prelude.bind('cons', wrapPrimOp(2, PrimOps.cons));
      prelude.bind('empty?', wrapPrimOp(1, PrimOps.isEmpty));
      prelude.bind('apply', wrapPrimOp(2, PrimOps.apply));
      prelude.bind('concat', wrapPrimOp(2, PrimOps.concat));
      prelude.bind('.', wrapPrimOp(2, PrimOps.dot));
      prelude.bind('bindhx', wrapPrimOp(2, PrimOps.dotBind));
      prelude.bind('runhx', wrapPrimOp(1, PrimOps.runHaxe));
      prelude.bind('.=', wrapPrimOp(2, PrimOps.dotSet));
      prelude.bind('nth', wrapPrimOp(2, PrimOps.getNth));
      prelude.bind('obhx', wrapPrimOp(1, PrimOps.makeObjectLiteral));
      prelude.bind('.>', wrapPrimOp(1, PrimOps.pureHaxe));
      prelude.bind('maphx', wrapPrimOp(2, PrimOps.mapHaxe));
    }
  }

  private static function wrapPrimOp ( numArgs : Int, op : Array<HatchValue> -> HatchValue) : (HatchValue)
  {
    var params = [for (i in 0...numArgs) 'arg$i'];
    return FunctionV( params, ListV( [PrimOpV( op )].concat( params.map(SymbolV))), prelude);
  }
  
  public static function eval (env : HatchEnv, v : HatchValue) : (HatchValue)
  {
    return switch (v)
      {
      case ListV(a): evalList( env, a);
      case SymbolV('_'): v;     // blank always resolves to itself
      case SymbolV(s): env.lookup(s);
      default: v;
      }
  }

  private static function evalList ( env : HatchEnv, vs : Array<HatchValue> ) : (HatchValue)
  {
    if (vs.length == 0) return ListV(vs);

    var head = vs[0];

    return switch (head)
      {
	// here, eval behaves like a function - it evaluates its evaluated argument. Is this right?
      case SymbolV('eval') if (vs.length == 2): eval(env,  eval(env, vs[1]));

      case SymbolV('quote'): vs[1];

      case SymbolV('if') if( vs.length == 4): evalIf( env, vs.slice( 1 ) );

      case SymbolV('lambda'), SymbolV('->') if (vs.length == 3): evalLambda( env , vs.slice( 1 ));

      case SymbolV('let') if (vs.length == 3): evalLet( env, vs.slice( 1 ));

      case SymbolV('define') if (vs.length == 4 || vs.length == 3): evalDefine( env, vs.slice( 1 ));
	
      case PrimOpV(_): apply( head, [ for (v in vs.slice(1)) eval( env , v )]);

      case FunctionV(_,_,_): apply( head, [for (v in vs.slice(1)) eval( env, v)]);

      case SymbolV(s): evalList( env, [ eval(env, head) ].concat( vs.slice(1)));

      default: throw 'cannot evaluate form with head $head';
      };
  }


  private static function isLetBindings ( bindings : HatchValue) : (Bool)
  {
    // ListV([ ListV([ SymbolV(v1), f1]), ListV([ SymbolV(v2), f2]), ...])
    if (bindings.isList())
      {
        return bindings.listContents().foreach(function (hv) {
            return hv.isList() && hv.listContents().length == 2 && hv.listContents()[0].isSymbol();
          });
      }
    return false;
  }

  private static function letParams ( bindings : HatchValue ) : Array<String>
  {
    return bindings.listContents().map(function (pr) {
        return pr.listContents()[0].symbolString();
      });
  }

  private static function letArgs ( env : HatchEnv, bindings : HatchValue) : Array<HatchValue>
  {
    return bindings.listContents().map(function (pr) {
        return eval( env, pr.listContents()[1]);
      });
  }

  // Note, this implementation of let involves parallel assigniment -
  // bindings cannot reference one another.
  private static function evalLet ( env : HatchEnv, forms : Array<HatchValue> ) : (HatchValue)
  {
    return switch (forms)
      {
      case [ bindings, body ] if ( isLetBindings( bindings )):
        callFunction( env, letParams( bindings), letArgs( env, bindings ), body);

      default: throw "Malformed let expression";
      }
  }
  
  private static function unpackSymbols ( a : Array<HatchValue> ) : Array<String>
  {
    return a.map( HatchValueUtil.symbolString );
  }

  
  private static function evalLambda ( env : HatchEnv, forms : Array<HatchValue> ) : (HatchValue)
  {
    return switch (forms)
      {
      case [ListV( params ), body] if( params.foreach( HatchValueUtil.isSymbol )):
        FunctionV( unpackSymbols( params ), body, env );

      default: throw 'Malformed lambda expression';
      };
  }

  private static function evalIf ( env : HatchEnv, forms : Array<HatchValue> ) : (HatchValue)
  {
    return switch ( eval( env, forms[0] ))
      {
      case BoolV(true): eval( env, forms[1]);
      case BoolV(false): eval( env, forms[2]);
      default: throw "Error: malformed if form";
      };
  }

  private static function evalDefine (env : HatchEnv, forms : Array<HatchValue>)
  {
    return switch (forms[0])
      {
      case SymbolV(s) if (env.defined(s)): throw 'cannot redefine symbol ${forms[0]} in current context';
      case SymbolV(s):
	{
	  env.bind(s, eval(env, forms[1]));
	  forms[0];
	}
      default: throw 'define takes a symbolic first argument';
      }
  }

  private static function validRestArgs ( params: Array<String>, args : Array<HatchValue> ) : (Bool)
  {
    return params.length > 0 && params[params.length -1] == 'rest&' && (params.length - 1) <= args.length;
  }

  private static function restArgs ( args0 : Array<HatchValue>, params : Array<String>) : Array<HatchValue>
  {
    var args = args0.copy();
    var newArgs = [];
    for (p in params)
      {
        if (p == 'rest&')
          {
            newArgs.push(ListV(args));
          }
        else
          {
            newArgs.push( args.shift() );
          }
      }
    return newArgs;
  }

  private static function validPartial( params : Array<String>, args : Array<HatchValue>) : (Bool)
  {
    var hasBlanks = args.exists( HatchValueUtil.isBlank );
    return params.length > args.length || (hasBlanks && params.length >= args.length);
  }    
  
  public static function apply (v : HatchValue , args : Array<HatchValue>) : (HatchValue)
  {
    return switch (v)
      {
      case PrimOpV(op):  op( args );
	
      case FunctionV( params, body, env) if (validRestArgs( params, args )): 
	callFunction( env, params, restArgs( args, params ), body);
	
      case FunctionV( params, body, env) if (validPartial( params, args)):
	makePartial( env, params, args, body);
        
      case FunctionV( params, body, env ) if (params.length == args.length): 
	callFunction( env, params, args, body );

      default: throw 'Error, cannot apply form to supplied arguments';
      }
  }

  public static function callFunction( env : HatchEnv,
                                        params : Array<String>,
                                        args : Array<HatchValue>,
                                        body : HatchValue) : (HatchValue)
  {
    var callEnv = env.extend( params, args );
    return eval( callEnv, body );
  }


  public static function makePartial ( env : HatchEnv,
                                       params: Array<String>,
                                       args: Array<HatchValue>,
                                       body : HatchValue) : (HatchValue)
  {
    var boundParams = [];
    var unboundParams = params.slice( args.length );
    var bindingArgs = [];
    
    for (i in 0...args.length)
      {
        switch (args[i]) {
        case SymbolV('_'):
          {
            unboundParams.unshift(params[i]);
          }
        default:
          {
            boundParams.push(params[i]);
            bindingArgs.push(args[i]);
          }
        }
      }

    var partialEnv = env.extend( boundParams, bindingArgs);
    return FunctionV( unboundParams, body, partialEnv);
    // var partialEnv = env.extend( params.slice(0, args.length), args);
    // return FunctionV(params.slice( args.length ), body, partialEnv);

  }
  
  public static function main () {
    trace('moo');
  }

  
}



