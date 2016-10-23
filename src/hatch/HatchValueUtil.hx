package hatch;

import hatch.HatchValue.HatchValue;

class HatchValueUtil
{
  
  public static function equal( v1 : HatchValue, v2 : HatchValue) : (Bool) {
    switch ([v1,v2]) {
    case [ListV(a1), ListV(a2)] if (a1.length == a2.length):
      {
        for (i in 0...a1.length)
          {
            if (!equal( a1[i], a2[i] ))
              {
                return false;
              }
          }
        return true;
      }
    default: return Type.enumEq( v1, v2 );
    }
  }

  public static function isBlank (v : HatchValue) : (Bool)
  {
    return equal(SymbolV('_'),v);
  }
  
  public static function isSymbol ( s : HatchValue ) : (Bool)
  {
    return switch (s)
      {
      case SymbolV(_): true;
      default: false;
      };
  }

  public static function isList ( v : HatchValue) : (Bool)
  {
    return switch (v)
      {
      case ListV(_): true;
      default: false;
      }
  }

  public static function isInt (v : HatchValue) : (Bool)
  {
    return switch (v)
      {
      case IntV(_): true;
      default: false;
      }
  }

  public static function isFloat (v : HatchValue) :(Bool)
  {
    return switch (v)
      {
      case FloatV(_): true;
      default: false;
      }
  }

  public static function isNumeric (v : HatchValue) : (Bool)
  {
    return isInt( v ) || isFloat( v );
  }

  public static function isString ( v : HatchValue) : (Bool)
  {
    return switch (v)
      {
      case StringV(_): true;
      default: false;
      }
  }

  public static function isBool ( v : HatchValue) : (Bool)
  {
    return switch (v)
      {
      case BoolV(_): true;
      default: false;
      }
  }

  public static function isFunctional ( v : HatchValue) : (Bool)
  {
    return switch (v)
      {
      case FunctionV(_,_,_): true;
      case PrimOpV(_):true;
      default: false;
      }
  }

  public static function listContents ( v : HatchValue) : Array<HatchValue>
  {
    return switch (v) {
    case ListV(contents) : contents;
    default: throw  "Cannot unpack list contents from non list form";
    }
  }

  public static function symbolString (s : HatchValue) : (String)
  {
    return switch (s)
      {
      case SymbolV(s): s;
      default: throw "Error: failed to stringify non-symbol";
      }
  }

  public static function fromHaxe ( v : Dynamic ) : (HatchValue)
  {
    return switch (Type.typeof(v))
      {
      case TInt: IntV(v);
      case TFloat: FloatV(v);
      case TBool: BoolV(v);
      default: if (Std.is( v, String)) StringV(v) else HaxeV( v );
      }
  }
  
  public static function toHaxe ( v : HatchValue ) : (Dynamic)
  {
    return switch (v) {
    case SymbolV( a ) : a;
    case IntV(i): i;
    case FloatV(f):f;
    case BoolV(b):b;
    case ListV(a): a.map( toHaxe );
    case HaxeV(d): d;
    case StringV(s) : s;
    default: null;              // no support (yet) for demarshalling functionals 
    }
  }
  
  public static function show ( v : HatchValue ) : (String)
  {
    return switch (v)
      {
      case SymbolV( a ) : '$a';
      case IntV(i): '$i';
      case StringV(s): '"$s"';
      case FloatV(f): '$f';
      case BoolV(b): if (b) '#t' else '#f';
      case ListV(a): '(${a.map( show ).join(' ')})';
      case PrimOpV(_): "#<PrimOp>#";
      case FunctionV(params,_,_): '#<function ${params.length}>#';
      case HaxeOpV(_): '#<Haxe operation>';
      case HaxeV(d): 'Haxe{$d}';
      };
  }
  
}