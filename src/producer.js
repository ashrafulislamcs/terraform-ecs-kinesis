import AWS from 'aws-sdk';

const kinesis = new AWS.Kinesis({
  region: 'us-east-1'
});

const buildParams = (payload) => ({
  PartitionKey: 'test',
  StreamName: 'test',
  Data: JSON.stringify(payload),
});

kinesis.putRecord(buildParams({
  foo: 'bar'
})).promise().then(res => console.log('Done!', res));
