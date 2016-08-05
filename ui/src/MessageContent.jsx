import React from 'react';

import {Tab, Tabs, TabList, TabPanel} from 'react-tabs';

import {bindComponent, filterBinding} from './Components';
import {decodeB64, encodeB64} from './util';
import ParsedMessage from './ParsedMessage';
import HexView from './HexView';
import EscapedTextView from './EscapedTextView';

Tabs.setUseDefaultStyles(false);

const StrippedText = bindComponent('StrippedText', binding =>
  <pre>{ binding.get().replace(/[^ -~\t\n]/g, '') }</pre>
);

export default bindComponent('MessageContent', binding => {
  if (binding.get('head.size') === 0) { return <div>(no content)</div>; }
  if (!binding.get('body')) {


    return <div>loading...</div>;
  }

  const readOnly = binding.toJS('head.disposition') !== 'Held' //TODO: dup logic w/ messagemeta, should refactor
  const rawBinding = filterBinding(binding.sub('body.raw'), {inFilter: encodeB64, outFilter: decodeB64});

  return <div className='MessageContent'>
    <Tabs>
      <TabList>
        <Tab>Parsed</Tab>
        <Tab>Hex Dump</Tab>
        <Tab>Escaped Text</Tab>
        <Tab>Printable Text</Tab>
      </TabList>
        <TabPanel>
          <ParsedMessage binding={binding} readOnly={readOnly} />
        </TabPanel>
        <TabPanel>
          <HexView binding={rawBinding} readOnly={readOnly} />
        </TabPanel>
        <TabPanel>
          <EscapedTextView binding={rawBinding} readOnly={readOnly} />
        </TabPanel>
        <TabPanel>
          <StrippedText binding={rawBinding} />
        </TabPanel>
    </Tabs>
  </div>;
});
