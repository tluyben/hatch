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
  
}