import React from 'react';

import {bindComponent} from './Components';

import MessagesTable from './MessagesTable';
import StatusBar from './StatusBar';
import MessageMeta from './MessageMeta';
import MessageContent from './MessageContent';

const BinProxyUI = bindComponent('BinProxyUI', (binding, {app}) => {
  const selectedBinding = binding.sub('messages.list.' + binding.get('messages.selectedIndex'));
  let showBody = false;
  const item = selectedBinding.toJS();
  if (item) {
    if (item.body instanceof Function) {
      item.body(); //can't show yet, loading will trigger update
    } else if (item.body) {
      showBody = true;
    }
  }

  return (
    <div className='BinProxyUI'>
      <StatusBar binding={binding.sub('proxy')} app={app} />
      <MessagesTable binding={binding.sub('messages')} />
      { showBody ? <MessageMeta binding={selectedBinding} app={app} /> : '' }
      { showBody ? <MessageContent binding={selectedBinding} /> : '' }
    </div>);
});
export default BinProxyUI;
