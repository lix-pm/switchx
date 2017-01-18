package switchx;

using StringTools;

enum UserVersionData {
  UEdge;
  ULatest;
  UStable;
  UNightly(hash:String);
  UOfficial(version:String);
  
}

enum ResolvedUserVersionData {
  RNightly(hash:String, date:Date);
  ROfficial(version:String);
}

abstract ResolvedVersion(ResolvedUserVersionData) from ResolvedUserVersionData to ResolvedUserVersionData {
  
  public var id(get, never):String;
  
    function get_id()
      return switch this {
        case RNightly(v, _): v;
        case ROfficial(v): v;
      }
      
}

abstract UserVersion(UserVersionData) from UserVersionData to UserVersionData {
  
  static var hex = [for (c in '0123456789abcdefABCDEF'.split('')) c.charCodeAt(0) => true];
  
  @:from static function ofResolved(v:ResolvedVersion):UserVersion
    return switch v {
      case ROfficial(version): UOfficial(version);
      case RNightly(version, _): UNightly(version);
    }
  
  static public function isHash(version:String) {
    
    for (i in 0...version.length)
      if (!hex[version.fastCodeAt(i)])
        return false;
        
    return true;
  }  
  
  @:from static public function ofString(s:Null<String>):UserVersion
    return 
      if (s == null) null;
      else switch s {
        case 'auto': null;
        case 'edge': UEdge;
        case 'latest': ULatest;
        case 'stable': UStable;
        case isHash(_) => true: UNightly(s);
        default: UOfficial(s);//TODO: check if this is valid?
      }
  
}