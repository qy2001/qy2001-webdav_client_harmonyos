# WebDav Client HarmonyOS

HarmonyOS 平台的 WebDav 客户端共享包（HSP），基于 RFC 4918 标准实现，支持多种认证方式和完整的 WebDav 操作。

## 功能特性

- **多认证模式**: Basic Auth、Bearer Token、Digest Auth、自定义请求头
- **RFC 4918 标准操作**: PROPFIND、MKCOL、DELETE、GET、PUT、COPY、MOVE、PROPPATCH、LOCK、UNLOCK
- **XML 自动解析**: 服务端 XML 响应自动转换为 JSON 对象 (基于 convertxml)
- **多实例复用**: 一个实例连接一个服务端，支持同时连接多个服务端
- **自定义配置**: 超时时间、User-Agent、默认 Depth、自定义请求头
- **基于 rcp**: 使用 HarmonyOS Remote Communication Kit 发起 HTTP 请求
- **资源完整信息**: `WebDavResource` 包含完整访问 URL (`fullUrl`) 和认证头 (`authHeaders`)，集成时直接可用

## 安装

### 方式一：ohpm 安装（推荐）

```bash
ohpm install webdav_client_harmonyos
```

### 方式二：Git 仓库引用

在你的模块 `oh-package.json5` 中添加：

```json5
{
  "dependencies": {
    "webdav_client_harmonyos": "git+https://github.com/你的用户名/webdav-client-lib.git"
  }
}
```

然后执行 `ohpm install`。

### 方式三：本地引用

将本仓库克隆到你的项目目录下，在 `oh-package.json5` 中添加：

```json5
{
  "dependencies": {
    "webdav_client_harmonyos": "file:../webdav-client-lib"
  }
}
```

## 快速开始

### 创建客户端

```typescript
import { WebDavClient, AuthType } from 'webdav_client_harmonyos';

// 无认证
const client = WebDavClient.fromPartial({
  baseUrl: 'https://dav.example.com/',
});

// Basic Auth
const basicClient = WebDavClient.fromPartial({
  baseUrl: 'https://dav.example.com/',
  authType: AuthType.BASIC,
  username: 'user',
  password: 'pass',
});

// Bearer Token
const tokenClient = WebDavClient.fromPartial({
  baseUrl: 'https://dav.example.com/',
  authType: AuthType.BEARER,
  token: 'your-access-token',
});

// Digest Auth
const digestClient = WebDavClient.fromPartial({
  baseUrl: 'https://dav.example.com/',
  authType: AuthType.DIGEST,
  username: 'user',
  password: 'pass',
});

// 自定义请求头
const customClient = WebDavClient.fromPartial({
  baseUrl: 'https://dav.example.com/',
  authType: AuthType.CUSTOM,
  customHeaders: { 'X-API-Key': 'your-key' },
});
```

### 目录操作

```typescript
// 列出目录内容
const listResp = await client.list('/', '1');
if (!listResp.isError && listResp.data !== undefined) {
  for (const resource of listResp.data) {
    console.log(resource.href, resource.isDirectory ? '[DIR]' : '[FILE]');
  }
}

// 获取资源属性
const statResp = await client.stat('/file.txt');

// 创建目录
await client.mkdir('/new-folder/');

// 删除资源
await client.delete('/old-file.txt');
```

### 文件操作

```typescript
// 下载文件
const getResp = await client.get('/file.txt');
if (!getResp.isError) {
  const content = getResp.data; // 文件内容字符串
}

// 上传文件
await client.put('/upload.txt', 'file content', 'text/plain');
```

### 复制与移动

```typescript
// 复制 (overwrite: true 覆盖目标)
await client.copy('/src.txt', '/dest.txt', true);

// 移动
await client.move('/old.txt', '/new.txt', false);
```

### 属性操作

```typescript
// 修改属性 (PROPPATCH)
const setProps: Record<string, string> = { 'displayname': 'New Name' };
const removeProps: string[] = ['someprop'];
await client.proppatch('/file.txt', setProps, removeProps);
```

### 锁操作

```typescript
// 锁定资源
const lockResp = await client.lock('/file.txt', 'user@example.com');
const lockToken = lockResp.data; // 保存 lockToken

// 解锁资源
await client.unlock('/file.txt', lockToken);
```

### 连接检测与资源释放

```typescript
// 检测连接
const connected = await client.checkConnection();

// 释放资源 (不再使用时调用)
client.destroy();
```

### 集成到其他项目

`WebDavResource` 的 `fullUrl` 和 `authHeaders` 属性可以方便地与其他组件集成（如视频播放器、图片查看器等）：

```typescript
const listResp = await client.list('/videos/', '1');
if (!listResp.isError && listResp.data !== undefined) {
  const video = listResp.data.find(r => !r.isDirectory && r.contentType.startsWith('video/'));
  if (video !== undefined) {
    // 直接使用 fullUrl 和 authHeaders，无需手动拼接 URL 和认证参数
    videoPlayer.url = video.fullUrl;
    videoPlayer.headers = video.authHeaders;
  }
}
```

`fullUrl` 由 `baseUrl` 的 origin（协议+IP+端口）与服务器返回的 `href` 拼接，避免路径重复。
`authHeaders` 根据认证类型自动填充（如 `Authorization: Basic xxx`、`Authorization: Bearer xxx` 等）。

## API 参考

### WebDavClient

| 方法 | 说明 | 返回类型 |
|------|------|----------|
| `list(path, depth)` | 列出目录内容 (PROPFIND) | `Promise<WebDavResponse<WebDavResource[]>>` |
| `stat(path)` | 获取资源属性 (PROPFIND depth=0) | `Promise<WebDavResponse<WebDavResource>>` |
| `mkdir(path)` | 创建目录 (MKCOL) | `Promise<WebDavResponse<void>>` |
| `delete(path)` | 删除资源 (DELETE) | `Promise<WebDavResponse<void>>` |
| `get(path)` | 下载文件 (GET) | `Promise<WebDavResponse<string>>` |
| `put(path, content, contentType)` | 上传文件 (PUT) | `Promise<WebDavResponse<void>>` |
| `copy(srcPath, destPath, overwrite)` | 复制资源 (COPY) | `Promise<WebDavResponse<void>>` |
| `move(srcPath, destPath, overwrite)` | 移动资源 (MOVE) | `Promise<WebDavResponse<void>>` |
| `proppatch(path, setProps, removeProps)` | 修改属性 (PROPPATCH) | `Promise<WebDavResponse<Record<string, string>>>` |
| `lock(path, owner)` | 锁定资源 (LOCK) | `Promise<WebDavResponse<string>>` |
| `unlock(path, lockToken)` | 解锁资源 (UNLOCK) | `Promise<WebDavResponse<void>>` |
| `checkConnection()` | 检测连接是否可用 | `Promise<boolean>` |
| `getUrl(path)` | 获取资源的完整 URL | `string` |
| `getConfig()` | 获取当前配置 | `WebDavConfig` |
| `destroy()` | 释放资源 | `void` |

### WebDavConfig

| 属性 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `baseUrl` | `string` | `''` | WebDav 服务端地址 |
| `authType` | `AuthType` | `NONE` | 认证类型 |
| `username` | `string` | `''` | 用户名 (Basic/Digest) |
| `password` | `string` | `''` | 密码 (Basic/Digest) |
| `token` | `string` | `''` | Token (Bearer) |
| `customHeaders` | `Record<string, string>` | `{}` | 自定义请求头 (Custom) |
| `timeout` | `number` | `30000` | 超时时间 (ms) |
| `userAgent` | `string` | `'WebDavClient-HarmonyOS/1.0'` | User-Agent |
| `defaultDepth` | `string` | `'1'` | 默认 Depth 头 |

### AuthType

| 值 | 说明 |
|----|------|
| `NONE` | 无认证 |
| `BASIC` | HTTP Basic 认证 |
| `BEARER` | Bearer Token 认证 |
| `DIGEST` | HTTP Digest 认证 |
| `CUSTOM` | 自定义请求头认证 |

### WebDavResource

| 属性 | 类型 | 说明 |
|------|------|------|
| `href` | `string` | 资源路径（服务器返回） |
| `isDirectory` | `boolean` | 是否为目录 |
| `displayName` | `string` | 显示名称 |
| `creationDate` | `string` | 创建时间 |
| `lastModified` | `string` | 最后修改时间 |
| `contentLength` | `number` | 文件大小 |
| `contentType` | `string` | 内容类型 |
| `etag` | `string` | ETag |
| `status` | `string` | HTTP 状态 |
| `fullUrl` | `string` | 完整访问 URL（自动拼接，可直接用于播放器等组件） |
| `authHeaders` | `Record<string, string>` | 认证请求头（自动填充，配合 fullUrl 使用） |

### WebDavResponse\<T\>

| 属性 | 类型 | 说明 |
|------|------|------|
| `statusCode` | `number` | HTTP 状态码 |
| `statusText` | `string` | 状态描述 |
| `headers` | `Record<string, string>` | 响应头 |
| `data` | `T \| undefined` | 响应数据 |
| `rawXml` | `string` | 原始 XML |
| `isError` | `boolean` | 是否错误 |
| `errorMessage` | `string` | 错误信息 |

## 权限要求

使用本库需要在 `module.json5` 中声明网络权限:

```json5
{
  "module": {
    "requestPermissions": [
      {
        "name": "ohos.permission.INTERNET",
        "reason": "$string:module_desc",
        "usedScene": {
          "abilities": ["EntryAbility"],
          "when": "always"
        }
      }
    ]
  }
}
```

## 项目结构

```
src/main/ets/
├── model/                        # 类型定义
│   ├── AuthType.ets              # 认证类型枚举
│   ├── WebDavConfig.ets          # 配置接口
│   ├── WebDavResource.ets        # 资源模型（含 fullUrl、authHeaders）
│   └── WebDavResponse.ets        # 响应封装
├── auth/                         # 认证策略
│   ├── IAuthProvider.ets         # 认证提供者接口
│   ├── BasicAuthProvider.ets     # Basic 认证
│   ├── BearerAuthProvider.ets    # Bearer Token
│   ├── DigestAuthProvider.ets    # Digest 认证
│   └── CustomAuthProvider.ets    # 自定义认证
├── http/                         # HTTP 请求层
│   └── HttpClient.ets            # rcp 封装
├── parser/                       # XML 解析
│   └── XmlParser.ets             # convertxml 封装
├── utils/                        # 工具
│   └── XmlBuilder.ets            # XML 请求体构建
└── WebDavClient.ets              # 主客户端类
```

## 安全说明

- `build-profile.json5` 和 `oh-package-lock.json5` 已加入 `.gitignore`，不会提交到仓库
- 签名证书文件（`.p12`、`.p7b`、`.cer`、`.jks`）同样已在 `.gitignore` 中忽略
- 请勿在代码中硬编码密码、Token 等敏感信息

## Demo

示例应用请查看 [webdav_client_demo](https://github.com/你的用户名/webdav-client-demo) 仓库。

## License

Apache-2.0
