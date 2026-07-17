export class AuthModeItem {
  id: string = '';
  title: string = '';
  description: string = '';
  icon: string = '';
  pagePath: string = '';

  static create(id: string, title: string, description: string, icon: string, pagePath: string): AuthModeItem {
    const item = new AuthModeItem();
    item.id = id;
    item.title = title;
    item.description = description;
    item.icon = icon;
    item.pagePath = pagePath;
    return item;
  }
}
