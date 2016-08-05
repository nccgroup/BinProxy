import React from 'react';
import {bindComponent} from './Components';

const doDumpToConsole = (evt) => {
  console.log(evt.target.dataset.dumpValue);
};

const doForwardMessage = (evt) => {
}

export default bindComponent('MessageMeta', (binding, {app}) => {
  const message = binding.toJS();
  const {head, body} = message;

  const copyActionsEnabled =  (body && body.raw);
  const proxyActionsEnabled = (head.disposition === 'Held');

  return <form action="#" className='MessageMeta'>
    <fieldset className="msginfo">
      <legend>Message Info</legend>
      <div className="msginfo-fields">
        <div className="msginfo-fieldgroup">
          <label>
            Message Index:
            <input value={head.index || ''} readOnly={true} />
          </label>
          <label>
            Message ID:
            <input value={head.message_id || ''} readOnly={true} />
          </label>
          <label>
            Session ID:
            <input value={head.session_id || ''} readOnly={true} />
          </label>
          <label>
            Direction:
            <select name="destination" value={head.src} disabled={true}>
              <option value="client">Client &rarr; Server</option>
              <option value="server">Server &rarr; Client</option>
            </select>
          </label>
        </div>

        <div className="msginfo-fieldgroup">
          <input type="button" value='Dump to Console'
            disabled={!copyActionsEnabled} onClick={doDumpToConsole} data-dump-value={JSON.stringify(message)}
            />
          <input type="button" value='Copy B64' disabled={true || !copyActionsEnabled} />
          <input type="button" value='Copy Raw' disabled={true || !copyActionsEnabled} />
        </div>

        <div className="msginfo-fieldgroup">
          <input type="button" value="Reset"   disabled={!proxyActionsEnabled} />
          <input type="button" value="Drop"    disabled={!proxyActionsEnabled} 
            onClick={() => app.dropMessage(message)}
            />
          <input type="button" value="Forward" disabled={!proxyActionsEnabled}
            onClick={() => app.forwardMessage(message)}
            />
        </div>
      </div>
    </fieldset>
  </form>;
});
