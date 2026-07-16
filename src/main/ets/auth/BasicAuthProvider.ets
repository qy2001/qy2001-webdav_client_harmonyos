import { util, buffer } from '@kit.ArkTS';
import { AuthType } from '../model/AuthType';
import { IAuthProvider } from './IAuthProvider';

export class BasicAuthProvider implements IAuthProvider {
  private username: string = '';
  private password: string = '';

  constructor(username: string, password: string) {
    this.username = username;
    this.password = password;
  }

  getType(): AuthType {
    return AuthType.BASIC;
  }

  applyHeaders(headers: Record<string, string>): Record<string, string> {
    const credentials: string = this.username + ':' + this.password;
    const base64 = new util.Base64Helper();
    const encoded: Uint8Array = new Uint8Array(buffer.from(credentials, 'utf-8').buffer);
    const encodedStr: string = base64.encodeToStringSync(encoded);
    headers['Authorization'] = 'Basic ' + encodedStr;
    return headers;
  }

  handle401(_responseHeaders: Record<string, string>): void {
  }
}
