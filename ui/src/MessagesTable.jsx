import React from 'react';
import {Table, Column, Cell} from 'fixed-data-table';
import moment from 'moment';
import {bindComponent} from './Components';

const timeFormatter = (ts) => moment.unix(ts).format('YYYY-MM-DD HH:mm:ss');

const sizeFormatter = value => {
  if (value === undefined) { return '--'; }
  if (value > 1073741824) { return (value / 1073741824 ).toFixed() + ' GB'; }
  if (value > 1048576)    { return (value / 1048576    ).toFixed() + ' MB'; }
  if (value > 1024)       { return (value / 1024       ).toFixed() + ' KB'; }
  return value + ' bytes';
};

const getText = (rows, rowIndex, column) => {
  const item = rows.get(rowIndex)
  if (!item) {
    //XXX hack to reference global App object
    window.App.loadItem(rowIndex);
    return 'Loading...'
  }
  const t = item.get('head').get(column);
  switch(column) {
    case 'size': return sizeFormatter(t);
    case 'time': return timeFormatter(t);
    default:     return t;
  }
};


export default bindComponent('MessagesTable', binding => {
  const rowCount = binding.get('count');
  const rows = binding.get('list');

  const currentRow = binding.get('selectedIndex');
  // use mouse down rather than click to avoid perceptible delay
  const onRowMouseDown = (evt, i) => binding.set('selectedIndex', i);

  // TODO: keep this in state and update in response to resizing
  let width = window.getComputedStyle(document.getElementById('UIRoot')).width;
  width = parseInt(width);
  width = width - 20;

  const DefaultCell = ({rowIndex, columnKey, width, height}) => {
    const style = (rowIndex === currentRow) ? { fontWeight: 'bold'} : undefined;
    return <Cell
      width={width}
      height={height}
      style={style}
      >{
        getText(rows,rowIndex,columnKey)
      }</Cell>;
  };

  return <div className='MessagesTable'>
    <Table
      rowHeight={30}
      rowsCount={rowCount}
      width={width}
      height={200}
      headerHeight={30}
      onRowMouseDown={onRowMouseDown}
      >
        <Column columnKey='session_id' header='Conn' width={50} cell={DefaultCell} />
        <Column columnKey='message_id' header='Msg' width={50} cell={DefaultCell} />
        <Column columnKey='src' header='From' width={60} cell={DefaultCell} />
        <Column columnKey='size' header='Size' width={120} cell={DefaultCell} />
        <Column columnKey='time' header='Time' width={160}  cell={DefaultCell} />
        <Column columnKey='summary' header='Summary' width={0} cell={DefaultCell} flexGrow={1} />
        <Column columnKey='disposition' header='Disposition' width={100} cell={DefaultCell} />
    </Table>
  </div>;
});
