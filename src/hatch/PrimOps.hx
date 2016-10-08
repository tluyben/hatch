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