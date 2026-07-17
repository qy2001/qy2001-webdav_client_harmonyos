import { AuthType } from '../model/AuthType';

export interface IAuthProvider {
  getType(): AuthType;
  applyHeaders(headers: Record<string, string>): Record<string, string>;
  handle401(responseHeaders: Record<string, string>): void;
}
