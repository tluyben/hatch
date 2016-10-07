package hatch;

import hatch.HatchValue.HatchValue;

class HatchValueUtil {

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

  
  
}