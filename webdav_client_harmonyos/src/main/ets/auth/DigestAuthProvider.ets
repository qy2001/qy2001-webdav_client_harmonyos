import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { buffer } from '@kit.ArkTS';
import { AuthType } from '../model/AuthType';
import { IAuthProvider } from './IAuthProvider';

export class DigestAuthProvider implements IAuthProvider {
  private username: string = '';
  private password: string = '';
  private realm: string = '';
  private nonce: string = '';
  private qop: string = '';
  private opaque: string = '';
  private algorithm: string = 'MD5';
  private cnonce: string = '';
  private nc: number = 0;
  private uri: string = '';

  constructor(username: string, password: string) {
    this.username = username;
    this.password = password;
    this.cnonce = this.generateCnonce();
  }

  getType(): AuthType {
    return AuthType.DIGEST;
  }

  applyHeaders(headers: Record<string, string>): Record<string, string> {
    if (this.nonce.length === 0) {
      return headers;
    }
    const authHeader = this.buildAuthorizationHeader();
    headers['Authorization'] = authHeader;
    return headers;
  }

  handle401(responseHeaders: Record<string, string>): void {
    const wwwAuth: string | undefined = this.getHeaderValue(responseHeaders, 'www-authenticate');
    if (wwwAuth !== undefined && wwwAuth.length > 0) {
      this.parseWwwAuthenticate(wwwAuth);
      this.nc = 0;
      this.cnonce = this.generateCnonce();
    }
  }

  setUri(uri: string): void {
    this.uri = uri;
  }

  private parseWwwAuthenticate(header: string): void {
    const lowerHeader: string = header.toLowerCase();
    const realmMatch: RegExpMatchArray | null = lowerHeader.match(new RegExp('realm="([^"]+)"'));
    if (realmMatch !== null) {
      this.realm = realmMatch[1];
    }
    const nonceMatch: RegExpMatchArray | null = lowerHeader.match(new RegExp('nonce="([^"]+)"'));
    if (nonceMatch !== null) {
      this.nonce = nonceMatch[1];
    }
    const qopMatch: RegExpMatchArray | null = lowerHeader.match(new RegExp('qop="([^"]+)"'));
    if (qopMatch !== null) {
      this.qop = qopMatch[1].split(',')[0].trim();
    }
    const opaqueMatch: RegExpMatchArray | null = lowerHeader.match(new RegExp('opaque="([^"]+)"'));
    if (opaqueMatch !== null) {
      this.opaque = opaqueMatch[1];
    }
    const algoMatch: RegExpMatchArray | null = lowerHeader.match(new RegExp('algorithm=([^\\s,]+)'));
    if (algoMatch !== null) {
      this.algorithm = algoMatch[1];
    }
  }

  private buildAuthorizationHeader(): string {
    this.nc += 1;
    const ncStr: string = this.nc.toString().padStart(8, '0');
    const ha1: string = this.md5(this.username + ':' + this.realm + ':' + this.password);
    const ha2: string = this.md5('GET:' + this.uri);
    let response: string = '';
    if (this.qop.length > 0) {
      response = this.md5(ha1 + ':' + this.nonce + ':' + ncStr + ':' + this.cnonce + ':' + this.qop + ':' + ha2);
    } else {
      response = this.md5(ha1 + ':' + this.nonce + ':' + ha2);
    }
    let header: string = 'Digest username="' + this.username + '", realm="' + this.realm + '", nonce="' + this.nonce + '", uri="' + this.uri + '", response="' + response + '"';
    if (this.opaque.length > 0) {
      header += ', opaque="' + this.opaque + '"';
    }
    if (this.qop.length > 0) {
      header += ', qop=' + this.qop + ', nc=' + ncStr + ', cnonce="' + this.cnonce + '"';
    }
    header += ', algorithm=' + this.algorithm;
    return header;
  }

  private md5(input: string): string {
    let hash: string = '';
    try {
      const md = cryptoFramework.createMd('MD5');
      const inputData: cryptoFramework.DataBlob = { data: new Uint8Array(buffer.from(input, 'utf-8').buffer) };
      md.updateSync(inputData);
      const result: cryptoFramework.DataBlob = md.digestSync();
      const arr: Uint8Array = result.data;
      for (let i = 0; i < arr.length; i++) {
        const hex: string = arr[i].toString(16).padStart(2, '0');
        hash += hex;
      }
    } catch (e) {
      hash = '';
    }
    return hash;
  }

  private generateCnonce(): string {
    const chars: string = 'abcdef0123456789';
    let cnonce: string = '';
    for (let i = 0; i < 16; i++) {
      const idx: number = Math.floor(Math.random() * chars.length);
      cnonce += chars[idx];
    }
    return cnonce;
  }

  private getHeaderValue(headers: Record<string, string>, key: string): string | undefined {
    const keys: string[] = Object.keys(headers);
    for (let i = 0; i < keys.length; i++) {
      if (keys[i].toLowerCase() === key) {
        return headers[keys[i]];
      }
    }
    return undefined;
  }
}
