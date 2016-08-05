import BinProxyUI from './BinProxyUI';
import React from 'react';
import ReactDOM from 'react-dom';
import Morearty from 'morearty';

import Connection from './Connection';
import Messages from './Messages';


class App {
  loadItem(i) {
    if (!this.loaded[i]) {
      this.loaded[i] = true;
      this.connection.sendMessage({action: 'load', value: i});
    }
  }
  forwardMessage(message) {
    this.connection.sendMessage({action: 'forward', message}); //XXX may need to tweak how we send up the message
  }
  dropMessage(message) {
    this.connection.sendMessage({action: 'drop', message});
  }
  reloadParser() {
    this.connection.sendMessage({action: 'reloadParser'});
  }


  constructor() {
    this.context = Morearty.createContext({
      initialState: {
        proxy: {
          connected: false,
          running: null,
          intercepting: null,
        },
        messages: {
          count: 0,
          list: [],
          selectedIndex: 0,
        },
      },
    });

    //kept outside of context to avoid caching
    this.loaded = [];

    this.binding = this.context.getBinding();
    this.connection = new Connection(this.binding.sub('proxy'));
    this.messages = new Messages(this.binding.sub('messages'));

    this.connection.onMessageCountReceived = count => this.binding.set('messages.count', count);

    this.connection.onProxyItem = (type, data) => {
      if (!data.body && type == 'message') {
        data.body = () => this.loadItem(data.head.message_id);
      }
      this.messages.setItem(type,data);
    }
  }
}

// window.app global hack is used in MessagesTable (at least)
const app = window.App = new App();

const AppUI = app.context.bootstrap(BinProxyUI);

document.addEventListener('DOMContentLoaded', () => {
  ReactDOM.render( <AppUI app={app} /> , document.getElementById('UIRoot'));
});
