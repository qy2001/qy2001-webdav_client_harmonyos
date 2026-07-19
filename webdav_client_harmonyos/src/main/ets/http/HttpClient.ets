import { rcp } from '@kit.RemoteCommunicationKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { util } from '@kit.ArkTS';
import { WebDavConfig } from '../model/WebDavConfig';
import { WebDavResponse } from '../model/WebDavResponse';
import { IAuthProvider } from '../auth/IAuthProvider';
import { AuthType } from '../model/AuthType';
import { DigestAuthProvider } from '../auth/DigestAuthProvider';

export interface RequestOptions {
  headers: Record<string, string>;
  body: string;
  contentType: string;
  depth: string;
  overwrite: string;
  destination: string;
  timeout: number;
}

export type OnUploadProgress = (totalSize: number, transferredSize: number) => void;

export class HttpClient {
  private session: rcp.Session | undefined = undefined;
  private uploadSession: rcp.Session | undefined = undefined;
  private config: WebDavConfig;
  private authProvider: IAuthProvider | undefined = undefined;
  private uploadProgressCallback: OnUploadProgress | undefined = undefined;

  constructor(config: WebDavConfig, authProvider: IAuthProvider | undefined) {
    this.config = config;
    this.authProvider = authProvider;
    this.initSession();
  }

  private initSession(): void {
    const sessionConfig: rcp.SessionConfiguration = {
      headers: {} as rcp.RequestHeaders,
      requestConfiguration: {
        transfer: {
          autoRedirect: true,
          timeout: {
            connectMs: this.config.timeout,
            transferMs: this.config.timeout,
          },
        },
      },
    };
    this.session = rcp.createSession(sessionConfig);
  }

  private resolveUrl(path: string): string {
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

  async request(method: string, path: string, options: RequestOptions | undefined): Promise<WebDavResponse<string>> {
    if (this.session === undefined) {
      return WebDavResponse.error<string>(0, 'Session is not initialized');
    }
    const fullUrl: string = this.resolveUrl(path);
    const mergedHeaders: Record<string, string> = this.buildHeaders(options);
    const req: rcp.Request = new rcp.Request(fullUrl, method, mergedHeaders as rcp.RequestHeaders);
    if (options !== undefined) {
      if (options.body.length > 0) {
        req.content = options.body;
      }
      if (options.timeout > 0) {
        req.configuration = {
          transfer: {
            timeout: {
              connectMs: options.timeout,
              transferMs: options.timeout,
            },
          },
        };
      }
    }
    try {
      const response: rcp.Response = await this.session.fetch(req);
      const result: WebDavResponse<string> = this.buildResponse(response);
      if (response.statusCode === 401 && this.authProvider !== undefined &&
        this.authProvider.getType() === AuthType.DIGEST) {
        const digestProvider: DigestAuthProvider = this.authProvider as DigestAuthProvider;
        digestProvider.setUri(fullUrl);
        digestProvider.handle401(this.extractResponseHeaders(response));
        const retryHeaders: Record<string, string> = this.buildHeaders(options);
        const retryReq: rcp.Request = new rcp.Request(fullUrl, method, retryHeaders as rcp.RequestHeaders);
        if (options !== undefined && options.body.length > 0) {
          retryReq.content = options.body;
        }
        const retryResponse: rcp.Response = await this.session.fetch(retryReq);
        return this.buildResponse(retryResponse);
      }
      return result;
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      return WebDavResponse.error<string>(err.code ?? 0, err.message ?? 'Request failed');
    }
  }

  async get(path: string, headers: Record<string, string>): Promise<WebDavResponse<string>> {
    const options: RequestOptions = this.createOptions();
    const keys: string[] = Object.keys(headers);
    for (let i = 0; i < keys.length; i++) {
      options.headers[keys[i]] = headers[keys[i]];
    }
    return this.request('GET', path, options);
  }

  async putBinary(path: string, content: ArrayBuffer, contentType: string, headers: Record<string, string>): Promise<WebDavResponse<string>> {
    if (this.session === undefined) {
      return WebDavResponse.error<string>(0, 'Session is not initialized');
    }
    const fullUrl: string = this.resolveUrl(path);
    const options: RequestOptions = this.createOptions();
    options.contentType = contentType;
    const keys: string[] = Object.keys(headers);
    for (let i = 0; i < keys.length; i++) {
      options.headers[keys[i]] = headers[keys[i]];
    }
    const mergedHeaders: Record<string, string> = this.buildHeaders(options);
    const uploadEventHandler: rcp.HttpEventsHandler = {
      onUploadProgress: (totalSize: number, transferredSize: number) => {
        if (this.uploadProgressCallback !== undefined) {
          this.uploadProgressCallback(totalSize, transferredSize);
        }
      },
    };
    const uploadSessionConfig: rcp.SessionConfiguration = {
      headers: mergedHeaders as rcp.RequestHeaders,
      requestConfiguration: {
        transfer: {
          autoRedirect: true,
          timeout: {
            connectMs: this.config.timeout,
            transferMs: this.config.timeout,
          },
        },
        tracing: {
          httpEventsHandler: uploadEventHandler,
        },
      },
    };
    const uploadSess: rcp.Session = rcp.createSession(uploadSessionConfig);
    this.uploadSession = uploadSess;
    const req: rcp.Request = new rcp.Request(fullUrl, 'PUT');
    req.content = content;
    if (contentType.length > 0) {
      req.content = content;
    }
    try {
      const response: rcp.Response = await uploadSess.fetch(req);
      this.closeUploadSession();
      if (response.statusCode === 401 && this.authProvider !== undefined &&
        this.authProvider.getType() === AuthType.DIGEST) {
        const digestProvider: DigestAuthProvider = this.authProvider as DigestAuthProvider;
        digestProvider.setUri(fullUrl);
        digestProvider.handle401(this.extractResponseHeaders(response));
        const retryHeaders: Record<string, string> = this.buildHeaders(options);
        const retryEventHandler: rcp.HttpEventsHandler = {
          onUploadProgress: (totalSize: number, transferredSize: number) => {
            if (this.uploadProgressCallback !== undefined) {
              this.uploadProgressCallback(totalSize, transferredSize);
            }
          },
        };
        const retrySessionConfig: rcp.SessionConfiguration = {
          headers: retryHeaders as rcp.RequestHeaders,
          requestConfiguration: {
            transfer: {
              autoRedirect: true,
              timeout: {
                connectMs: this.config.timeout,
                transferMs: this.config.timeout,
              },
            },
            tracing: {
              httpEventsHandler: retryEventHandler,
            },
          },
        };
        const retrySess: rcp.Session = rcp.createSession(retrySessionConfig);
        this.uploadSession = retrySess;
        const retryReq: rcp.Request = new rcp.Request(fullUrl, 'PUT');
        retryReq.content = content;
        const retryResponse: rcp.Response = await retrySess.fetch(retryReq);
        this.closeUploadSession();
        return this.buildResponse(retryResponse);
      }
      return this.buildResponse(response);
    } catch (e) {
      this.closeUploadSession();
      const err: BusinessError = e as BusinessError;
      return WebDavResponse.error<string>(err.code ?? 0, err.message ?? 'Request failed');
    }
  }

  setOnUploadProgress(callback: OnUploadProgress): void {
    this.uploadProgressCallback = callback;
  }

  private closeUploadSession(): void {
    if (this.uploadSession !== undefined) {
      this.uploadSession.close();
      this.uploadSession = undefined;
    }
  }

  async put(path: string, body: string, contentType: string, headers: Record<string, string>): Promise<WebDavResponse<string>> {
    const options: RequestOptions = this.createOptions();
    options.body = body;
    options.contentType = contentType;
    const keys: string[] = Object.keys(headers);
    for (let i = 0; i < keys.length; i++) {
      options.headers[keys[i]] = headers[keys[i]];
    }
    return this.request('PUT', path, options);
  }

  async delete(path: string, headers: Record<string, string>): Promise<WebDavResponse<string>> {
    const options: RequestOptions = this.createOptions();
    const keys: string[] = Object.keys(headers);
    for (let i = 0; i < keys.length; i++) {
      options.headers[keys[i]] = headers[keys[i]];
    }
    return this.request('DELETE', path, options);
  }

  async mkcol(path: string, headers: Record<string, string>): Promise<WebDavResponse<string>> {
    const options: RequestOptions = this.createOptions();
    const keys: string[] = Object.keys(headers);
    for (let i = 0; i < keys.length; i++) {
      options.headers[keys[i]] = headers[keys[i]];
    }
    return this.request('MKCOL', path, options);
  }

  async propfind(path: string, body: string, depth: string, headers: Record<string, string>): Promise<WebDavResponse<string>> {
    const options: RequestOptions = this.createOptions();
    options.body = body;
    options.contentType = 'application/xml; charset=utf-8';
    options.depth = depth;
    const keys: string[] = Object.keys(headers);
    for (let i = 0; i < keys.length; i++) {
      options.headers[keys[i]] = headers[keys[i]];
    }
    return this.request('PROPFIND', path, options);
  }

  async proppatch(path: string, body: string, headers: Record<string, string>): Promise<WebDavResponse<string>> {
    const options: RequestOptions = this.createOptions();
    options.body = body;
    options.contentType = 'application/xml; charset=utf-8';
    const keys: string[] = Object.keys(headers);
    for (let i = 0; i < keys.length; i++) {
      options.headers[keys[i]] = headers[keys[i]];
    }
    return this.request('PROPPATCH', path, options);
  }

  async copy(srcPath: string, destPath: string, overwrite: boolean, headers: Record<string, string>): Promise<WebDavResponse<string>> {
    const options: RequestOptions = this.createOptions();
    options.destination = destPath;
    options.overwrite = overwrite ? 'T' : 'F';
    const keys: string[] = Object.keys(headers);
    for (let i = 0; i < keys.length; i++) {
      options.headers[keys[i]] = headers[keys[i]];
    }
    return this.request('COPY', srcPath, options);
  }

  async move(srcPath: string, destPath: string, overwrite: boolean, headers: Record<string, string>): Promise<WebDavResponse<string>> {
    const options: RequestOptions = this.createOptions();
    options.destination = destPath;
    options.overwrite = overwrite ? 'T' : 'F';
    const keys: string[] = Object.keys(headers);
    for (let i = 0; i < keys.length; i++) {
      options.headers[keys[i]] = headers[keys[i]];
    }
    return this.request('MOVE', srcPath, options);
  }

  async lock(path: string, body: string, headers: Record<string, string>): Promise<WebDavResponse<string>> {
    const options: RequestOptions = this.createOptions();
    options.body = body;
    options.contentType = 'application/xml; charset=utf-8';
    options.depth = '0';
    const keys: string[] = Object.keys(headers);
    for (let i = 0; i < keys.length; i++) {
      options.headers[keys[i]] = headers[keys[i]];
    }
    return this.request('LOCK', path, options);
  }

  async unlock(path: string, lockToken: string, headers: Record<string, string>): Promise<WebDavResponse<string>> {
    const options: RequestOptions = this.createOptions();
    options.headers['Lock-Token'] = '<' + lockToken + '>';
    const keys: string[] = Object.keys(headers);
    for (let i = 0; i < keys.length; i++) {
      options.headers[keys[i]] = headers[keys[i]];
    }
    return this.request('UNLOCK', path, options);
  }

  destroy(): void {
    if (this.session !== undefined) {
      this.session.close();
      this.session = undefined;
    }
    this.closeUploadSession();
    this.uploadProgressCallback = undefined;
  }

  private buildHeaders(options: RequestOptions | undefined): Record<string, string> {
    const headers: Record<string, string> = {} as Record<string, string>;
    if (this.config.userAgent.length > 0) {
      headers['User-Agent'] = this.config.userAgent;
    }
    if (this.authProvider !== undefined) {
      this.authProvider.applyHeaders(headers);
    }
    if (options !== undefined) {
      if (options.contentType.length > 0) {
        headers['Content-Type'] = options.contentType;
      }
      if (options.depth.length > 0) {
        headers['Depth'] = options.depth;
      }
      if (options.overwrite.length > 0) {
        headers['Overwrite'] = options.overwrite;
      }
      if (options.destination.length > 0) {
        headers['Destination'] = options.destination;
      }
      const keys: string[] = Object.keys(options.headers);
      for (let i = 0; i < keys.length; i++) {
        headers[keys[i]] = options.headers[keys[i]];
      }
    }
    return headers;
  }

  private buildResponse(response: rcp.Response): WebDavResponse<string> {
    let bodyStr: string = '';
    if (response.body !== undefined) {
      if (typeof response.body === 'string') {
        bodyStr = response.body as string;
      } else {
        const decoder: util.TextDecoder = util.TextDecoder.create('utf-8');
        bodyStr = decoder.decodeToString(new Uint8Array(response.body as ArrayBuffer));
      }
    }
    const respHeaders: Record<string, string> = this.extractResponseHeaders(response);
    let statusText: string = '';
    if (response.statusCode >= 200 && response.statusCode < 300) {
      statusText = 'OK';
    } else if (response.statusCode >= 300 && response.statusCode < 400) {
      statusText = 'Redirect';
    } else if (response.statusCode >= 400 && response.statusCode < 500) {
      statusText = 'Client Error';
    } else if (response.statusCode >= 500) {
      statusText = 'Server Error';
    }
    const result: WebDavResponse<string> = new WebDavResponse<string>();
    result.statusCode = response.statusCode;
    result.statusText = statusText;
    result.headers = respHeaders;
    result.data = bodyStr;
    result.rawXml = bodyStr;
    result.isError = response.statusCode >= 400;
    if (result.isError) {
      result.errorMessage = 'HTTP ' + response.statusCode.toString() + ': ' + statusText;
    }
    return result;
  }

  private extractResponseHeaders(response: rcp.Response): Record<string, string> {
    const headers: Record<string, string> = {} as Record<string, string>;
    if (response.headers !== undefined) {
      const respHeaders: rcp.ResponseHeaders = response.headers;
      const keys: string[] = Object.keys(respHeaders);
      for (let i = 0; i < keys.length; i++) {
          const val: string | string[] | undefined = respHeaders[keys[i]];
        if (val === undefined) {
          continue;
        }
        if (val instanceof Array) {
          headers[keys[i]] = (val as string[]).join(', ');
        } else {
          headers[keys[i]] = val as string;
        }
      }
    }
    return headers;
  }

  private createOptions(): RequestOptions {
    const options: RequestOptions = {
      headers: {} as Record<string, string>,
      body: '',
      contentType: '',
      depth: '',
      overwrite: '',
      destination: '',
      timeout: 0,
    };
    return options;
  }
}
