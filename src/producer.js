import AWS from 'aws-sdk';

const kinesis = new AWS.Kinesis({
  region: 'us-east-1'
});

const buildParams = (payload) => ({
  PartitionKey: 'test',
  StreamName: 'test',
  Data: JSON.stringify(payload),
});

const cannon = (count = 1000) => {
  for (let i = 0; i < count; i++) {
    kinesis.putRecord(buildParams({
      foo: 'bar',
      record: i,
    })).promise().then(console.log).catch(console.log);
  }
}

cannon();
