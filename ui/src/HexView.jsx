import React from 'react';
import Immutable from 'immutable';
import {bindComponent, filterBinding, bufferComponent, BoundForms} from './Components';
import {hexToChar} from './util';
import Promise from 'core-js/library/es6/promise'; //babel polyfill

// Takes the internal repr (3 string object), passes up changes when they're valid hex
const BufferedHexView = bufferComponent(bindComponent('HexView', (binding, props) => {
  let rows = binding.get('lineCount');
  if (props.maxLines) {
    rows = Math.min(rows, props.maxLines);
  }

  return <div className='HexView'>
    <pre>{binding.get('lineLabels')}</pre>
    <BoundForms.TextArea
        binding={binding.sub('hexContent')}
        rows={rows}
        cols='48'
        disabled={props.readOnly}
        data-validation-error={props['data-validation-error']}
    />
    <pre>{binding.get('printableContent')}</pre>
  </div>;
}), {
  validate: (value) => {
    const hex = value.get('hexContent').replace(/\s*/g,'');
    return Promise.resolve( /^[0-9a-fA-F]*$/.test(hex) && ( hex.length % 2 == 0 ) )
  }
});

// Transforms a binary string to an immutable.js object containing
// strings for line labels, hex dump, printable chars
const hexDump = (str) => {
  let left = '';
  let center = '';
  let right = '';
  let lineCount = 1;

  for (let i = 0; i < str.length ; i++) {
    let col = i % 16;
    let cc = str.charCodeAt(i);
    let hex = cc.toString(16);
    if (hex.length == 1) { hex = '0' + hex; }

    if (col == 0) {
      left += i.toString(16) + '\n';
    }

    center += hex;
    if (col != 15) {
      center += ' ';
    }

    if ((cc >= 32) && (cc <= 127)) {
      right += String.fromCharCode(cc);
    } else {
      right += '.';
    }

    if (col == 7) {
      center += ' ';
    }
    if (col == 15) {
      lineCount += 1;
      center += '\n';
      right += '\n';
    }
  }
  return Immutable.Map({lineLabels: left, hexContent: center, printableContent: right, lineCount});
};

// Transforms hex dump from internal representation to binary string
const hexRead = (value) =>  {
  const hex = value.get('hexContent').replace(/\s/g,'');
  return hex.replace(/../g, hexToChar);
};


// Expected binding is a raw binary string.
const HexView = bindComponent('HexView', (binding, props) => {
  const bind = filterBinding(binding, {inFilter: hexRead, outFilter: hexDump});
  return <BufferedHexView {...props} binding={bind} maxLines={props.maxLines} />;
});
export default HexView;
