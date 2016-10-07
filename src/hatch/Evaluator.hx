package hatch;

import hatch.HatchValue.HatchValue;

using Lambda;
using hatch.HatchValueUtil;

class Evaluator {

  public static var prelude : HatchEnv;
  
  public static function init () {
    if (prelude == null) {
      prelude = new HatchEnv();

      prelude.bind('+', wrapPrimOp(2, PrimOps.add));
      prelude.bind('-', wrapPrimOp(2, PrimOps.sub));
      prelude.bind('*', wrapPrimOp(2, PrimOps.mul));
      prelude.bind('/', wrapPrimOp(2, PrimOps.div));
      
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
      case SymbolV('quote'): vs[1];

      case SymbolV('if') if( vs.length == 4): evalIf( env, vs.slice( 1 ) );

      case SymbolV('lambda'), SymbolV('->') if (vs.length == 3): evalLambda( env , vs.slice( 1 ));

      case SymbolV('let') if (vs.length == 3): evalLet( env, vs.slice( 1 ));
        
      case PrimOpV(_): apply( head, [ for (v in vs.slice(1)) eval( env , v )]);

      case FunctionV(_,_,_): apply( head, [for (v in vs.slice(1)) eval( env, v)]);

      default: apply( eval(env, head), [for (v in vs.slice(1)) eval( env, v )]);
        
      }
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
      default: throw "Error: malformed if form: (if bool then-form else-form)";
      };
  }

  private static function validRestArgs ( params: Array<String>, args : Array<HatchValue> ) : (Bool)
  {
    return params.length > 0 && params[params.length -1] == 'rest&' && params.length <= args.length;
  }

  private static function restArgs ( args : Array<HatchValue>, i : Int) : Array<HatchValue>
  {
    var newArgs = args.slice(0, i);
    newArgs.push( ListV( args.slice(i) ) );
    return newArgs;
  }
  
  private static function apply (v : HatchValue , args : Array<HatchValue>) : (HatchValue)
  {
    return switch (v)
      {
      case PrimOpV(op): op( args );
        
      case FunctionV( params, body, env ) if (params.length == args.length):
        callFunction( env, params, args, body );
        
      case FunctionV( params, body, env) if (validRestArgs( params, args )):
        callFunction( env, params, restArgs( args, params.length), body);

      case FunctionV( params, body, env) if (params.length > args.length):
        makePartial( env, params, args, body);
        
      default: throw 'Error, cannot apply $v to supplied arguments';
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

    var partialEnv = env.extend( params.slice(0, args.length), args);
    return FunctionV(params.slice( args.length ), body, partialEnv);

  }
  
  public static function main () {
    trace('moo');
  }

  
}



