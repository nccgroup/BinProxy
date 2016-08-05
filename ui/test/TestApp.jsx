import React from 'react';
import ReactDOM from 'react-dom';
import Morearty from 'morearty';
import {BoundForms, bindComponent, filterBinding, bufferComponent} from './Components';

const VALIDATE_NO_LOWER_CASE = v => (! /[a-z]/.test(v));

const EditorField = props =>
  props.readOnly
    ? <span>{props.binding.get()}</span>
    : <BoundForms.Input {...props} />;

const Editor = props => {
  const doSave = () => props.buffer.save();
  const doReset = () => props.buffer.reset();
  return <div style={{border:'1px solid black', float: 'left', margin: '1ex', width: '40%'}}>
    <div><b>{props.title}</b></div>
    { !props.error && <div>{props.error}</div> }
    <div>Name:  <EditorField {...props} binding={props.binding.sub('name')}  /></div>
    <div>Email: <EditorField {...props} binding={props.binding.sub('email')} /></div>
    { !props.readOnly && <div>
        <input type='submit' onClick={doSave} /> &nbsp;
        <input type='reset' onClick={doReset} />
      </div>
    }
    <pre>errors: {JSON.stringify(props.validationError)}</pre>
  </div>;
};

const EDITOR_VALIDATOR = value => {
  let ok = true;
  const errors = {};
  if (value.get('name') === '') {
    ok = false;
    errors['name'] = 'Please enter a name.';
  }
  if (! /^\S+@\S+$/.test(value.get('email'))) { //yeah, yeah, it's a demo
    ok = false;
    errors['email'] = 'Please enter a valid email.';
  }
  if (!ok) {
    throw errors;
  }
  return true;
}

const BufferedEditor1 = bufferComponent(Editor, {
  validate: EDITOR_VALIDATOR,
});
const BufferedEditor2 = bufferComponent(Editor, {
  autoSave: false,
  autoValidate: false,
  validate: EDITOR_VALIDATOR,
});
const BufferedEditor3 = bufferComponent(Editor, {
  autoSave: false,
  //autoValidate: true, // default
  validate: EDITOR_VALIDATOR,
});
//note: autoSave=true implies autoValidate=true

const TestComp = bindComponent('testcomp', (binding,props) => {
  let b = binding.sub('foo.bar');
  return <div>
    <div>
      <BufferedEditor1 binding={binding.sub('formTest')} title="Defaults"/>
      <BufferedEditor2 binding={binding.sub('formTest')} title="No Auto save or validate"/>
      <BufferedEditor3 binding={binding.sub('formTest')} title="Auto validate w/o auto save (a bit wonky still)"/>
      <Editor binding={binding.sub('formTest')} readOnly={true} title="Read only view of master data"/>
    </div>
  </div>;
});

const context = Morearty.createContext({
  initialState: {
    foo: {
      bar: "ABCD",
    },
    formTest: {
      name: 'Anonymous Coward', //should default to this if empty
      email: '' // can be blank or .*@.*
    }
  }
});
window.AppContext = context;

const TestApp = context.bootstrap(TestComp);

document.addEventListener("DOMContentLoaded", () => {
  console.log('loaded');
  ReactDOM.render( <TestApp/> , document.getElementById('UIRoot'))
});
