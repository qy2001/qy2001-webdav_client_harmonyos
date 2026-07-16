import { AuthType } from '../model/AuthType';
import { IAuthProvider } from './IAuthProvider';

export class CustomAuthProvider implements IAuthProvider {
  private customHeaders: Record<string, string> = {} as Record<string, string>;

  constructor(headers: Record<string, string>) {
    this.customHeaders = headers;
  }

  getType(): AuthType {
    return AuthType.CUSTOM;
  }

  applyHeaders(headers: Record<string, string>): Record<string, string> {
    const keys: string[] = Object.keys(this.customHeaders);
    for (let i = 0; i < keys.length; i++) {
      headers[keys[i]] = this.customHeaders[keys[i]];
    }
    return headers;
  }

  handle401(_responseHeaders: Record<string, string>): void {
  }
}
