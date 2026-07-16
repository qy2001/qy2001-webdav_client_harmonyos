import { convertxml } from '@kit.ArkTS';
import { WebDavResource } from '../model/WebDavResource';

export class XmlParser {
  private static OPTIONS: convertxml.ConvertOptions = {
    trim: false,
    declarationKey: '_declaration',
    instructionKey: '_instruction',
    attributesKey: '_attributes',
    textKey: '_text',
    cdataKey: '_cdata',
    doctypeKey: '_doctype',
    commentKey: '_comment',
    parentKey: '_parent',
    typeKey: '_type',
    nameKey: '_name',
    elementsKey: '_elements',
  };

  static parseToJson(xmlString: string): Record<string, Object> {
    const conv = new convertxml.ConvertXML();
    const result: Record<string, Object> = conv.convertToJSObject(xmlString, XmlParser.OPTIONS) as Record<string, Object>;
    return result;
  }

  static parseMultiStatus(xmlString: string): WebDavResource[] {
    const resources: WebDavResource[] = [];
    try {
      const json: Record<string, Object> = XmlParser.parseToJson(xmlString);
      const elements: Object[] | undefined = XmlParser.getElements(json);
      if (elements === undefined) {
        return resources;
      }
      for (let i = 0; i < elements.length; i++) {
        const element: Record<string, Object> = elements[i] as Record<string, Object>;
        const name: string | undefined = element[XmlParser.OPTIONS.nameKey as string] as string | undefined;
        if (name === 'multistatus') {
          const innerElements: Object[] | undefined = XmlParser.getElements(element);
          if (innerElements !== undefined) {
            XmlParser.parseResponses(innerElements, resources);
          }
        }
      }
    } catch (e) {
    }
    return resources;
  }

  private static parseResponses(elements: Object[], resources: WebDavResource[]): void {
    for (let i = 0; i < elements.length; i++) {
      const element: Record<string, Object> = elements[i] as Record<string, Object>;
      const name: string | undefined = element[XmlParser.OPTIONS.nameKey as string] as string | undefined;
      if (name === 'response') {
        const resource: WebDavResource = XmlParser.parseResponse(element);
        resources.push(resource);
      }
    }
  }

  private static parseResponse(element: Record<string, Object>): WebDavResource {
    const resource: WebDavResource = new WebDavResource();
    const children: Object[] | undefined = XmlParser.getElements(element);
    if (children === undefined) {
      return resource;
    }
    for (let i = 0; i < children.length; i++) {
      const child: Record<string, Object> = children[i] as Record<string, Object>;
      const name: string | undefined = child[XmlParser.OPTIONS.nameKey as string] as string | undefined;
      if (name === 'href') {
        resource.href = XmlParser.getTextContent(child);
      } else if (name === 'propstat') {
        XmlParser.parsePropStat(child, resource);
      }
    }
    if (resource.href.length > 0 && resource.href.charAt(resource.href.length - 1) === '/') {
      resource.isDirectory = true;
    }
    return resource;
  }

  private static parsePropStat(element: Record<string, Object>, resource: WebDavResource): void {
    const children: Object[] | undefined = XmlParser.getElements(element);
    if (children === undefined) {
      return;
    }
    for (let i = 0; i < children.length; i++) {
      const child: Record<string, Object> = children[i] as Record<string, Object>;
      const name: string | undefined = child[XmlParser.OPTIONS.nameKey as string] as string | undefined;
      if (name === 'status') {
        resource.status = XmlParser.getTextContent(child);
      } else if (name === 'prop') {
        XmlParser.parseProp(child, resource);
      }
    }
  }

  private static parseProp(element: Record<string, Object>, resource: WebDavResource): void {
    const children: Object[] | undefined = XmlParser.getElements(element);
    if (children === undefined) {
      return;
    }
    for (let i = 0; i < children.length; i++) {
      const child: Record<string, Object> = children[i] as Record<string, Object>;
      const name: string | undefined = child[XmlParser.OPTIONS.nameKey as string] as string | undefined;
      if (name === 'resourcetype') {
        const rtChildren: Object[] | undefined = XmlParser.getElements(child);
        if (rtChildren !== undefined) {
          for (let j = 0; j < rtChildren.length; j++) {
            const rtChild: Record<string, Object> = rtChildren[j] as Record<string, Object>;
            const rtName: string | undefined = rtChild[XmlParser.OPTIONS.nameKey as string] as string | undefined;
            if (rtName === 'collection') {
              resource.isDirectory = true;
              resource.resourceType = 'collection';
            }
          }
        }
      } else if (name === 'displayname') {
        resource.displayName = XmlParser.getTextContent(child);
      } else if (name === 'creationdate') {
        resource.creationDate = XmlParser.getTextContent(child);
      } else if (name === 'getlastmodified') {
        resource.lastModified = XmlParser.getTextContent(child);
      } else if (name === 'getcontentlength') {
        const len: string = XmlParser.getTextContent(child);
        if (len.length > 0) {
          resource.contentLength = parseInt(len, 10);
        }
      } else if (name === 'getcontenttype') {
        resource.contentType = XmlParser.getTextContent(child);
      } else if (name === 'getetag') {
        resource.etag = XmlParser.getTextContent(child);
      }
    }
  }

  private static getElements(obj: Record<string, Object>): Object[] | undefined {
    const elementsKey: string = XmlParser.OPTIONS.elementsKey as string;
    const val: Object | undefined = obj[elementsKey];
    if (val !== undefined && val instanceof Array) {
      return val as Object[];
    }
    return undefined;
  }

  private static getTextContent(element: Record<string, Object>): string {
    const children: Object[] | undefined = XmlParser.getElements(element);
    if (children === undefined) {
      return '';
    }
    for (let i = 0; i < children.length; i++) {
      const child: Record<string, Object> = children[i] as Record<string, Object>;
      const type: string | undefined = child[XmlParser.OPTIONS.typeKey as string] as string | undefined;
      if (type === 'text') {
        const text: string | undefined = child[XmlParser.OPTIONS.textKey as string] as string | undefined;
        return text ?? '';
      }
    }
    return '';
  }
}
