import { WebDavConfig, DefaultWebDavConfig, PartialWebDavConfig } from './model/WebDavConfig';
import { AuthType } from './model/AuthType';
import { WebDavResource } from './model/WebDavResource';
import { WebDavResponse } from './model/WebDavResponse';
import { IAuthProvider } from './auth/IAuthProvider';
import { BasicAuthProvider } from './auth/BasicAuthProvider';
import { BearerAuthProvider } from './auth/BearerAuthProvider';
import { DigestAuthProvider } from './auth/DigestAuthProvider';
import { CustomAuthProvider } from './auth/CustomAuthProvider';
import { HttpClient, RequestOptions, OnUploadProgress } from './http/HttpClient';
import { XmlParser } from './parser/XmlParser';
import { XmlBuilder } from './utils/XmlBuilder';

export class WebDavClient {
  private config: WebDavConfig;
  private httpClient: HttpClient;
  private authProvider: IAuthProvider | undefined = undefined;

  constructor(config: WebDavConfig) {
    this.config = config;
    this.authProvider = this.createAuthProvider(config);
    this.httpClient = new HttpClient(config, this.authProvider);
  }

  static fromPartial(partial: PartialWebDavConfig): WebDavClient {
    const config: WebDavConfig = DefaultWebDavConfig.create(partial);
    return new WebDavClient(config);
  }

  async list(path: string, depth: string): Promise<WebDavResponse<WebDavResource[]>> {
    const xmlBody: string = XmlBuilder.buildPropfind([]);
    const extraHeaders: Record<string, string> = {} as Record<string, string>;
    const rawResponse: WebDavResponse<string> = await this.httpClient.propfind(path, xmlBody, depth, extraHeaders);
    return this.parseResourceResponse(rawResponse);
  }

  async stat(path: string): Promise<WebDavResponse<WebDavResource>> {
    const xmlBody: string = XmlBuilder.buildPropfind([
      'resourcetype', 'displayname', 'creationdate', 'getlastmodified',
      'getcontentlength', 'getcontenttype', 'getetag'
    ]);
    const extraHeaders: Record<string, string> = {} as Record<string, string>;
    const rawResponse: WebDavResponse<string> = await this.httpClient.propfind(path, xmlBody, '0', extraHeaders);
    return this.parseSingleResourceResponse(rawResponse);
  }

  async mkdir(path: string): Promise<WebDavResponse<void>> {
    const extraHeaders: Record<string, string> = {} as Record<string, string>;
    const rawResponse: WebDavResponse<string> = await this.httpClient.mkcol(path, extraHeaders);
    return this.voidResponse(rawResponse);
  }

  async delete(path: string): Promise<WebDavResponse<void>> {
    const extraHeaders: Record<string, string> = {} as Record<string, string>;
    const rawResponse: WebDavResponse<string> = await this.httpClient.delete(path, extraHeaders);
    return this.voidResponse(rawResponse);
  }

  async get(path: string): Promise<WebDavResponse<string>> {
    const extraHeaders: Record<string, string> = {} as Record<string, string>;
    return this.httpClient.get(path, extraHeaders);
  }

  async put(path: string, content: string, contentType: string): Promise<WebDavResponse<void>> {
    const extraHeaders: Record<string, string> = {} as Record<string, string>;
    const rawResponse: WebDavResponse<string> = await this.httpClient.put(path, content, contentType, extraHeaders);
    return this.voidResponse(rawResponse);
  }

  async putBinary(path: string, content: ArrayBuffer, contentType: string): Promise<WebDavResponse<void>> {
    const extraHeaders: Record<string, string> = {} as Record<string, string>;
    const rawResponse: WebDavResponse<string> = await this.httpClient.putBinary(path, content, contentType, extraHeaders);
    return this.voidResponse(rawResponse);
  }

  setOnUploadProgress(callback: OnUploadProgress): void {
    this.httpClient.setOnUploadProgress(callback);
  }

  async copy(srcPath: string, destPath: string, overwrite: boolean): Promise<WebDavResponse<void>> {
    const extraHeaders: Record<string, string> = {} as Record<string, string>;
    const rawResponse: WebDavResponse<string> = await this.httpClient.copy(srcPath, destPath, overwrite, extraHeaders);
    return this.voidResponse(rawResponse);
  }

  async move(srcPath: string, destPath: string, overwrite: boolean): Promise<WebDavResponse<void>> {
    const extraHeaders: Record<string, string> = {} as Record<string, string>;
    const rawResponse: WebDavResponse<string> = await this.httpClient.move(srcPath, destPath, overwrite, extraHeaders);
    return this.voidResponse(rawResponse);
  }

  async proppatch(path: string, setProps: Record<string, string>, removeProps: string[]): Promise<WebDavResponse<Record<string, string>>> {
    const xmlBody: string = XmlBuilder.buildProppatch(setProps, removeProps);
    const extraHeaders: Record<string, string> = {} as Record<string, string>;
    const rawResponse: WebDavResponse<string> = await this.httpClient.proppatch(path, xmlBody, extraHeaders);
    const result: WebDavResponse<Record<string, string>> = new WebDavResponse<Record<string, string>>();
    result.statusCode = rawResponse.statusCode;
    result.statusText = rawResponse.statusText;
    result.headers = rawResponse.headers;
    result.rawXml = rawResponse.rawXml;
    result.isError = rawResponse.isError;
    result.errorMessage = rawResponse.errorMessage;
    if (!rawResponse.isError && rawResponse.rawXml.length > 0) {
      try {
        const json: Record<string, Object> = XmlParser.parseToJson(rawResponse.rawXml);
        result.data = json as Record<string, string>;
      } catch (e) {
        result.data = {} as Record<string, string>;
      }
    }
    return result;
  }

  async lock(path: string, owner: string): Promise<WebDavResponse<string>> {
    const xmlBody: string = XmlBuilder.buildLockRequest(owner, 'exclusive');
    const extraHeaders: Record<string, string> = {} as Record<string, string>;
    const rawResponse: WebDavResponse<string> = await this.httpClient.lock(path, xmlBody, extraHeaders);
    if (!rawResponse.isError) {
      const lockToken: string | undefined = rawResponse.headers['Lock-Token'];
      if (lockToken !== undefined && lockToken.length > 0) {
        let token: string = lockToken;
        if (token.charAt(0) === '<' && token.charAt(token.length - 1) === '>') {
          token = token.substring(1, token.length - 1);
        }
        rawResponse.data = token;
      }
    }
    return rawResponse;
  }

  async unlock(path: string, lockToken: string): Promise<WebDavResponse<void>> {
    const extraHeaders: Record<string, string> = {} as Record<string, string>;
    const rawResponse: WebDavResponse<string> = await this.httpClient.unlock(path, lockToken, extraHeaders);
    return this.voidResponse(rawResponse);
  }

  async checkConnection(): Promise<boolean> {
    try {
      const response: WebDavResponse<WebDavResource> = await this.stat('/');
      return !response.isError;
    } catch (e) {
      return false;
    }
  }

  destroy(): void {
    this.httpClient.destroy();
  }

  getConfig(): WebDavConfig {
    return this.config;
  }

  getUrl(path: string): string {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    let base: string = this.config.baseUrl;
    if (base.charAt(base.length - 1) === '/' && path.charAt(0) === '/') {
      return base + path.substring(1);
    }
    if (base.charAt(base.length - 1) !== '/' && path.charAt(0) !== '/') {
      return base + '/' + path;
    }
    return base + path;
  }

  private createAuthProvider(config: WebDavConfig): IAuthProvider | undefined {
    if (config.authType === AuthType.BASIC) {
      return new BasicAuthProvider(config.username, config.password);
    } else if (config.authType === AuthType.BEARER) {
      return new BearerAuthProvider(config.token);
    } else if (config.authType === AuthType.DIGEST) {
      return new DigestAuthProvider(config.username, config.password);
    } else if (config.authType === AuthType.CUSTOM) {
      return new CustomAuthProvider(config.customHeaders);
    }
    return undefined;
  }

  private parseResourceResponse(rawResponse: WebDavResponse<string>): WebDavResponse<WebDavResource[]> {
    const result: WebDavResponse<WebDavResource[]> = new WebDavResponse<WebDavResource[]>();
    result.statusCode = rawResponse.statusCode;
    result.statusText = rawResponse.statusText;
    result.headers = rawResponse.headers;
    result.rawXml = rawResponse.rawXml;
    result.isError = rawResponse.isError;
    result.errorMessage = rawResponse.errorMessage;
    if (!rawResponse.isError && rawResponse.rawXml.length > 0) {
      result.data = XmlParser.parseMultiStatus(rawResponse.rawXml);
      this.fillFullUrls(result.data);
    }
    return result;
  }

  private parseSingleResourceResponse(rawResponse: WebDavResponse<string>): WebDavResponse<WebDavResource> {
    const result: WebDavResponse<WebDavResource> = new WebDavResponse<WebDavResource>();
    result.statusCode = rawResponse.statusCode;
    result.statusText = rawResponse.statusText;
    result.headers = rawResponse.headers;
    result.rawXml = rawResponse.rawXml;
    result.isError = rawResponse.isError;
    result.errorMessage = rawResponse.errorMessage;
    if (!rawResponse.isError && rawResponse.rawXml.length > 0) {
      const resources: WebDavResource[] = XmlParser.parseMultiStatus(rawResponse.rawXml);
      if (resources.length > 0) {
        this.fillFullUrls(resources);
        result.data = resources[0];
      }
    }
    return result;
  }

  private fillFullUrls(resources: WebDavResource[]): void {
    const authHeaders: Record<string, string> = {} as Record<string, string>;
    if (this.authProvider !== undefined) {
      this.authProvider.applyHeaders(authHeaders);
    }
    const origin: string = this.getOrigin();
    for (let i = 0; i < resources.length; i++) {
      resources[i].fullUrl = this.resolveResourceUrl(resources[i].href, origin);
      resources[i].authHeaders = authHeaders;
    }
  }

  private getOrigin(): string {
    const base: string = this.config.baseUrl;
    let end: number = base.indexOf('/', base.indexOf('//') + 2);
    if (end < 0) {
      end = base.length;
    }
    return base.substring(0, end);
  }

  private resolveResourceUrl(href: string, origin: string): string {
    if (href.startsWith('http://') || href.startsWith('https://')) {
      return href;
    }
    if (href.startsWith('/')) {
      return origin + href;
    }
    return this.getUrl(href);
  }

  private voidResponse(rawResponse: WebDavResponse<string>): WebDavResponse<void> {
    const result: WebDavResponse<void> = new WebDavResponse<void>();
    result.statusCode = rawResponse.statusCode;
    result.statusText = rawResponse.statusText;
    result.headers = rawResponse.headers;
    result.rawXml = rawResponse.rawXml;
    result.isError = rawResponse.isError;
    result.errorMessage = rawResponse.errorMessage;
    return result;
  }
}
