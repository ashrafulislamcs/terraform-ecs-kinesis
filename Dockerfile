FROM anapsix/alpine-java
FROM node:14.15.3-alpine3.10

WORKDIR /usr/src/app

COPY ./src ./src
COPY ./package*.json ./

RUN npm i

EXPOSE 80

CMD ["npm", "start"]