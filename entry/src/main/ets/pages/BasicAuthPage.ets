import { AuthType, WebDavClient, WebDavResource, WebDavResponse, OnUploadProgress } from "webdav_client_harmonyos";
import { picker, fileIo as fs } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';


@Builder
export function BasicAuthPageBuilder() {
  BasicAuthPage()
}

@Component
struct BasicAuthPage {
  private navStack: NavPathStack = new NavPathStack();
  @State protocol: string = 'http';
  @State serverIp: string = '192.168.1.100';
  @State serverPort: string = '5244';
  @State serverPath: string = '/dav/';
  @State username: string = '';
  @State password: string = '';
  @State queryPath: string = '/';
  @State resultText: string = '';
  @State isLoading: boolean = false;
  @State fileList: WebDavResource[] = [];
  @State selectedFileName: string = '';
  @State uploadProgress: number = -1;
  private selectedFileURI: string = '';
  private selectedFileContent: ArrayBuffer | undefined = undefined;
  private client: WebDavClient | undefined = undefined;

  build() {
    NavDestination() {
      Scroll() {
        Column({ space: 16 }) {
          this.inputSection()
          this.querySection()
          this.actionSection()
          this.resultSection()
        }
        .width('100%')
        .padding(16)
      }
      .width('100%')
      .height('100%')
    }
    .title('基础认证')
    .onReady((context: NavDestinationContext) => {
      this.navStack = context.pathStack;
    })
    .onDisAppear(() => {
      if (this.client !== undefined) {
        this.client.destroy();
        this.client = undefined;
      }
    })
  }

  @Builder
  inputSection() {
    Column({ space: 12 }) {
      Text('服务端配置')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)

      Text('协议')
        .fontSize(13)
        .fontColor('#666666')
        .width('100%')
      Row({ space: 8 }) {
        Button('HTTP')
          .fontSize(14)
          .layoutWeight(1)
          .backgroundColor(this.protocol === 'http' ? '#007DFF' : '#E0E0E0')
          .fontColor(this.protocol === 'http' ? '#FFFFFF' : '#333333')
          .onClick(() => { this.protocol = 'http'; })
        Button('HTTPS')
          .fontSize(14)
          .layoutWeight(1)
          .backgroundColor(this.protocol === 'https' ? '#007DFF' : '#E0E0E0')
          .fontColor(this.protocol === 'https' ? '#FFFFFF' : '#333333')
          .onClick(() => { this.protocol = 'https'; })
      }
      .width('100%')

      TextInput({ placeholder: 'IP 地址', text: this.serverIp })
        .onChange((value: string) => { this.serverIp = value; })
        .width('100%')

      TextInput({ placeholder: '端口', text: this.serverPort })
        .onChange((value: string) => { this.serverPort = value; })
        .width('100%')
        .type(InputType.Number)

      TextInput({ placeholder: '路径 (如 /dav/)', text: this.serverPath })
        .onChange((value: string) => { this.serverPath = value; })
        .width('100%')

      Text('完整地址: ' + this.buildBaseUrl())
        .fontSize(12)
        .fontColor('#999999')
        .width('100%')

      Text('认证信息')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .margin({ top: 4 })

      TextInput({ placeholder: '用户名', text: $$this.username })
        .onChange((value: string) => { this.username = value; })
        .width('100%')

      TextInput({ placeholder: '密码' , text: $$this.password })
        .type(InputType.Password)
        .onChange((value: string) => { this.password = value; })
        .width('100%')
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  querySection() {
    Column({ space: 12 }) {
      Text('查询路径')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)

      Row({ space: 8 }) {
        TextInput({ placeholder: '输入文件或目录路径 (如 / 或 /docs/)', text: this.queryPath })
          .onChange((value: string) => { this.queryPath = value; })
          .layoutWeight(1)
        Button('查询')
          .backgroundColor('#007DFF')
          .fontColor('#FFFFFF')
          .enabled(!this.isLoading && this.client !== undefined)
          .onClick(() => { this.handleQuery(); })
      }
      .width('100%')
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  actionSection() {
    Column({ space: 12 }) {
      Text('操作')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)

      Row({ space: 8 }) {
        Button('连接')
          .layoutWeight(1)
          .enabled(!this.isLoading)
          .onClick(() => { this.handleConnect(); })
        Button('列出目录')
          .layoutWeight(1)
          .enabled(!this.isLoading && this.client !== undefined)
          .onClick(() => { this.handleList(); })
      }
      .width('100%')

      Row({ space: 8 }) {
        Button('查看属性')
          .layoutWeight(1)
          .enabled(!this.isLoading && this.client !== undefined)
          .onClick(() => { this.handleStat(); })
        Button('创建目录')
          .layoutWeight(1)
          .enabled(!this.isLoading && this.client !== undefined)
          .onClick(() => { this.handleMkdir(); })
      }
      .width('100%')

      Row({ space: 8 }) {
        Button('选择文件上传')
          .layoutWeight(1)
          .backgroundColor('#FF8C00')
          .enabled(!this.isLoading && this.client !== undefined)
          .onClick(() => { this.handlePickAndUpload(); })
        Button('上传文本')
          .layoutWeight(1)
          .enabled(!this.isLoading && this.client !== undefined)
          .onClick(() => { this.handlePutText(); })
      }
      .width('100%')

      if (this.selectedFileName.length > 0) {
        Column({ space: 8 }) {
          Row({ space: 8 }) {
            Text('已选择: ' + this.selectedFileName)
              .fontSize(13)
              .fontColor('#333333')
              .layoutWeight(1)
            Button('上传')
              .fontSize(13)
              .backgroundColor('#FF8C00')
              .enabled(!this.isLoading && this.client !== undefined)
              .onClick(() => { this.handleUploadFile(); })
          }
          .width('100%')
          if (this.uploadProgress >= 0) {
            Progress({ value: this.uploadProgress, total: 100, type: ProgressType.Linear })
              .width('100%')
              .color('#FF8C00')
            Text('上传进度: ' + this.uploadProgress.toString() + '%')
              .fontSize(12)
              .fontColor('#666666')
          }
        }
        .width('100%')
        .padding(8)
        .backgroundColor('#FFF5E6')
        .borderRadius(8)
      }

      Button('删除文件')
        .width('100%')
        .backgroundColor('#FF4444')
        .enabled(!this.isLoading && this.client !== undefined)
        .onClick(() => { this.handleDelete(); })
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
  }

  @Builder
  resultSection() {
    Column({ space: 8 }) {
      Text('结果')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)

      if (this.isLoading) {
        LoadingProgress()
          .width(32)
          .height(32)
          .color('#007DFF')
      }

      if (this.fileList.length > 0) {
        List({ space: 8 }) {
          ForEach(this.fileList, (item: WebDavResource) => {
            ListItem() {
              Row({ space: 8 }) {
                Text(item.isDirectory ? '[目录]' : '[文件]')
                  .fontSize(12)
                  .fontColor(item.isDirectory ? '#007DFF' : '#666666')
                  .width(48)
                Text(item.displayName.length > 0 ? item.displayName : item.href)
                  .fontSize(14)
                  .layoutWeight(1)
                if (!item.isDirectory) {
                  Text(this.formatSize(item.contentLength))
                    .fontSize(12)
                    .fontColor('#999999')
                }
              }
              .width('100%')
              .padding(8)
              .backgroundColor('#F5F5F5')
              .borderRadius(8)
              .onClick(() => { this.navigateToItem(item); })
            }
          }, (item: WebDavResource, index: number) => item.href + index.toString())
        }
        .width('100%')
        .constraintSize({ maxHeight: 300 })
      }

      if (this.resultText.length > 0) {
        Text(this.resultText)
          .fontSize(12)
          .fontColor('#333333')
          .width('100%')
          .padding(12)
          .backgroundColor('#F5F5F5')
          .borderRadius(8)
          .copyOption(CopyOptions.InApp)
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .alignItems(HorizontalAlign.Start)
  }

  private buildBaseUrl(): string {
    return this.protocol + '://' + this.serverIp + ':' + this.serverPort + this.serverPath;
  }

  private formatSize(bytes: number): string {
    if (bytes < 1024) {
      return bytes.toString() + ' B';
    }
    if (bytes < 1024 * 1024) {
      return (bytes / 1024).toFixed(1) + ' KB';
    }
    return (bytes / (1024 * 1024)).toFixed(1) + ' MB';
  }

  private extractRelativePath(href: string): string {
    const basePath: string = this.serverPath;
    const idx: number = href.indexOf(basePath);
    if (idx >= 0) {
      return href.substring(idx + basePath.length);
    }
    return href;
  }

  private navigateToItem(item: WebDavResource): void {
    const relativePath: string = this.extractRelativePath(item.href);
    this.queryPath = relativePath;
    this.handleQuery();
  }

  private createClient(): void {
    if (this.client !== undefined) {
      this.client.destroy();
    }
    this.client = WebDavClient.fromPartial({
      baseUrl: this.buildBaseUrl(),
      authType: AuthType.BASIC,
      username: this.username,
      password: this.password,
    });
  }

  private async handleConnect(): Promise<void> {
    this.isLoading = true;
    this.resultText = '正在连接...';
    this.fileList = [];
    try {
      this.createClient();
      if (this.client !== undefined) {
        const connected: boolean = await this.client.checkConnection();
        this.resultText = connected ? '连接成功！' : '连接失败，请检查地址和认证信息。';
      } else {
        this.resultText = '创建客户端失败。';
      }
    } catch (e) {
      this.resultText = '错误：' + (e as Error).message;
    }
    this.isLoading = false;
  }

  private async handleQuery(): Promise<void> {
    if (this.client === undefined) {
      return;
    }
    this.isLoading = true;
    this.resultText = '';
    this.fileList = [];
    try {
      const statResponse: WebDavResponse<WebDavResource> = await this.client.stat(this.queryPath);
      if (statResponse.isError) {
        this.resultText = '错误：' + statResponse.statusCode.toString() + ' ' + statResponse.errorMessage;
      } else if (statResponse.data !== undefined && statResponse.data.isDirectory) {
        const listResponse: WebDavResponse<WebDavResource[]> = await this.client.list(this.queryPath, '1');
        if (listResponse.isError) {
          this.resultText = '错误：' + listResponse.statusCode.toString() + ' ' + listResponse.errorMessage;
        } else if (listResponse.data !== undefined) {
          this.fileList = listResponse.data;
          this.resultText = '找到 ' + listResponse.data.length.toString() + ' 个项目';
        }
      } else if (statResponse.data !== undefined) {
        const r: WebDavResource = statResponse.data;
        this.resultText = '路径: ' + r.href + '\n类型: 文件\n名称: ' + r.displayName +
          '\n修改时间: ' + r.lastModified + '\n大小: ' + this.formatSize(r.contentLength) +
          '\nMIME: ' + r.contentType;
      }
    } catch (e) {
      this.resultText = '错误：' + (e as Error).message;
    }
    this.isLoading = false;
  }

  private async handleList(): Promise<void> {
    if (this.client === undefined) {
      return;
    }
    this.isLoading = true;
    this.resultText = '';
    this.fileList = [];
    try {
      const response: WebDavResponse<WebDavResource[]> = await this.client.list(this.queryPath, '1');
      if (response.isError) {
        this.resultText = '错误：' + response.statusCode.toString() + ' ' + response.errorMessage;
      } else if (response.data !== undefined) {
        this.fileList = response.data;
        this.resultText = '找到 ' + response.data.length.toString() + ' 个项目';
      }
    } catch (e) {
      this.resultText = '错误：' + (e as Error).message;
    }
    this.isLoading = false;
  }

  private async handleStat(): Promise<void> {
    if (this.client === undefined) {
      return;
    }
    this.isLoading = true;
    this.resultText = '';
    try {
      const response: WebDavResponse<WebDavResource> = await this.client.stat(this.queryPath);
      if (response.isError) {
        this.resultText = '错误：' + response.statusCode.toString() + ' ' + response.errorMessage;
      } else if (response.data !== undefined) {
        const r: WebDavResource = response.data;
        this.resultText = '路径: ' + r.href + '\n类型: ' + (r.isDirectory ? '目录' : '文件') +
          '\n名称: ' + r.displayName + '\n修改时间: ' + r.lastModified +
          '\n大小: ' + this.formatSize(r.contentLength) + '\nMIME: ' + r.contentType;
      }
    } catch (e) {
      this.resultText = '错误：' + (e as Error).message;
    }
    this.isLoading = false;
  }

  private async handleMkdir(): Promise<void> {
    if (this.client === undefined) {
      return;
    }
    this.isLoading = true;
    this.resultText = '正在创建目录...';
    try {
      const response: WebDavResponse<void> = await this.client.mkdir(this.queryPath);
      this.resultText = response.isError ?
        '错误：' + response.statusCode.toString() + ' ' + response.errorMessage :
        '目录创建成功！';
    } catch (e) {
      this.resultText = '错误：' + (e as Error).message;
    }
    this.isLoading = false;
  }

  private async handlePickAndUpload(): Promise<void> {
    try {
      const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
      const documentSelectOptions: picker.DocumentSelectOptions = new picker.DocumentSelectOptions();
      documentSelectOptions.maxSelectNumber = 1;
      const docPicker: picker.DocumentViewPicker = new picker.DocumentViewPicker(context);
      const uris: Array<string> = await docPicker.select(documentSelectOptions);
      if (uris.length > 0) {
        this.selectedFileURI = uris[0];
        const filePath: string = this.uriToPath(uris[0]);
        const fileName: string = filePath.substring(filePath.lastIndexOf('/') + 1);
        this.selectedFileName = fileName;
        const file: fs.File = fs.openSync(uris[0], fs.OpenMode.READ_ONLY);
        const stat: fs.Stat = fs.statSync(file.fd);
        const buffer: ArrayBuffer = new ArrayBuffer(stat.size);
        fs.readSync(file.fd, buffer);
        fs.closeSync(file);
        this.selectedFileContent = buffer;
        this.uploadProgress = -1;
        this.resultText = '已选择文件: ' + fileName + '\n大小: ' + this.formatSize(buffer.byteLength) + '\n请点击"上传"按钮上传到: ' + this.queryPath;
      }
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      this.resultText = '选择文件失败：' + err.message;
    }
  }

  private async handleUploadFile(): Promise<void> {
    if (this.client === undefined) {
      return;
    }
    if (this.selectedFileContent === undefined || this.selectedFileName.length === 0) {
      this.resultText = '请先选择文件';
      return;
    }
    this.isLoading = true;
    this.uploadProgress = 0;
    this.resultText = '正在上传文件...';
    try {
      const remotePath: string = this.buildUploadPath(this.queryPath, this.selectedFileName);
      const contentType: string = this.guessContentType(this.selectedFileName);
      const progressCallback: OnUploadProgress = (totalSize: number, transferredSize: number): void => {
        if (totalSize > 0) {
          this.uploadProgress = Math.floor(transferredSize / totalSize * 100);
        }
      };
      this.client.setOnUploadProgress(progressCallback);
      const response: WebDavResponse<void> = await this.client.putBinary(remotePath, this.selectedFileContent, contentType);
      if (response.isError) {
        this.resultText = '错误：' + response.statusCode.toString() + ' ' + response.errorMessage;
        this.uploadProgress = -1;
      } else {
        this.resultText = '文件上传成功！\n远程路径: ' + remotePath + '\n大小: ' + this.formatSize(this.selectedFileContent.byteLength);
        this.uploadProgress = 100;
        this.selectedFileName = '';
        this.selectedFileContent = undefined;
      }
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      this.resultText = '错误：' + err.message;
      this.uploadProgress = -1;
    }
    this.isLoading = false;
  }

  private async handlePutText(): Promise<void> {
    if (this.client === undefined) {
      return;
    }
    this.isLoading = true;
    this.resultText = '正在上传...';
    try {
      const response: WebDavResponse<void> = await this.client.put(this.queryPath, 'Hello WebDav!', 'text/plain');
      this.resultText = response.isError ?
        '错误：' + response.statusCode.toString() + ' ' + response.errorMessage :
        '文本上传成功！';
    } catch (e) {
      this.resultText = '错误：' + (e as Error).message;
    }
    this.isLoading = false;
  }

  private uriToPath(uri: string): string {
    const prefix: string = 'file://';
    if (uri.startsWith(prefix)) {
      return uri.substring(prefix.length);
    }
    return uri;
  }

  private buildUploadPath(queryPath: string, fileName: string): string {
    if (queryPath.endsWith('/')) {
      return queryPath + fileName;
    }
    return queryPath + '/' + fileName;
  }

  private guessContentType(fileName: string): string {
    const ext: string = fileName.substring(fileName.lastIndexOf('.')).toLowerCase();
    const mimeMap: Record<string, string> = {
      '.txt': 'text/plain',
      '.html': 'text/html',
      '.css': 'text/css',
      '.js': 'application/javascript',
      '.json': 'application/json',
      '.xml': 'application/xml',
      '.png': 'image/png',
      '.jpg': 'image/jpeg',
      '.jpeg': 'image/jpeg',
      '.gif': 'image/gif',
      '.pdf': 'application/pdf',
      '.zip': 'application/zip',
      '.mp4': 'video/mp4',
      '.mp3': 'audio/mpeg',
    } as Record<string, string>;
    const result: string | undefined = mimeMap[ext];
    if (result !== undefined) {
      return result;
    }
    return 'application/octet-stream';
  }

  private async handleDelete(): Promise<void> {
    if (this.client === undefined) {
      return;
    }
    this.isLoading = true;
    this.resultText = '正在删除...';
    try {
      const response: WebDavResponse<void> = await this.client.delete(this.queryPath);
      this.resultText = response.isError ?
        '错误：' + response.statusCode.toString() + ' ' + response.errorMessage :
        '删除成功！';
    } catch (e) {
      this.resultText = '错误：' + (e as Error).message;
    }
    this.isLoading = false;
  }
}
