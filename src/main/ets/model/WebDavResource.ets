export class WebDavResource {
  href: string = '';
  isDirectory: boolean = false;
  displayName: string = '';
  creationDate: string = '';
  lastModified: string = '';
  contentLength: number = 0;
  contentType: string = '';
  etag: string = '';
  status: string = '';
  resourceType: string = '';
  fullUrl: string = '';
  authHeaders: Record<string, string> = {} as Record<string, string>;

  static create(href: string): WebDavResource {
    const r = new WebDavResource();
    r.href = href;
    return r;
  }

  static createWithBaseUrl(href: string, baseUrl: string): WebDavResource {
    const r = new WebDavResource();
    r.href = href;
    r.fullUrl = resolveFullUrl(href, baseUrl);
    return r;
  }
}

function resolveFullUrl(href: string, baseUrl: string): string {
  if (href.startsWith('http://') || href.startsWith('https://')) {
    return href;
  }
  if (baseUrl.charAt(baseUrl.length - 1) === '/' && href.charAt(0) === '/') {
    return baseUrl + href.substring(1);
  }
  if (baseUrl.charAt(baseUrl.length - 1) !== '/' && href.charAt(0) !== '/') {
    return baseUrl + '/' + href;
  }
  return baseUrl + href;
}
