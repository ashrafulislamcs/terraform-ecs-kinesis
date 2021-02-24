FROM ubuntu:latest
USER root

WORKDIR /usr/src/app

COPY ./src ./src
COPY ./package*.json ./
COPY kinesis.properties kinesis.properties

RUN apt-get update
RUN apt-get -y install curl gnupg
RUN curl -sL https://deb.nodesource.com/setup_14.x  | bash -
RUN apt-get -y install nodejs

RUN DEBIAN_FRONTEND=noninteractive \
    apt-get -y install default-jre-headless && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN npm i
RUN npm i -g aws-kcl

EXPOSE 80

CMD ["npm", "start"]