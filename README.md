# WebDav Client HarmonyOS

HarmonyOS 平台的 WebDav 客户端动态库，基于 RFC 4918 标准实现，支持多种认证方式和完整的 WebDav 操作。

## 功能特性

- **多认证模式**: Basic Auth、Bearer Token、Digest Auth、自定义请求头
- **RFC 4918 标准操作**: PROPFIND、MKCOL、DELETE、GET、PUT、COPY、MOVE、PROPPATCH、LOCK、UNLOCK
- **XML 自动解析**: 服务端 XML 响应自动转换为 JSON 对象 (基于 convertxml)
- **多实例复用**: 一个实例连接一个服务端，支持同时连接多个服务端
- **自定义配置**: 超时时间、User-Agent、默认 Depth、自定义请求头
- **基于 rcp**: 使用 HarmonyOS Remote Communication Kit 发起 HTTP 请求
- **资源完整信息**: `WebDavResource` 包含完整访问 URL (`fullUrl`) 和认证头 (`authHeaders`)，集成时直接可用
- **文件上传**: 支持 `DocumentViewPicker` 选择本地文件上传，自动识别 MIME 类型，支持上传进度回调

## 快速开始

### 签名配置

`build-profile.json5` 已加入 `.gitignore`，不会提交到仓库。克隆后需手动创建，参考以下模板：

**根目录 `build-profile.json5`：**

```json5
{
  "app": {
    "signingConfigs": [
      {
        "name": "default",
        "type": "HarmonyOS",
        "material": {
          "certpath": "C:\\Users\\你的用户名\\.ohos\\config\\你的证书.cer",
          "keyAlias": "debugKey",
          "keyPassword": "你的密钥密码",
          "profile": "C:\\Users\\你的用户名\\.ohos\\config\\你的配置.p7b",
          "signAlg": "SHA256withECDSA",
          "storeFile": "C:\\Users\\你的用户名\\.ohos\\config\\你的密钥库.p12",
          "storePassword": "你的密钥库密码"
        }
      }
    ],
    "products": [
      {
        "name": "default",
        "signingConfig": "default",
        "targetSdkVersion": "26.0.0",
        "compatibleSdkVersion": "5.0.0(12)",
        "runtimeOS": "HarmonyOS",
        "buildOption": {
          "strictMode": {
            "caseSensitiveCheck": true,
            "useNormalizedOHMUrl": true
          }
        }
      }
    ],
    "buildModeSet": [
      { "name": "debug" },
      { "name": "release" }
    ]
  },
  "modules": [
    {
      "name": "entry",
      "srcPath": "./entry",
      "targets": [{ "name": "default", "applyToProducts": ["default"] }]
    },
    {
      "name": "webdav_client_harmonyos",
      "srcPath": "./webdav_client_harmonyos",
      "targets": [{ "name": "default", "applyToProducts": ["default"] }]
    }
  ]
}
```

**`entry/build-profile.json5`：**

```json5
{
  "api": {
    "compatibleApiVersion": 12,
    "targetApiVersion": 12,
    "releaseType": "Release"
  }
}
```

**`webdav_client_harmonyos/build-profile.json5`：**

```json5
{
  "api": {
    "compatibleApiVersion": 12,
    "targetApiVersion": 12,
    "releaseType": "Release"
  }
}
```

最简方式：在 DevEco Studio 中打开项目后，进入 **File → Project Structure → Project → Signing Configs**，勾选 **Automatically generate signature**，DevEco 会自动生成 `build-profile.json5` 和签名证书。

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
// 下载文件 (文本内容)
const getResp = await client.get('/file.txt');
if (!getResp.isError) {
  const content = getResp.data; // 文件内容字符串
}

// 上传文本文件
await client.put('/upload.txt', 'file content', 'text/plain');

// 上传二进制文件 (通过 DocumentViewPicker 选择文件后读取的 ArrayBuffer)
const content: ArrayBuffer = ...; // 从文件选择器获取
await client.putBinary('/image.png', content, 'image/png');

// 监听上传进度
client.setOnUploadProgress((totalSize: number, transferredSize: number) => {
  const progress = Math.floor(transferredSize / totalSize * 100);
  console.log(`上传进度: ${progress}%`);
});
await client.putBinary('/large-file.zip', largeBuffer, 'application/zip');
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

## 集成方式

提供三种集成方式，根据项目需求选择。

### 方式一：HSP 子模块集成（源码）

将 `webdav_client_harmonyos` 作为项目子模块，可以直接修改源码，适合需要定制或调试的场景。

**1. 复制模块源码到项目根目录：**

```
your-project/
├── entry/
├── webdav_client_harmonyos/    ← 复制到此处
│   ├── Index.ets
│   ├── oh-package.json5
│   ├── build-profile.json5
│   ├── hvigorfile.ts
│   └── src/main/ets/...
├── build-profile.json5
└── oh-package.json5
```

**2. 在根目录 `build-profile.json5` 的 `modules` 中注册子模块：**

```json5
{
  "modules": [
    {
      "name": "entry",
      "srcPath": "./entry",
      "targets": [{ "name": "default", "applyToProducts": ["default"] }]
    },
    {
      "name": "webdav_client_harmonyos",
      "srcPath": "./webdav_client_harmonyos",
      "targets": [{ "name": "default", "applyToProducts": ["default"] }]
    }
  ]
}
```

**3. 在根目录 `oh-package.json5` 中添加 devDependencies：**

```json5
{
  "devDependencies": {
    "webdav_client_harmonyos": "file:./webdav_client_harmonyos"
  }
}
```

**4. 在使用模块的 `oh-package.json5`（如 `entry/oh-package.json5`）中添加依赖：**

```json5
{
  "dependencies": {
    "webdav_client_harmonyos": "file:../webdav_client_harmonyos"
  }
}
```

**5. 在 `webdav_client_harmonyos/` 目录下创建 `build-profile.json5`：**

```json5
{
  "apiType": "stageMode",
  "buildOption": {},
  "targets": [
    {
      "name": "default",
      "runtimeOS": "HarmonyOS"
    }
  ]
}
```

**6. 执行 ohpm 安装依赖：**

```bash
ohpm install
```

### 方式二：HAR 包集成

从 [GitHub Releases](https://github.com/qy2001/qy2001-webdav_client_harmonyos/releases) 下载 `webdav_client_harmonyos.har`，无需编译子模块，集成更轻量。

**1. 将 HAR 包放到项目目录（如项目根目录或 `libs/` 目录）：**

```
your-project/
├── entry/
├── libs/
│   └── webdav_client_harmonyos.har    ← HAR 包
├── build-profile.json5
└── oh-package.json5
```

**2. 在使用模块的 `oh-package.json5`（如 `entry/oh-package.json5`）中添加依赖：**

```json5
{
  "dependencies": {
    "webdav_client_harmonyos": "file:../libs/webdav_client_harmonyos.har"
  }
}
```

**3. 在根目录 `oh-package.json5` 中添加 devDependencies：**

```json5
{
  "devDependencies": {
    "webdav_client_harmonyos": "file:./libs/webdav_client_harmonyos.har"
  }
}
```

**4. 执行 ohpm 安装依赖：**

```bash
ohpm install
```

> **注意**：HAR 集成方式不需要在 `build-profile.json5` 的 `modules` 中注册子模块。

### 方式三：HSP 包集成

从 [GitHub Releases](https://github.com/qy2001/qy2001-webdav_client_harmonyos/releases) 下载 `webdav_client_harmonyos-default-signed.hsp`，以预编译 HSP 包方式集成。

**1. 将 HSP 包放到项目目录：**

```
your-project/
├── entry/
├── libs/
│   └── webdav_client_harmonyos-default-signed.hsp    ← HSP 包
├── build-profile.json5
└── oh-package.json5
```

**2. 在使用模块的 `oh-package.json5` 中添加依赖：**

```json5
{
  "dependencies": {
    "webdav_client_harmonyos": "file:../libs/webdav_client_harmonyos-default-signed.hsp"
  }
}
```

**3. 在根目录 `oh-package.json5` 中添加 devDependencies：**

```json5
{
  "devDependencies": {
    "webdav_client_harmonyos": "file:./libs/webdav_client_harmonyos-default-signed.hsp"
  }
}
```

**4. 执行 ohpm 安装依赖：**

```bash
ohpm install
```

> **注意**：HSP 包集成同样不需要在 `build-profile.json5` 的 `modules` 中注册子模块。

### 使用方式

三种集成方式完成后，代码中使用方式相同：

```typescript
import { WebDavClient, AuthType } from 'webdav_client_harmonyos';
```

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
| `put(path, content, contentType)` | 上传文本文件 (PUT) | `Promise<WebDavResponse<void>>` |
| `putBinary(path, content, contentType)` | 上传二进制文件 (PUT) | `Promise<WebDavResponse<void>>` |
| `setOnUploadProgress(callback)` | 设置上传进度回调 | `void` |
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

### OnUploadProgress

```typescript
type OnUploadProgress = (totalSize: number, transferredSize: number) => void;
```

上传进度回调类型，通过 `client.setOnUploadProgress()` 设置。

- `totalSize`: 上传数据总大小（字节），若服务端未返回 Content-Length 则为 0
- `transferredSize`: 已上传的数据大小（字节）

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
webdav_client_harmonyos/src/main/ets/
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

HAR 和 HSP 包可从 [GitHub Releases](https://github.com/qy2001/qy2001-webdav_client_harmonyos/releases) 下载。

## 安全说明

- `build-profile.json5` 已加入 `.gitignore`，不会提交到仓库（包含签名证书路径和密码）
- 签名证书文件（`.p12`、`.p7b`、`.cer`、`.jks`）同样已在 `.gitignore` 中忽略
- 请勿在代码中硬编码密码、Token 等敏感信息

## License

Apache-2.0
