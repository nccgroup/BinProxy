import React from 'react';

import {bindComponent, BoundForms} from './Components';

export default bindComponent('StatusBar', (binding, {app}) => {
  const {connected, running} = binding.toJS();

  return <div className="StatusBar">
    <span>
      Proxy:
        <span className={connected ? 'statusOk' : 'statusErr'}>
          { connected ? 'connected' : 'disconnnected' }
        </span>
        { connected &&
            <span className={running ? 'statusOk' : 'statusErr'}>
              { running ? 'running' : 'stopped' }
            </span>
        }
    </span>

    <span><a href="/config">Configure Proxy</a></span>
    <span><a href="" onClick={ (evt) => {
      app.reloadParser();
      evt.preventDefault();
    }}>
      Reload Parser</a></span>

    <label>
      Intercept: <BoundForms.CheckBox binding={binding.sub('intercepting')} />
    </label>
  </div>;
});
