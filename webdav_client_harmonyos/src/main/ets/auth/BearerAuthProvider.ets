import { AuthType } from '../model/AuthType';
import { IAuthProvider } from './IAuthProvider';

export class BearerAuthProvider implements IAuthProvider {
  private token: string = '';

  constructor(token: string) {
    this.token = token;
  }

  getType(): AuthType {
    return AuthType.BEARER;
  }

  applyHeaders(headers: Record<string, string>): Record<string, string> {
    headers['Authorization'] = 'Bearer ' + this.token;
    return headers;
  }

  handle401(_responseHeaders: Record<string, string>): void {
  }
}
