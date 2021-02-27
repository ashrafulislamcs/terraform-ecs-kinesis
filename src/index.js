import _ from 'lodash';
import kcl from 'aws-kcl';
import queue from 'async/queue.js';
import { v4 as uuidv4 } from 'uuid';

import Message from './message.js';

const DEFAULT_CONCURRENCY_LIMIT = 500;

const putItem = (item) => {
  const message = new Message({
    id: uuidv4(),
    meta: JSON.stringify(item),
  });

  return message.save();
}
class Client {
  constructor({ concurrencyLimit = DEFAULT_CONCURRENCY_LIMIT } = {}) {
    this.limit = concurrencyLimit;

    this.queue = null;
    this.init = this.init.bind(this);
    this.push = this.push.bind(this);
    this.handleTask = this.handleTask.bind(this);
  }

  init() {
    this.queue = queue(async (task, done) => {
      await this.handleTask(task);

      done();
    }, this.limit);
  }

  async handleTask(task) {
    const { data, sequenceNumber, done, onCheckpoint } = task;

    console.log('Saving data: ', data);

    await putItem(data);

    onCheckpoint(sequenceNumber, (err) => {
      if (err) {
        console.log('An error occurred when checkpointing: ', err);
      }

      // In this example, regardless of error, we mark processRecords
      // complete to proceed further with more records.
      done();
    });
  }

  push(item) {
    this.queue.push(item);
  }

  get interface() {
    const self = this;

    return {
      initialize(initializeInput, done) {
        // Any other init logic in here before KCL kicks in...

        console.log('Starting KCL record processor...');

        self.init();
        done();
      },
      shutdown(shutdownInput, done) {
        console.log('Shutting down KCL consumer...');

        shutdownInput.checkpointer.checkpoint((err) => {
          if (err) {
            console.log('An error occured when shutting down: ', err);
          }

          // In this example, regardless of error, we mark the shutdown operation
          // complete.
          done();
        });
      },
      processRecords(processRecordsInput, done) {
        if (!processRecordsInput || !processRecordsInput.records) {
          // Must call completeCallback to proceed further.
          return done();
        }
    
        const { records } = processRecordsInput;

        _.each(records, (record) => {
          const { sequenceNumber } = record;

          if (!sequenceNumber) {
            // Must call completeCallback to proceed further.
            return done();
          }

          self.push({
            done,
            sequenceNumber,
            data: Buffer(record.data, 'base64').toString(),
            onCheckpoint: processRecordsInput.checkpointer.checkpoint,
          })
        });
      },
    }
  }

  start() {
    console.log('Starting KCL...');

    kcl(this.interface).run();
  }
}

new Client({}).start()
