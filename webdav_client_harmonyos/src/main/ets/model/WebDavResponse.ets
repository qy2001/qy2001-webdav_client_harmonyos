export class WebDavResponse<T> {
  statusCode: number = 0;
  statusText: string = '';
  headers: Record<string, string> = {} as Record<string, string>;
  data: T | undefined = undefined;
  rawXml: string = '';
  isError: boolean = false;
  errorMessage: string = '';

  static success<T>(statusCode: number, data: T, rawXml: string, headers: Record<string, string>): WebDavResponse<T> {
    const resp = new WebDavResponse<T>();
    resp.statusCode = statusCode;
    resp.data = data;
    resp.rawXml = rawXml;
    resp.headers = headers;
    resp.isError = false;
    return resp;
  }

  static error<T>(statusCode: number, errorMessage: string): WebDavResponse<T> {
    const resp = new WebDavResponse<T>();
    resp.statusCode = statusCode;
    resp.errorMessage = errorMessage;
    resp.isError = true;
    return resp;
  }
}
