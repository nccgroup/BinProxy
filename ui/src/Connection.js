import Immutable from 'immutable';

export default class Connection {
  constructor(binding) {
    this.binding = binding;

    binding.addListener('intercepting', changes => {
      const doIntercept = changes.getCurrentValue();
      // TODO: auto-send messages currently in queue
      this.sendMessage({action: 'setIntercept', value: doIntercept});
      // XXX: there's a race condition here that probably needs to be solved server-side.
    });

    this._connect();
  }

  _connect() {
    this.socket = new WebSocket('ws://' + window.location.host + window.location.pathname);
    this.socket.onopen = this._onSocketOpen.bind(this);
    this.socket.onclose = this._onSocketClose.bind(this);
    this.socket.onmessage = this._onSocketMessage.bind(this);
  }

  _onSocketOpen() {
    this.binding.set('connected',true);
    this.sendMessage({action:'ping'});
  }

  _onSocketClose() {
    //also called on failure to connect, so we'll retry repeatedly
    this.binding.atomically()
      .set('connected',true)
      .set('running',null)
      .set('intercepting',null)
      .commit();
    setTimeout(this.connect.bind(this), 2000);
  }

  sendMessage(message_object) {
    this.socket.send(JSON.stringify(message_object));
  }


  _onSocketMessage(raw_message) {
    const ws_message = JSON.parse(raw_message.data);
    const {type, data} = ws_message;

    switch (type) {
      case 'pong':
        this.binding.set('running', data.status === 'running');
        break;

      case 'info':
      case 'error':
        console.log(data); //TODO: UI popup
        break;

      case 'message_count':
        this.onMessageCountReceived(data);
        break;

      case 'event':
      case 'message':
      case 'update': //XXX currently this has the whole thing, might switch to diffs
        this.onProxyItem(type, data);
        break;

      default:
        console.log('unexpected WS message: ', ws_message);
    }
  }
}
