export class XmlBuilder {
  static buildPropfind(properties: string[]): string {
    let xml: string = '<?xml version="1.0" encoding="utf-8"?>';
    xml += '<d:propfind xmlns:d="DAV:">';
    if (properties.length === 0) {
      xml += '<d:allprop/>';
    } else {
      xml += '<d:prop>';
      for (let i = 0; i < properties.length; i++) {
        xml += '<d:' + properties[i] + '/>';
      }
      xml += '</d:prop>';
    }
    xml += '</d:propfind>';
    return xml;
  }

  static buildProppatch(setProps: Record<string, string>, removeProps: string[]): string {
    let xml: string = '<?xml version="1.0" encoding="utf-8"?>';
    xml += '<d:propertyupdate xmlns:d="DAV:">';
    const setKeys: string[] = Object.keys(setProps);
    if (setKeys.length > 0) {
      xml += '<d:set><d:prop>';
      for (let i = 0; i < setKeys.length; i++) {
        xml += '<d:' + setKeys[i] + '>' + setProps[setKeys[i]] + '</d:' + setKeys[i] + '>';
      }
      xml += '</d:prop></d:set>';
    }
    if (removeProps.length > 0) {
      xml += '<d:remove><d:prop>';
      for (let i = 0; i < removeProps.length; i++) {
        xml += '<d:' + removeProps[i] + '/>';
      }
      xml += '</d:prop></d:remove>';
    }
    xml += '</d:propertyupdate>';
    return xml;
  }

  static buildLockRequest(owner: string, scope: string): string {
    let xml: string = '<?xml version="1.0" encoding="utf-8"?>';
    xml += '<d:lockinfo xmlns:d="DAV:">';
    if (scope === 'exclusive') {
      xml += '<d:lockscope><d:exclusive/></d:lockscope>';
    } else {
      xml += '<d:lockscope><d:shared/></d:lockscope>';
    }
    xml += '<d:locktype><d:write/></d:locktype>';
    xml += '<d:owner><d:href>' + owner + '</d:href></d:owner>';
    xml += '</d:lockinfo>';
    return xml;
  }
}
