import React from 'react';
import {hexToChar} from './util';
import {bindComponent, bufferComponent, filterBinding, BoundForms} from './Components';
import Promise from 'core-js/library/es6/promise'; //babel polyfill

const badEscape = /[^\\]\\(?!\\|x[0-9a-fA-F]{2})/;
const maxLines = 10;

const escapeText = s =>
  s.replace(/\\/g,'\\\\')
   .replace(/[^ -~\n]/g, function(c) {
    let hex = c.charCodeAt(0).toString(16).toUpperCase();
    if (hex.length == 1) { hex = '0' + hex; }
      return '\\x' + hex;
  });

const unescapeText = s =>
  s.replace(/\\(\\|x[0-9a-fA-F]{2})/g, function(seq) {
    if (seq == '\\\\') { return '\\'; }
    return hexToChar(seq.substr(2));
  });

const BufferedTextArea = bufferComponent(BoundForms.TextArea, {
  validate: newValue => Promise.resolve(!badEscape.test(newValue)),
});

const EscapedTextView = bindComponent('EscapedTextView', (binding, {readOnly, ...props}) => {
  const b = filterBinding(binding, {
    outFilter: escapeText,
    inFilter: unescapeText,
  });
  return <BufferedTextArea
    {...props}
    binding={b}
    className='EscapedPane'
    rows={b.get().split('\n', maxLines).length}
    disabled={readOnly}
    data-validation-error={props['data-validation-error']}
  />;
});

export default EscapedTextView;
