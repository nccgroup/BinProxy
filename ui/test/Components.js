i'HexView',mport React from 'react';
import Morearty from 'morearty';
import Promise from 'core-js/library/es6/promise'; //babel polyfill


/* eslint-disable react/display-name, react/prop-types */
export const BoundForms = Object.freeze({
  CheckBox: (props) =>
    <input {...props}
      type="checkbox"
      x=1
      checked={props.binding.get()}
      onChange={ evt => props.binding.set( evt.target.value )}
    />,
  Input: (props) =>
    <input {...props}
      value={props.binding.get()}
      onChange={ evt => props.binding.set( evt.target.value )}
    />,

  TextArea: (props) =>
    <textarea {...props}
      value={props.binding.get()}
      onChange={ evt => props.binding.set( evt.target.value )}
    />,
});

const requiredBinding = { binding: React.PropTypes.object.isRequired };
BoundForms.CheckBox.propTypes = requiredBinding;
BoundForms.Input.propTypes = requiredBinding;
BoundForms.TextArea.propTypes = requiredBinding;
BoundForms.CheckBox.displayName = 'BoundForms.CheckBox';
BoundForms.Input.displayName = 'BoundForms.Input';
BoundForms.TextArea.displayName = 'BoundForms.TextArea';
/* eslint-enable react/display-name, react/prop-types */

export const bindComponent = (name, func) => React.createClass({
  displayName: name,
  mixins: [Morearty.Mixin],
  render: function() { return func(this.getDefaultBinding(), this.props); },
});

const IDENTITY_FUNCTION = v => v;
export const filterBinding = (binding, {inFilter, outFilter}) => {
  if (! binding instanceof Morearty.Binding) {
    throw `Expected "binding" to be a Morearty.Binding instance, got ${typeof binding} ${binding}`;
  }
  inFilter = inFilter || IDENTITY_FUNCTION;
  outFilter = outFilter || IDENTITY_FUNCTION;

  const initialValue = inFilter(binding.toJS());

  const newContext = Morearty.createContext({initialState: {value: initialValue}});
  const newBinding = newContext.getBinding().sub('value');
  newBinding.addListener( change => {
    let v = change.getCurrentValue();
    v = outFilter(v);
    binding.set(v);
  });

  return newBinding;
};

//TODO -need to define a baseline set of options (callback funcs)
//that make this flexible enough to build useful things.
//
// Use cases: update in real time on valid input (eg. hex editor)
//  normalize and update
//  update, normalize on blur -- maybe not in scope, can do the latter w/o this
//  explicit save
//  explicit reset
//  show validation results (realtime or on save)
//
// Goals (from above)
//  Default behavior s/b to update
//  validation can modify content props (return value?)
//  either support explicit save or make it easy
export const bufferComponent = (component, options) => {
  return props => <Buffer {...props} content={component} {...options} />;
};

// Note: when using this class, predefine the 'content' function property
// to avoid rerenders that break input state (cursor pos)
//
// The 'binding' value may be an Immutable or a primitive (if it is treated
// as constant).
//
// Specify onChange(newVale, oldValue, buffer) => true (accept update) / false (reject it)
//  can also call buffer.setState (e.g. 'contentProps')
//
// 
// this.onChange -> props.validate -> 
// this.save() -> props.validate ->
//
const Buffer = React.createClass({
  propTypes: {
    autoSave: React.PropTypes.bool,
    autoValidate: React.PropTypes.bool,
    validate: React.PropTypes.func,
    content: React.PropTypes.element.isRequired,
  },
  displayName: 'Buffer',
  mixins: [Morearty.Mixin],

  getDefaultProps: function() {
    return {
      autoSave: true,
      autoValidate: true,
      validate: () => true,
    };
  },

  onBindingChange: function(change) {
    const oldValue = this.state.value;
    const newValue = change.getCurrentValue();

    //Must do this in either case.  http://stackoverflow.com/q/28922275
    this.setState({ value: newValue });

    if (this.props.autoSave || this.props.autoValidate) {
      this.maybeSave(newValue, oldValue, false);
    }
  },

  maybeSave: function(newValue, oldValue, isExplicitSave) {
    let p = Promise.resolve(true)
      .then(() => this.props.validate(newValue, oldValue))
      .then(res => {
        if (!res) { throw '(Validator returned false.)'; }
    });
    // we store and return the promise at this point in the chain, so callers
    // can handle a failure to validate

    // also set/clear error in state
    p.then( () => this.setState({'validationError': null}) );
    // this also suppresses the unhandled rejection warning
    p.catch( e => this.setState({'validationError': e}) );

    // If the validation did succeed, pass the new value out
    p.then( () => {
      if (this.props.autoSave || isExplicitSave) {
        //can this throw? if it does, we will get an unhandled rejection warning
        this.getDefaultBinding().set(newValue);
      }
    });

    return p;
  },

  save: function() {
    //TODO what should the second arg be here)
    return this.maybeSave(this.state.value, this.state.value, true);
  },

  reset: function() {
    throw 'not yet implemented';
  },

  //returns new state
  bindContent: function(value, content) {
    const context = Morearty.createContext({initialState: { value }});
    const binding = context.getBinding().sub('value');
    const bsContent = context.bootstrap(content);

    binding.addListener(this.onBindingChange);

    return {value, binding, bsContent, validationError: null};
  },

  //XXX Without this, the first time the value changes from a user edit, this
  //component doesn't re-render, and the content is rerendered (it shouldn't
  //be, as the state is following the DOM).  I'm still not really clear on why.
  shouldComponentUpdateOverride: function() { return true; },

  getInitialState: function() {
    const initialValue = this.getDefaultBinding().get();
    return this.bindContent(initialValue, this.props.content);
  },

  componentWillReceiveProps: function(nextProps) {
    const newValue = nextProps.binding.get();
    const oldValue = this.state.value;

    if (newValue !== oldValue) {
      //should only happen when prop changed by external source;
      // internal edits should already be reflected in state
      this.setState(this.bindContent(newValue, nextProps.content));
    }
    if (this.props.content != nextProps.content) {
      if (process.env.NODE_ENV !== 'production') {
        // eslint-disable-next-line no-console
        console.warn('change in `content` prop forces re-render.');
      }
      this.setState(this.bindContent(newValue, nextProps.content));
    }
  },

  render: function() {
    const BSC = this.state.bsContent;
    return <BSC {...this.props} validationError={this.state.validationError} buffer={this} binding={this.state.binding} />;
  },
});

