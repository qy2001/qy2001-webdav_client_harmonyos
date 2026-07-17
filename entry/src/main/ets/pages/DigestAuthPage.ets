import { WebDavClient, AuthType, WebDavResource, WebDavResponse } from 'webdav_client_harmonyos';

@Builder
export function DigestAuthPageBuilder() {
  DigestAuthPage()
}

@Component
struct DigestAuthPage {
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
  private client: WebDavClient | undefined = undefined;

  build() {
    NavDestination() {
      Scroll() {
        Column({ space: 16 }) {
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

            Text('HTTP 摘要认证需要服务端先发送 401 挑战，客户端自动计算摘要后重新发送请求。')
              .fontSize(12)
              .fontColor('#999999')

            TextInput({ placeholder: '用户名' })
              .onChange((value: string) => { this.username = value; })
              .width('100%')

            TextInput({ placeholder: '密码' })
              .type(InputType.Password)
              .onChange((value: string) => { this.password = value; })
              .width('100%')
          }
          .width('100%')
          .padding(16)
          .backgroundColor('#FFFFFF')
          .borderRadius(12)
          .alignItems(HorizontalAlign.Start)

          this.querySection()
          this.actionButtons()
          this.resultArea()
        }
        .width('100%')
        .padding(16)
      }
      .width('100%')
      .height('100%')
    }
    .title('摘要认证')
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
  actionButtons() {
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
        Button('下载文件')
          .layoutWeight(1)
          .enabled(!this.isLoading && this.client !== undefined)
          .onClick(() => { this.handleGet(); })
        Button('上传文件')
          .layoutWeight(1)
          .enabled(!this.isLoading && this.client !== undefined)
          .onClick(() => { this.handlePut(); })
      }
      .width('100%')

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
  resultArea() {
    Column({ space: 8 }) {
      Text('结果')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)

      if (this.isLoading) {
        LoadingProgress().width(32).height(32).color('#007DFF')
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
      authType: AuthType.DIGEST,
      username: this.username,
      password: this.password,
    });
  }

  private async handleConnect(): Promise<void> {
    this.isLoading = true;
    this.resultText = '正在连接（摘要认证需要两次请求）...';
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
    if (this.client === undefined) return;
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
          '\n修改时间: ' + r.lastModified + '\n大小: ' + this.formatSize(r.contentLength);
      }
    } catch (e) {
      this.resultText = '错误：' + (e as Error).message;
    }
    this.isLoading = false;
  }

  private async handleList(): Promise<void> {
    if (this.client === undefined) return;
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
    if (this.client === undefined) return;
    this.isLoading = true;
    this.resultText = '';
    try {
      const response: WebDavResponse<WebDavResource> = await this.client.stat(this.queryPath);
      if (response.isError) {
        this.resultText = '错误：' + response.statusCode.toString();
      } else if (response.data !== undefined) {
        const r: WebDavResource = response.data;
        this.resultText = '路径: ' + r.href + '\n类型: ' + (r.isDirectory ? '目录' : '文件') +
          '\n名称: ' + r.displayName + '\n修改时间: ' + r.lastModified;
      }
    } catch (e) {
      this.resultText = '错误：' + (e as Error).message;
    }
    this.isLoading = false;
  }

  private async handleMkdir(): Promise<void> {
    if (this.client === undefined) return;
    this.isLoading = true;
    this.resultText = '正在创建目录...';
    try {
      const response: WebDavResponse<void> = await this.client.mkdir(this.queryPath);
      this.resultText = response.isError ?
        '错误：' + response.statusCode.toString() : '目录创建成功！';
    } catch (e) {
      this.resultText = '错误：' + (e as Error).message;
    }
    this.isLoading = false;
  }

  private async handleGet(): Promise<void> {
    if (this.client === undefined) return;
    this.isLoading = true;
    this.resultText = '正在下载...';
    try {
      const response: WebDavResponse<string> = await this.client.get(this.queryPath);
      this.resultText = response.isError ?
        '错误：' + response.statusCode.toString() :
        '内容：\n' + (response.data ?? '（空）');
    } catch (e) {
      this.resultText = '错误：' + (e as Error).message;
    }
    this.isLoading = false;
  }

  private async handlePut(): Promise<void> {
    if (this.client === undefined) return;
    this.isLoading = true;
    this.resultText = '正在上传...';
    try {
      const response: WebDavResponse<void> = await this.client.put(this.queryPath, 'Hello WebDav!', 'text/plain');
      this.resultText = response.isError ?
        '错误：' + response.statusCode.toString() : '文件上传成功！';
    } catch (e) {
      this.resultText = '错误：' + (e as Error).message;
    }
    this.isLoading = false;
  }

  private async handleDelete(): Promise<void> {
    if (this.client === undefined) return;
    this.isLoading = true;
    this.resultText = '正在删除...';
    try {
      const response: WebDavResponse<void> = await this.client.delete(this.queryPath);
      this.resultText = response.isError ?
        '错误：' + response.statusCode.toString() : '删除成功！';
    } catch (e) {
      this.resultText = '错误：' + (e as Error).message;
    }
    this.isLoading = false;
  }
}
