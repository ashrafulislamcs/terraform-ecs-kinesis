import dynamoose from 'dynamoose';

const sdk = dynamoose.aws.sdk;

sdk.config.update({
  region: 'us-east-1'
});

const message = dynamoose.model("messages", {
  "id": String,
  "meta": {
    "type": String,
  }
});

export default message;
