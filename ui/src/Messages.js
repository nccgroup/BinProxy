import {Event, Message} from './Message';

const classes = {
  event: Event,
  message: Message,
};

export default class Messages {
  constructor(binding) {
    this.binding = binding;
  }

  setItem(type, data) {
    const id = data.head.message_id;
    let obj;

    if (type === 'update') {
      obj = new Message(data);
    } else {
      this.binding.update('count', c => Math.max(c, id + 1));
      obj = new (classes[type])(data);
    }

    this.binding.sub('list').set(id, obj);
  }
}
