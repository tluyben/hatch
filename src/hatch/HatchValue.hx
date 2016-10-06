package hatch;


enum HatchValue {
  SymbolV(a : String);
  ListV(l : Array<HatchValue>);
  IntV(i : Int);
  FloatV(f : Float);
  StringV(s : String);
  BoolV(b : Bool);
}

