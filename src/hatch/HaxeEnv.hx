package hatch;

import haxe.ds.Either;

using Lambda;

enum HaxeResolved {
  ResolvedValue(v : Dynamic);
  ResolvedMethodCall(ob : Dynamic, method : Dynamic);
  ResolvedClassInstantiation(cl: Class<Dynamic>);
  //  ResolvedEnumInstantiation(en:
}

class HaxeEnv
{



  
  private static var table : Map<String,Dynamic>;

  public static function init () {
    if (table == null)
      {
        table = new Map();
      }
  }

  private static function unpackClass (h : HaxeResolved)
  {
    return switch (h)
      {
      case ResolvedClassInstantiation(c): c;
      default: throw 'not a class $h';
      }
  }
  
  public static function set (s : String, v : Dynamic) : (Void)
  {
    table.set(s,v);
  }

  private static var variableRegexString : String = "[_a-zA-Z][_a-zA-Z0-9]*";
  private static var variableRegex : EReg;
  private static function isValidVariable ( s : String) : (Bool)
  {
    if (variableRegex == null)
      {
        variableRegex = new EReg( '^' + variableRegexString + "$",'');
      }
    
    return variableRegex.match( s );
  }

  private static var typePathRegexString = "([a-z][a-z_]*\\.)*([A-Z][A-Za-z_0-9]*\\.)?([A-Z][A-Za-z_0-9]*)";
  private static var typePathRegex : EReg;
  private static function isTypeName ( p : String )
  {
    if (typePathRegex == null)
      {
        typePathRegex = new EReg( '^' + typePathRegexString + "$" ,'');
      }
    return typePathRegex.match( p );

  }

  private static var classAttributePathString : String;
  private static var classAttributePathRegex : EReg;
  private static function isClassAttributePath ( p : String) : (Bool)
  {
    if (classAttributePathRegex == null)
      {
        classAttributePathString = '$typePathRegexString\\.($variableRegexString\\.)*$variableRegexString';
        classAttributePathRegex = new EReg( '^' + classAttributePathString + "$" ,'');
      }
    return classAttributePathRegex.match( p );
  }

  private static var objectAttributePath : String;
  private static var objectAttributePathRegex : EReg;
  private static function isObjectAttributePath (p : String) : (Bool)
  {
    if (objectAttributePathRegex == null)
      {
	objectAttributePath = '($variableRegexString\\.)+$variableRegexString';
	objectAttributePathRegex = new EReg( "^" + objectAttributePath + "$", '');
      }
    return objectAttributePathRegex.match( p );
  }
  
  public static function resolveHaxeReference ( symbol : String ) : (HaxeResolved)
  {
    if (isTypeName( symbol ))
      {
        return resolveTypePath( symbol );
      }
    else if (isClassAttributePath( symbol ))
      {
        return resolveClassAttribReference( symbol );
      }
    else if (isObjectAttributePath( symbol ))
      {
        return resolveObjectAttributePath( symbol );
      }
    else  if ( isValidVariable( symbol) )
      {
        return ResolvedValue( table.get( symbol ) );
      }

      {
        throw 'invalid Haxe reference: $symbol';
      }
  }
  
  private static function resolveTypePath ( path : String ) : (Dynamic)
  {
    if (table.exists( path ))
      {
        return table.get( path );
      }
    else
      {
        var cl = Type.resolveClass( path );
        if (cl != null)
          {
            table.set( path, ResolvedClassInstantiation(cl));
            return ResolvedClassInstantiation( cl );
          }
        else
          {
            // var en = Type.resolveEnum( path );
            // if ( en != null )
            //   {
            //     table.set( path, cl);
            //     return cl;
            //   }
            // else
            //   {
	    throw 'Cannot resolve symbol $path';
		//              }
          }
      }
  } 
  
  private static function getFields ( o : Dynamic ) : Array<String>
  {
    return switch (Type.typeof( o ))
      {
      case TObject if (Type.getClass( o ) == null): Reflect.fields( o );
      case TObject: Type.getInstanceFields( o );
      case TClass(_): {
        var fields = Type.getClassFields( o );
        var o = Type.getSuperClass( o );
        while (o != null)
          {
            fields = fields.concat( Type.getClassFields( o ));
            o = Type.getSuperClass( o );
          }
        fields;
      }
      default: [];
      };
  }
  
  private static function resolveClassAttribReference ( path : String ) : (Dynamic)
  {
    var parts = path.split('.');
    var typeParts : Array<String> = [];
    while ( parts.length > 0 && (parts[0] == parts[0].toLowerCase()))
      {
        typeParts.push( parts.shift() );
      }
    typeParts.push( parts.shift() ); // should get the class part
    // resolveTypePath throws error if type doesn't resolve.
    var target : Dynamic = unpackClass(resolveTypePath( typeParts.join('.') ));
    var attrib : Dynamic = target;
    while ( parts.length > 0 )
      {
        var attribute = parts.shift();
	target = attrib;
        if ( getFields( target ).has( attribute ))
          {
            attrib = Reflect.field( target, attribute);
          }
        else
          {
            throw 'could not resolve path $path due to bad attribute';
          }            
      }
    return switch (Type.typeof( attrib ))
      {
      case TFunction: ResolvedMethodCall( target, attrib );
      default: ResolvedValue( attrib );
      };
  }        

  private static function resolveObjectAttributePath ( path : String ) : (Dynamic)
  {
    var parts = path.split('.');
    var attribute = parts.shift();
    var target : Dynamic = table.get( attribute );
    var attrib : Dynamic = target;
    if (target != null)
      {
	while (parts.length > 0)
	  {
	    attribute = parts.shift();
	    attrib = target;
	    if ( getFields( target ).has( attribute ) )
	      {
		attrib = Reflect.field( target, attribute );
	      }
	    else
	      {
		throw 'could not resolve $path due to bad attribute $attribute';
	      }
	  }
	return switch (Type.typeof( attrib ))
	  {
	  case TFunction: ResolvedMethodCall(target, attrib);
	  default: ResolvedValue( attrib );
	  };
      }
    else
      {
	throw 'unknown reference $attribute';
      }
  }


  public static function evaluate( symbol : String, args : Array<Dynamic>) : (Dynamic)
  {
    return switch (resolveHaxeReference( symbol ) )
      {
      case ResolvedValue(v): v;
      case ResolvedMethodCall(t,m): Reflect.callMethod( t, m, args);
      case ResolvedClassInstantiation(c): Type.createInstance(c, args);
      }
  }



  public static function main ()
  {
    var validVar = isValidVariable('foobar');
    var validVar2 = isValidVariable('FOOBAR');    
    var validClassAttrib = isClassAttributePath('Math.sin');
    var validClass = isTypeName('foo.bar.Goo');
    var otherVlaidClass = isTypeName('Goo');
    var validObjectAttrib = isObjectAttributePath('foo.bar.zooGar');
   trace('validVar foobar = $validVar');
   trace('validVar2 FOOBAR = $validVar2');   
   trace('validClassAttrib Math.sin = $validClassAttrib');
   trace('validClass foo.bar.Goo = $validClass');
   trace('otherVlaidClass Goo = $otherVlaidClass');
   trace('validObjectAttrib foo.bar.zooGar = $validObjectAttrib');
  }


}