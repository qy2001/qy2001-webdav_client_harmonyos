import { AuthType } from './AuthType';

export interface WebDavConfig {
  baseUrl: string;
  authType: AuthType;
  username: string;
  password: string;
  token: string;
  customHeaders: Record<string, string>;
  timeout: number;
  userAgent: string;
  defaultDepth: string;
}

export class DefaultWebDavConfig {
  static create(overrides: PartialWebDavConfig): WebDavConfig {
    const config: WebDavConfig = {
      baseUrl: overrides.baseUrl ?? '',
      authType: overrides.authType ?? AuthType.NONE,
      username: overrides.username ?? '',
      password: overrides.password ?? '',
      token: overrides.token ?? '',
      customHeaders: overrides.customHeaders ?? ({} as Record<string, string>),
      timeout: overrides.timeout ?? 30000,
      userAgent: overrides.userAgent ?? 'WebDavClient-HarmonyOS/1.0',
      defaultDepth: overrides.defaultDepth ?? '1',
    };
    return config;
  }
}

export interface PartialWebDavConfig {
  baseUrl?: string;
  authType?: AuthType;
  username?: string;
  password?: string;
  token?: string;
  customHeaders?: Record<string, string>;
  timeout?: number;
  userAgent?: string;
  defaultDepth?: string;
}
