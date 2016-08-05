import Immutable from 'immutable';

class BaseItem extends Immutable.Record({head: null, body: null}) {
  constructor(data) {
    const head = Immutable.fromJS(data.head);
    const body = Immutable.fromJS(data.body);
    super({head,body});
  }
  // XXX minimal implementation, needs error handling, no clobber, no repeat
  load() {
    this.get('body')();
    this.set('body', null);
  }
}

export class Event extends BaseItem {}
export class Message extends BaseItem { }
