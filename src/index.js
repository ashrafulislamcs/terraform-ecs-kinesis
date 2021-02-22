import _ from 'lodash';
import kcl from 'aws-kcl';
import queue from 'async/queue.js';

const DEFAULT_CONCURRENCY_LIMIT = 500;

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

  handleTask(task) {
    const { data, sequenceNumber, partitionKey, done } = task;

    console.log('Here is the data...', data);

    done();
  }

  push(item) {
    this.queue.push(item);
  }

  get interface() {
    return {
      initialize(initializeInput, done) {
        // Any other init logic in here before KCL kicks in...

        console.log('Starting KCL record processor...');

        this.init();
        done();
      },
      shutdown() {
        console.log('Shutting down KCL consumer...');
      },
      processRecords(processRecordsInput, done) {
        if (!processRecordsInput || !processRecordsInput.records) {
          // Must call completeCallback to proceed further.
          return done();
        }
    
        const { records } = processRecordsInput;

        if (!sequenceNumber) {
          // Must call completeCallback to proceed further.
          return done();
        }

        _.each(records, (record) => {
          const { sequenceNumber, partitionKey } = record;

          this.push({
            done,
            partitionKey,
            sequenceNumber,
            data: Buffer(record.data, 'base64').toString(),
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
