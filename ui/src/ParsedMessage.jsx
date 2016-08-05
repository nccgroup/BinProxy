import React from 'react';
import Morearty from 'morearty';
import Immutable from 'immutable';

import {bindComponent, BoundForms} from './Components';
import {decodeB64, encodeB64} from './util';
import HexView from './HexView';
import EscapedTextView from './EscapedTextView';

const PMPlaceholder = (props) =>
  <div className='PMTreeNode'>{props.children}</div>; //eslint-disable-line react/prop-types

const renderBranchContent = (binding, props) => {
  const len = binding.get().size;
  if (len == 0) {
    return <PMPlaceholder key={0}><i>(no elements)</i></PMPlaceholder>;
  }

  /* Array.map only iterates over initialized values, so run the constructor
   * twice to initialize the values to unedfined.  All this for the lack of a
   * decent Range class in JS.  Argh. */
  return Array.apply(null, new Array(len)).map( (_, idx) =>
    <PMTreeNode {...props} key={idx} binding={binding.sub(idx)} />
  );
};

const renderLeafContent = (binding, display, {readOnly}) => {
  const value = binding.get();
  const filter_out = [];
  const filter_in = [];

  switch (typeof value) {
    case 'string':
      filter_out.push(decodeB64);
      filter_in.push(encodeB64);
      break;

    case 'number':
      if (display == 'hex') {
        filter_out.push( n => '0x' + n.toString(16) );
        filter_in.push( s => parseInt(s, 16) );
      } else {
        filter_out.push( n => n.toString(10) );
        filter_in.push( s => parseInt(s, 10) );
      }
      break;

    default:
      throw 'unexpected type';
  }

  const newBinding = Morearty.Binding.init(Immutable.fromJS({
    leaf: filter_out.reduce( (v,f) => f(v) , value),
  }));
  newBinding.addListener('leaf', (changes) => {
    const newValue = filter_in.reduce(
      (v,f) => f(v),
      changes.getCurrentValue()
    );
    binding.set(newValue);
  });
  const leafBinding = newBinding.sub('leaf');

  switch(display) {
    case 'hexdump':
      return <HexView binding={leafBinding} readOnly={readOnly} />;
    case 'multiline':
      return <EscapedTextView binding={leafBinding} readOnly={readOnly} />; // maxLines={10} />;
    default:
      return <BoundForms.Input binding={leafBinding} disabled={readOnly} />;
  }
};

const PMTreeNode = bindComponent('PMTreeNode', (binding,props) => {
  const {isRoot, ...restProps} = props;

  const name = binding.get('name');
  const anon = isRoot || binding.get('display') === 'anon' || !name;
  const isLeaf = ! binding.get().has('contents');

  const nameSpan = ((!anon)
    ? <span className='FieldName' title={binding.get('objclass')}>{name}</span>
    : '');

  const classSpan = ((anon || !isLeaf)
    ? <PMPlaceholder key={-1}><u>{binding.get('objclass')}</u></PMPlaceholder>
    : '');

  const content = (isLeaf
    ? renderLeafContent(binding.sub('value'), binding.get('display'), restProps)
    : renderBranchContent(binding.sub('contents'), restProps));

  return <label className='PMTreeNode'>
    {nameSpan}
    <span className='FieldContent'>
      {classSpan}
      {content}
    </span>
  </label>;
});

export default bindComponent('ParsedMessage', (binding, props) =>
  <div className='ParsedMessage'>
    <PMTreeNode
      {...props}
      binding={binding.sub('body.snapshot')}
      isRoot={true}
    />
  </div>
);
