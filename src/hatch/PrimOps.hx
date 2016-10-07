package hatch;

import hatch.HatchValue.HatchValue;
using hatch.HatchValueUtil;
using Lambda;


class PrimOps
{


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

  // public static function mod (args : Array<HatchValue>) : (HatchValue)
  // {
    
  // }


  // public static function sin (args : Array<HatchValue>) : (HatchValue)
  // {
    
  // }
  
  // public static function cos (args : Array<HatchValue>) : (HatchValue)
  // {

  // }

  // public static function tan (args : Array<HatchValue>) : (HatchValue)
  // {
    
  // }


  // public static function tan (args : Array<HatchValue>) : (HatchValue)
  // {
    
  // }

  
  
}