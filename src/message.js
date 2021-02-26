import dynamoose from 'dynamoose';

const message = dynamoose.model("message", {
  "id": String,
  "meta": {
    "type": String,
  }
});

export default message;
